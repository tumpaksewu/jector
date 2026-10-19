import Foundation

public struct SearchRequest: Sendable {
    public let app: ProjectorApp
    public let query: String

    public init(app: ProjectorApp, query: String) throws {
        self.app = app
        self.query = try Self.validate(query)
    }

    public static func validate(_ value: String) throws -> String {
        guard !value.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
            throw RemoteError.message("Search queries cannot contain control characters.")
        }
        let query = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty, query.count <= 200, query.utf8.count <= 1024 else {
            throw RemoteError.message("Enter a search query between 1 and 200 characters.")
        }
        return query
    }

    /// One shell argument, including apostrophes, dollar signs and non-Latin text.
    static func quote(_ value: String) -> String { "'" + value.replacingOccurrences(of: "'", with: "'\"'\"'") + "'" }

    public var command: String {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"))!
        switch app {
        case .youtube:
            return view("https://www.youtube.com/results?search_query=" + encoded)
        case .vkVideo:
            return view("vkvideo://vk.com/search?query=" + encoded)
        case .rutube:
            return view("rutube://rutube.ru/search?query=" + encoded)
        case .jellyfin:
            return "am start -a android.intent.action.SEARCH -n \(app.component) --es query \(Self.quote(query))"
        case .atvSearch:
            return "am start -a com.tvvoicesearch.app.action.OPEN_SEARCH_RESULTS -n \(app.component) --es query \(Self.quote(query))"
        }
    }

    private func view(_ url: String) -> String {
        "am start -a android.intent.action.VIEW -d \(Self.quote(url)) -p \(app.package)"
    }
}
