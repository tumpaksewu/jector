import SwiftUI
import ProjectorCore
import ProjectorInference

@MainActor
final class AssistantStore: ObservableObject {
    @Published var input = ""
    @Published var ready = false
    @Published var busy = false
    @Published var status = "Load the model to interpret English or Russian commands."
    @Published var error: String?
    @Published var actions: [ProjectorAction] = []
    @Published var latency: Double?
    @Published var selectedArtifact = ModelArtifact(rawValue: UserDefaults.standard.string(forKey: "model.selected") ?? "q4") ?? .q4
    @Published var autoExecute = false
    var loadMilliseconds: Double?
    private(set) var plannedJSON: String?
    private(set) var plannedEndpoint: String?
    let model = LocalModel()
    let files = ModelFiles()
    var task: Task<Void, Never>?
    var operationID = UUID()

    func prepare() {
        guard !busy else { return }
        error = nil; busy = true; ready = false
        let artifact = selectedArtifact
        status = "Verifying model…"
        let id = UUID(); operationID = id
        task = Task {
            defer { if operationID == id { busy = false } }
            do {
                guard ModelFiles.exists(artifact) else { throw InferenceError.message("Download a model in Settings → Models first.") }
                try await files.verify(artifact)
                try Task.checkCancellation()
                status = "Loading model on this iPhone…"
                let started = Date()
                try await model.load(path: ModelFiles.url(for: artifact).path)
                loadMilliseconds = Date().timeIntervalSince(started) * 1000
                try Task.checkCancellation()
                ready = true; status = "Ready · \(artifact.name) · on-device"
            } catch {
                if operationID == id { self.error = error.localizedDescription; status = "Model unavailable" }
            }
        }
    }

    func select(_ artifact: ModelArtifact) {
        guard !busy, selectedArtifact != artifact else { return }
        cancel()
        selectedArtifact = artifact
        UserDefaults.standard.set(artifact.rawValue, forKey: "model.selected")
    }

    func interpret(remote: RemoteStore) {
        guard ready, !busy else { return }
        clearPlan(); error = nil; latency = nil
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let endpoint = remote.connectedAddress
        let apps = remote.info == nil ? ProjectorApp.allCases.filter { $0 != .atvSearch || remote.atvSearchEnabled } : remote.availableApps
        busy = true; status = "Interpreting on this iPhone…"
        let id = UUID(); operationID = id
        task = Task {
            defer { if operationID == id { busy = false } }
            do {
                let result = try await model.interpret(text)
                try Task.checkCancellation()
                let plan = try ToolPlan(json: result.json, installedApps: apps)
                try plan.validateSearchTargets(in: text)
                actions = plan.actions; plannedJSON = result.json; plannedEndpoint = endpoint
                latency = result.milliseconds
                status = actions.isEmpty ? "No supported action. Try a specific projector command." : "Review the actions below."
                if autoExecute, !actions.isEmpty, endpoint != nil { execute(remote: remote) }
            } catch {
                if operationID == id { self.error = error.localizedDescription; status = "Nothing sent"; clearPlan() }
            }
        }
    }

    func execute(remote: RemoteStore) {
        guard let json = plannedJSON, let endpoint = plannedEndpoint,
              endpoint == remote.connectedAddress, remote.activity == nil else {
            error = "Connect to the projector, then interpret the command again."
            return
        }
        remote.executePlan(json, expectedEndpoint: endpoint)
        clearPlan(); status = "Sent to the projector command queue. See execution status below."
    }

    func clearPlan() { actions = []; plannedJSON = nil; plannedEndpoint = nil }

    func cancel() {
        task?.cancel()
        let id = UUID(); operationID = id
        clearPlan(); busy = true; ready = false
        status = "Stopping and releasing model memory…"
        task = Task {
            await model.unload()
            guard operationID == id else { return }
            busy = false; status = "Stopped. Load the model when ready."
        }
    }
}
