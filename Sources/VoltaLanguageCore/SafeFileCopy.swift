import Foundation

/// Copies a replacement beside its destination, then swaps it in only after the copy succeeds.
public enum SafeFileCopy {
    public static func copyReplacingItem(at sourceURL: URL, to destinationURL: URL) throws {
        let fileManager = FileManager.default
        let source = sourceURL.standardizedFileURL
        let destination = destinationURL.standardizedFileURL
        let sourcePath = source.path(percentEncoded: false)
        let destinationPath = destination.path(percentEncoded: false)

        guard fileManager.fileExists(atPath: sourcePath) else {
            throw CocoaError(.fileNoSuchFile)
        }
        guard source != destination else { return }

        let parent = destination.deletingLastPathComponent()
        try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
        let temporary = parent.appending(path: ".volta-\(UUID().uuidString).tmp")
        defer { try? fileManager.removeItem(at: temporary) }

        try fileManager.copyItem(at: source, to: temporary)
        if fileManager.fileExists(atPath: destinationPath) {
            _ = try fileManager.replaceItemAt(destination, withItemAt: temporary, backupItemName: nil, options: [])
        } else {
            try fileManager.moveItem(at: temporary, to: destination)
        }
    }
}
