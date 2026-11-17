import Foundation

enum GlyphTintResolver {
    static func resolve(_ selection: GlyphTint, mode: FlowMode, level: Int) -> GlyphTint? {
        switch selection {
        case .status:
            switch mode {
            case .filling: .green
            case .deficit: .amber
            case .draining where level <= 10: .rose
            case .draining where level <= 20: .amber
            default: nil
            }
        case .monochrome:
            nil
        default:
            selection
        }
    }
}
