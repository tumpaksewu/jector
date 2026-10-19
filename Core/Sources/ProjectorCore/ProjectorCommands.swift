import Foundation

public struct ProjectorCommands: Sendable {
    public let session: ProjectorSession
    public init(session: ProjectorSession) { self.session = session }

    public func inspect() async throws -> ProjectorInfo {
        let model = try await session.shell("getprop ro.product.model")
        guard model.localizedCaseInsensitiveContains("Peppa") else {
            throw RemoteError.message("Connected to \(model), but controls are currently validated for the Formovie S5 (Peppa) only.")
        }
        let android = try await session.shell("getprop ro.build.version.release")
        let packages = try await session.shell("pm list packages")
        let installed = Set(packages.split(separator: "\n").map { $0.replacingOccurrences(of: "package:", with: "").trimmingCharacters(in: .whitespacesAndNewlines) })
        let volume = try await readVolume()
        let accessibility = try await session.shell("settings get secure enabled_accessibility_services")
        var launchers = HomeLauncher.parse(try await session.shell("cmd package query-activities --brief -a android.intent.action.MAIN -c android.intent.category.HOME"))
        if installed.contains("com.spocky.projengmenu") {
            let result = try await session.shell("cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.LAUNCHER -p com.spocky.projengmenu")
            for launcher in HomeLauncher.parse(result) where !launchers.contains(launcher) { launchers.append(launcher) }
        }
        return ProjectorInfo(model: model, android: android,
                             apps: ProjectorApp.allCases.filter { installed.contains($0.package) },
                             volume: volume, launchers: launchers, projectivyAccessibilityEnabled: accessibility.contains("com.spocky.projengmenu"))
    }

    public func readVolume() async throws -> Volume {
        try Volume(output: await session.shell("media volume --stream 3 --get"))
    }

    public func setVolume(percent: Int, current: Volume) async throws -> Volume {
        let index = try current.index(for: percent)
        _ = try await session.shell("media volume --stream 3 --set \(index)")
        let actual = try await readVolume()
        guard actual.index == index else { throw RemoteError.message("Volume readback did not match the requested level.") }
        return actual
    }

    public func key(_ key: RemoteKey) async throws {
        _ = try await session.shell("input keyevent \(key.rawValue)")
    }

    public func home(launcher: HomeLauncher?, available: [HomeLauncher]) async throws {
        _ = try await session.shell(launcher?.command ?? "input keyevent KEYCODE_HOME")
        try await waitForForeground(launcher.map { [$0.package] } ?? Set(available.map(\.package)), requiredMatches: 6,
                                    failureMessage: "Home did not stay on \(launcher?.title ?? "the default launcher"). Check the Home setting and Projectivy’s Override current launcher option.")
    }

    public func launch(_ app: ProjectorApp) async throws {
        _ = try await session.shell(app.launchCommand)
        try await waitForForeground([app.package])
    }

    public func media(play: Bool) async throws -> String {
        _ = try await session.shell("media dispatch \(play ? "play" : "pause")")
        return "\(play ? "Play" : "Pause") sent. Confirm playback on the projector."
    }

    public func search(_ app: ProjectorApp, query: String) async throws {
        let request = try SearchRequest(app: app, query: query)
        _ = try await session.shell(request.command)
        try await waitForForeground([app.package])
    }

    private func waitForForeground(_ packages: Set<String>, requiredMatches: Int = 2, failureMessage: String? = nil) async throws {
        let deadline = Date().addingTimeInterval(12)
        var matches = 0
        var previousPackage: String?
        while Date() < deadline {
            try Task.checkCancellation()
            let focus = try await session.shell("dumpsys window windows | grep mCurrentFocus", timeout: 5)
            let currentPackage = packages.first { focus.contains(" \($0)/") }
            matches = currentPackage == nil ? 0 : currentPackage == previousPackage ? matches + 1 : 1
            previousPackage = currentPackage
            if matches >= requiredMatches { return }
            try await Task.sleep(nanoseconds: 500_000_000)
        }
        throw RemoteError.message(failureMessage ?? "Command sent, but the expected screen did not become stable. Check the projector.")
    }
}
