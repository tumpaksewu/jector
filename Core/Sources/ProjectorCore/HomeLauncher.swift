import Foundation

public struct HomeLauncher: Identifiable, Hashable, Sendable {
    public let component: String
    public var id: String { component }
    public var package: String { String(component.split(separator: "/")[0]) }
    public var title: String {
        switch package {
        case "com.tvfengmi.launcher": return "FengOS"
        case "com.spocky.projengmenu": return "Projectivy"
        default: return package
        }
    }
    public var command: String {
        "am start -a android.intent.action.MAIN -f 0x10200000 -n \(component)"
    }

    public init(component: String) throws {
        guard component.range(of: #"\A[A-Za-z][A-Za-z0-9_]*(?:\.[A-Za-z0-9_]+)+/[A-Za-z_.][A-Za-z0-9_.]*\z"#,
                              options: .regularExpression) != nil else {
            throw RemoteError.message("Invalid launcher activity returned by projector.")
        }
        self.component = component
    }

    public static func parse(_ output: String) -> [HomeLauncher] {
        var seen = Set<String>()
        return output.split(separator: "\n").compactMap { line in
            let value = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let launcher = try? HomeLauncher(component: value),
                  !value.hasSuffix(".FallbackHome"), seen.insert(value).inserted else { return nil }
            return launcher
        }
    }

    public static func selected(_ id: String, installed: [HomeLauncher]) throws -> HomeLauncher? {
        guard !id.isEmpty else { return nil }
        guard let launcher = installed.first(where: { $0.id == id }) else {
            throw RemoteError.message("The selected Home launcher is unavailable. Choose another in Settings.")
        }
        return launcher
    }
}
