import SwiftUI
import ProjectorCore

extension RemoteStore {
    func selectedHomeLauncher() throws -> HomeLauncher? {
        try HomeLauncher.selected(homeLauncherID, installed: info?.launchers ?? [])
    }

    func executePlan(_ json: String, expectedEndpoint: String) {
        guard connectedAddress == expectedEndpoint, let info, activity == nil else { return }
        do {
            let plan = try ToolPlan(json: json, installedApps: availableApps)
            guard !plan.actions.isEmpty else { return }
            let launcher = plan.actions.contains(.home) ? try selectedHomeLauncher() : nil
            perform("Running voice command…") {
                var completed = 0
                do {
                    for action in plan.actions {
                        try Task.checkCancellation()
                        guard self.connectedAddress == expectedEndpoint else { throw CancellationError() }
                        self.status = "\(completed)/\(plan.actions.count) complete · \(action.title)"
                        switch action {
                        case .volume(let level):
                            let current = try await self.controls.readVolume()
                            let actual = try await self.controls.setVolume(percent: level, current: current)
                            self.volume = actual; self.volumeDraft = Double(actual.percent)
                        case .pause: _ = try await self.controls.media(play: false)
                        case .resume: _ = try await self.controls.media(play: true)
                        case .open(let app): try await self.controls.launch(app)
                        case .search(let app, let query): try await self.controls.search(app, query: query)
                        case .home: try await self.controls.home(launcher: launcher, available: info.launchers)
                        }
                        completed += 1
                    }
                    return "\(completed) command(s) completed. Search and playback report delivery; check results on the projector."
                } catch {
                    throw RemoteError.message("Stopped after \(completed) completed command(s). \(error.localizedDescription) Check the projector before retrying.")
                }
            }
        } catch { self.error = error.localizedDescription }
    }

}
