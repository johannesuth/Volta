import AVFoundation
import Foundation
import VoltaLanguageCore

/// Plays alert tones through AVAudioPlayer, honouring volume and the quiet window.
@MainActor
enum Chime {
    nonisolated static let silent = "__volta_silent__"

    static var userTonesFolder: URL {
        let dir = ConfigStore.shared.folder.appending(path: "Tones", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static let systemFolder = URL(filePath: "/System/Library/Sounds", directoryHint: .isDirectory)
    private static var player: AVAudioPlayer?

    static func catalog() -> [String] {
        func names(in dir: URL, keepExtension: Bool) -> [String] {
            let urls = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
            return urls.filter { ["aiff", "aif", "wav", "mp3", "m4a", "caf"].contains($0.pathExtension.lowercased()) }
                .map { keepExtension ? $0.lastPathComponent : $0.deletingPathExtension().lastPathComponent }
                .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        }
        return [silent] + names(in: systemFolder, keepExtension: false) + names(in: userTonesFolder, keepExtension: true)
    }

    private static func locate(_ name: String) -> URL? {
        let custom = userTonesFolder.appending(path: name)
        if FileManager.default.fileExists(atPath: custom.path(percentEncoded: false)) { return custom }
        let system = systemFolder.appending(path: name + ".aiff")
        return FileManager.default.fileExists(atPath: system.path(percentEncoded: false)) ? system : nil
    }

    /// `force` ignores the quiet window (used for previews in Settings).
    static func ring(_ name: String, gain: Double = 1, force: Bool = false) {
        let cfg = ConfigStore.shared.c
        guard name != silent, force || !cfg.quiet.contains(), let url = locate(name) else { return }
        player?.stop()
        player = try? AVAudioPlayer(contentsOf: url)
        player?.volume = Float(min(1, cfg.volume * gain))
        player?.play()
    }

    static func adopt(_ source: URL) throws -> String {
        let dest = userTonesFolder.appending(path: source.lastPathComponent)
        try SafeFileCopy.copyReplacingItem(at: source, to: dest)
        return dest.lastPathComponent
    }
}
