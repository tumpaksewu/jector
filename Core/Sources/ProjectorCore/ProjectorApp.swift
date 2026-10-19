import Foundation

public enum ProjectorApp: String, CaseIterable, Identifiable, Sendable {
    case youtube, jellyfin, rutube, vkVideo, atvSearch
    public var id: String { rawValue }
    public var launchCommand: String {
        "am start -W -a android.intent.action.MAIN -c android.intent.category.LEANBACK_LAUNCHER -f 0x10200000 -n \(component)"
    }
    public var title: String { self == .jellyfin ? "Jellyfin TV" : toolName }
    public var toolName: String {
        switch self {
        case .youtube: return "YouTube"
        case .jellyfin: return "Jellyfin"
        case .rutube: return "Rutube"
        case .vkVideo: return "VK Video"
        case .atvSearch: return "ATV Search"
        }
    }
    public var package: String {
        switch self {
        case .youtube: return "com.google.android.youtube.tv"
        case .jellyfin: return "org.jellyfin.androidtv"
        case .rutube: return "ru.rutube.app"
        case .vkVideo: return "com.vk.tv"
        case .atvSearch: return "com.tvvoicesearch.app"
        }
    }
    public var component: String {
        switch self {
        case .youtube: return package + "/com.google.android.apps.youtube.tv.activity.ShellActivity"
        case .jellyfin: return package + "/.ui.startup.StartupActivity"
        case .rutube: return package + "/.SplashActivity"
        case .vkVideo: return package + "/.presentation.base.TvMainActivity"
        case .atvSearch: return package + "/.VoiceSearchActivity"
        }
    }
    public static func named(_ value: String) -> Self? { allCases.first { $0.toolName == value } }

    public func isNamed(in request: String) -> Bool {
        let alias: String
        switch self {
        case .youtube: alias = #"youtube|ютуб\p{L}*"#
        case .jellyfin: alias = #"jellyfin|джеллифин\p{L}*"#
        case .rutube: alias = #"rutube|рутуб\p{L}*"#
        case .vkVideo: alias = #"vk(?:\s*video)?|вк(?:\s*видео)?"#
        case .atvSearch: alias = #"atv\s*(?:search|поиск)"#
        }
        return request.range(of: #"(?i)(?<![\p{L}\p{N}_])(?:"# + alias + #")(?![\p{L}\p{N}_])"#,
                             options: .regularExpression) != nil
    }
}
