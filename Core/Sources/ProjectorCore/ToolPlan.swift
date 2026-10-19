import Foundation
import CoreFoundation

public enum ProjectorAction: Equatable, Sendable {
    case volume(Int), pause, resume, open(ProjectorApp), home, search(ProjectorApp, String)

    public var title: String {
        switch self {
        case .volume(let value): return "Set volume to \(value)%"
        case .pause: return "Pause playback"
        case .resume: return "Resume playback"
        case .open(let app): return "Open \(app.title)"
        case .home: return "Go to Home"
        case .search(let app, let query): return "Search \(app.title) for “\(query)”"
        }
    }
}

public struct ToolPlan: Sendable {
    public let actions: [ProjectorAction]

    /// Do not let the model silently choose a search destination the user omitted.
    public func validateSearchTargets(in request: String) throws {
        for case .search(let app, _) in actions where !app.isNamed(in: request) {
            throw RemoteError.message("Name the app to search: YouTube, Jellyfin, Rutube or VK Video. Nothing was sent.")
        }
    }

    /// Reject the entire plan before running anything; never accept a partial parse.
    public init(json: String, installedApps: [ProjectorApp]) throws {
        let fail = RemoteError.message("Invalid or unsupported model command; nothing was sent.")
        guard json.utf8.count <= 4096,
              let data = json.data(using: .utf8),
              let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              Set(root.keys) == ["calls"], let calls = root["calls"] as? [[String: Any]],
              calls.count <= 3 else { throw fail }
        actions = try calls.map { call in
            guard Set(call.keys) == ["name", "arguments"], let name = call["name"] as? String,
                  let args = call["arguments"] as? [String: Any] else { throw fail }
            switch name {
            case "set_volume":
                guard Set(args.keys) == ["level"], let number = args["level"] as? NSNumber,
                      CFGetTypeID(number) != CFBooleanGetTypeID(),
                      number.doubleValue == Double(number.intValue), (0...100).contains(number.intValue) else {
                    throw RemoteError.message("Volume must be an integer from 0 to 100; nothing was sent.")
                }
                return .volume(number.intValue)
            case "open_app":
                guard Set(args.keys) == ["app"], let value = args["app"] as? String,
                      let app = ProjectorApp.named(value),
                      installedApps.contains(app) else { throw fail }
                return .open(app)
            case "search_app":
                guard Set(args.keys) == ["app", "query"], let value = args["app"] as? String,
                      let app = ProjectorApp.named(value), installedApps.contains(app),
                      let query = args["query"] as? String else { throw fail }
                return .search(app, try SearchRequest.validate(query))
            case "pause_media", "resume_media", "go_home":
                guard args.isEmpty else { throw fail }
                return name == "pause_media" ? .pause : name == "resume_media" ? .resume : .home
            default: throw fail
            }
        }
    }
}
