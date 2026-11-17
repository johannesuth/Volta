import Foundation

enum URLQueryParameters {
    /// Returns nil when a URL repeats a key, avoiding ambiguous command handling.
    static func parse(_ url: URL) -> [String: String]? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        var values: [String: String] = [:]
        for item in components.queryItems ?? [] {
            guard values[item.name] == nil else { return nil }
            values[item.name] = item.value ?? ""
        }
        return values
    }
}
