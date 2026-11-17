public enum AppProfile {
    /// Keep the production folder stable while allowing isolated local QA profiles.
    public static func supportFolderName(arguments: [String]) -> String {
        guard let option = arguments.firstIndex(of: "--profile"),
              arguments.indices.contains(option + 1) else {
            return "Volta"
        }

        let candidate = arguments[option + 1]
        guard !candidate.hasPrefix("--") else { return "Volta" }
        let allowed = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-")
        let name = String(candidate.filter { allowed.contains($0) })
        return name.isEmpty ? "Volta" : "Volta-\(name)"
    }
}
