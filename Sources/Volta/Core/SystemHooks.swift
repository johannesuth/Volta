import AppKit
import Carbon.HIToolbox
import ServiceManagement

// MARK: - Global shortcut

/// System-wide shortcut via the Carbon event hot-key service (the only public macOS API that
/// works without Accessibility or Input-Monitoring permission).
final class GlobalShortcut {
    private static var actions: [UInt32: () -> Void] = [:]
    private static var dispatcherInstalled = false
    private static var nextID: UInt32 = 1

    private var hotKey: EventHotKeyRef?
    private let identifier: UInt32

    init?(_ combo: KeyCombo, perform: @escaping () -> Void) {
        Self.installDispatcher()
        identifier = Self.nextID
        Self.nextID += 1
        let signature = EventHotKeyID(signature: 0x766F_6C74, id: identifier) // "volt"
        guard RegisterEventHotKey(combo.keyCode, combo.carbonFlags, signature, GetEventDispatcherTarget(), 0, &hotKey) == noErr else {
            return nil
        }
        Self.actions[identifier] = perform
    }

    deinit {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        Self.actions[identifier] = nil
    }

    private static func installDispatcher() {
        guard !dispatcherInstalled else { return }
        dispatcherInstalled = true
        var kind = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
        InstallEventHandler(GetEventDispatcherTarget(), { _, event, _ in
            var hk = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &hk)
            GlobalShortcut.actions[hk.id]?()
            return noErr
        }, 1, &kind, nil, nil)
    }

    /// Converts an NSEvent captured by the recorder into a combo.
    static func combo(from event: NSEvent) -> KeyCombo? {
        let mods = event.modifierFlags.intersection([.command, .option, .control, .shift])
        guard !mods.isEmpty, let chars = event.charactersIgnoringModifiers?.uppercased(), !chars.isEmpty else { return nil }
        var carbon: UInt32 = 0
        var label = ""
        if mods.contains(.control) { carbon |= UInt32(controlKey); label += "⌃" }
        if mods.contains(.option) { carbon |= UInt32(optionKey); label += "⌥" }
        if mods.contains(.shift) { carbon |= UInt32(shiftKey); label += "⇧" }
        if mods.contains(.command) { carbon |= UInt32(cmdKey); label += "⌘" }
        let functionKeys: [Int: String] = [kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
                                           kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12"]
        let keyName: String = switch Int(event.keyCode) {
        case kVK_Space: Copy.text("Leertaste", "Space")
        case kVK_Return: "↩"
        case let code where functionKeys[code] != nil: functionKeys[code]!
        default: chars
        }
        return KeyCombo(keyCode: UInt32(event.keyCode), carbonFlags: carbon, label: label + keyName)
    }
}

// MARK: - Open at login

/// Registers Volta itself as a login item, so macOS lists it as "Volta" with its icon under
/// System Settings → General → Login Items.
enum LoginItem {
    private static let legacyLabel = "com.johannesuth.volta.autostart"

    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }
    static var needsApproval: Bool { SMAppService.mainApp.status == .requiresApproval }

    static func set(_ on: Bool) throws {
        if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
    }

    static func openSystemSettings() { SMAppService.openSystemSettingsLoginItems() }

    /// Versions up to 2.1 used a LaunchAgent that started `/usr/bin/open`, which macOS showed as "open".
    @discardableResult
    static func removeLegacyAgent(in folder: URL = URL.homeDirectory.appending(path: "Library/LaunchAgents")) -> Bool {
        let plist = folder.appending(path: "\(legacyLabel).plist")
        guard FileManager.default.fileExists(atPath: plist.path(percentEncoded: false)) else { return false }
        return (try? FileManager.default.removeItem(at: plist)) != nil
    }

    /// Replaces the old agent with a proper login item, keeping the user's choice.
    static func migrateLegacyAgent() {
        if removeLegacyAgent() { try? set(true) }
    }
}

// MARK: - Low Power Mode

enum EcoMode {
    /// Flips Low Power Mode with `pmset`, asking macOS for administrator approval once.
    static func set(_ enabled: Bool, done: @escaping (Bool) -> Void) {
        let task = Process()
        task.executableURL = URL(filePath: "/usr/bin/osascript")
        task.arguments = ["-e", "do shell script \"/usr/bin/pmset -a lowpowermode \(enabled ? 1 : 0)\" with administrator privileges"]
        task.terminationHandler = { p in DispatchQueue.main.async { done(p.terminationStatus == 0) } }
        if (try? task.run()) == nil { done(false) }
    }
}

enum Shortcuts {
    static func openPane(_ id: String) {
        if let url = URL(string: "x-apple.systempreferences:\(id)") { NSWorkspace.shared.open(url) }
    }
    static func batteryPane() { openPane("com.apple.Battery-Settings.extension") }
    static func bluetoothPane() { openPane("com.apple.BluetoothSettings") }
}
