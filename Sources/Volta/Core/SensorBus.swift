import Foundation
import IOKit

/// Talks to the AppleSMC user client with a flat 80-byte request buffer.
/// Only read selectors are used, which macOS allows for ordinary user processes.
final class SensorBus: @unchecked Sendable {
    static let shared = SensorBus()

    private enum Offset { static let key = 0, size = 28, type = 32, result = 40, selector = 42, payload = 48 }
    private enum Selector: UInt8 { case describe = 9, fetch = 5 }
    private static let frame = 80

    private var port: io_connect_t = 0
    private let gate = DispatchQueue(label: "volta.sensorbus")
    private var shapes: [String: (size: UInt32, type: String)] = [:]

    private init() {
        for matcher in [IOServiceNameMatching("AppleSMC"), IOServiceMatching("AppleSMC")] {
            var it: io_iterator_t = 0
            guard IOServiceGetMatchingServices(kIOMainPortDefault, matcher, &it) == KERN_SUCCESS else { continue }
            defer { IOObjectRelease(it) }
            let svc = IOIteratorNext(it)
            guard svc != 0 else { continue }
            defer { IOObjectRelease(svc) }
            if IOServiceOpen(svc, mach_task_self_, 0, &port) == KERN_SUCCESS { return }
        }
    }

    private static func code(_ text: String) -> UInt32 {
        var v: UInt32 = 0
        for b in text.utf8.prefix(4) { v = v << 8 | UInt32(b) }
        return v
    }

    private static func text(_ code: UInt32) -> String {
        String(decoding: [24, 16, 8, 0].map { UInt8(truncatingIfNeeded: code >> $0) }, as: UTF8.self)
    }

    private func exchange(_ request: [UInt8]) -> [UInt8]? {
        var input = request
        var output = [UInt8](repeating: 0, count: Self.frame)
        var outLen = Self.frame
        let status = input.withUnsafeMutableBytes { inBuf in
            output.withUnsafeMutableBytes { outBuf in
                IOConnectCallStructMethod(port, 2, inBuf.baseAddress, Self.frame, outBuf.baseAddress, &outLen)
            }
        }
        guard status == kIOReturnSuccess, output[Offset.result] == 0 else { return nil }
        return output
    }

    private func request(key: String, selector: Selector, size: UInt32 = 0) -> [UInt8] {
        var buf = [UInt8](repeating: 0, count: Self.frame)
        buf.withUnsafeMutableBytes { raw in
            raw.storeBytes(of: Self.code(key), toByteOffset: Offset.key, as: UInt32.self)
            raw.storeBytes(of: size, toByteOffset: Offset.size, as: UInt32.self)
        }
        buf[Offset.selector] = selector.rawValue
        return buf
    }

    /// Decoded numeric reading, or nil when the key is absent or of an unknown encoding.
    func number(_ key: String) -> Double? {
        gate.sync {
            guard port != 0 else { return nil }
            if shapes[key] == nil {
                guard let reply = exchange(request(key: key, selector: .describe)) else { return nil }
                let size = reply.withUnsafeBytes { $0.load(fromByteOffset: Offset.size, as: UInt32.self) }
                let type = reply.withUnsafeBytes { $0.load(fromByteOffset: Offset.type, as: UInt32.self) }
                shapes[key] = (size, Self.text(type))
            }
            guard let shape = shapes[key],
                  let reply = exchange(request(key: key, selector: .fetch, size: shape.size)) else { return nil }
            let bytes = Array(reply[Offset.payload ..< Offset.payload + Int(min(shape.size, 32))])
            return Self.decode(bytes, as: shape.type)
        }
    }

    private static func decode(_ b: [UInt8], as type: String) -> Double? {
        func be16() -> UInt16 { UInt16(b[0]) << 8 | UInt16(b[1]) }
        switch (type, b.count) {
        case ("flt ", 4): return Double(Float(bitPattern: b.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }))
        case ("sp78", 2): return Double(Int16(bitPattern: be16())) / 256
        case ("fpe2", 2): return Double(be16()) / 4
        case ("ui8 ", 1): return Double(b[0])
        case ("ui16", 2): return Double(be16())
        case ("si16", 2): return Double(Int16(bitPattern: be16()))
        default: return nil
        }
    }

    /// Battery pack temperature: median of the plausible pack sensors.
    var packCelsius: Double? {
        let values = ["TB0T", "TB1T", "TB2T", "TB3T"].compactMap(number).filter { (2.0...85.0).contains($0) }.sorted()
        return values.isEmpty ? nil : values[values.count / 2]
    }

    /// Whole-system draw in watts.
    var systemWatts: Double? {
        number("PSTR").flatMap { (0.0...400.0).contains($0) ? $0 : nil }
    }
}
