import SwiftUI
import ProjectorInference

@MainActor
final class ModelLibrary: ObservableObject {
    @Published var downloaded: Set<ModelArtifact> = []
    @Published var active: ModelArtifact?
    @Published var progress = 0.0
    @Published var downloading = false
    @Published var status = "No weights are bundled. Download a model over Wi-Fi."
    @Published var error: String?
    private let files = ModelFiles()
    private var task: Task<Void, Never>?

    init() { refresh() }
    func refresh() { downloaded = Set(ModelArtifact.allCases.filter { ModelFiles.exists($0) }) }
    var storageLabel: String {
        ByteCountFormatter.string(fromByteCount: downloaded.reduce(0) { $0 + $1.bytes }, countStyle: .file)
    }

    func download(_ artifact: ModelArtifact) {
        guard active == nil else { return }
        active = artifact; downloading = true; progress = 0; error = nil; status = "Downloading \(artifact.name)…"
        task = Task {
            defer { active = nil; downloading = false; refresh() }
            do {
                try await files.download(artifact) { [weak self] progress in
                    Task { @MainActor in
                        guard self?.active == artifact else { return }
                        self?.progress = progress
                        if progress >= 1 { self?.status = "Verifying download…" }
                    }
                }
                try Task.checkCancellation()
                status = "\(artifact.name) downloaded and verified."
            } catch {
                if Task.isCancelled { status = "Download cancelled. Temporary data removed." }
                else { self.error = error.localizedDescription; status = "Download failed. Retry when ready." }
            }
        }
    }

    func cancelDownload() { task?.cancel() }

    func delete(_ artifact: ModelArtifact, assistant: AssistantStore) {
        guard active == nil, !assistant.busy else { return }
        active = artifact; error = nil; status = "Removing \(artifact.name)…"
        task = Task {
            defer { active = nil; refresh() }
            if assistant.selectedArtifact == artifact {
                assistant.cancel()
                await assistant.task?.value
            }
            do {
                try await files.delete(artifact)
                status = "\(artifact.name) removed from this iPhone."
            } catch { self.error = error.localizedDescription }
        }
    }
}
