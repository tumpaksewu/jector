import SwiftUI
import ProjectorInference

struct ModelsView: View {
    @EnvironmentObject private var library: ModelLibrary
    @EnvironmentObject private var assistant: AssistantStore
    @State private var deleting: ModelArtifact?

    var body: some View {
            List {
                Section {
                    Label("\(library.storageLabel) used by models", systemImage: "internaldrive")
                    Text("Models download directly to this iPhone over Wi-Fi. No model weights ship with the app. Downloads are checked before use.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text(library.status).font(.caption)
                    if let error = library.error { Text(error).foregroundStyle(.red) }
                }
                ForEach(ModelArtifact.allCases) { artifact in
                    Section {
                        HStack {
                            Text(artifact.name).font(.headline)
                            Spacer()
                            if assistant.selectedArtifact == artifact {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.teal)
                            }
                        }
                        Text("\(artifact.sizeLabel) download · English / Russian")
                            .font(.caption).foregroundStyle(.secondary)
                        Text(artifact == .q4 ? "Recommended starting point: lower memory use." : "Higher precision and memory use. Optional alternative to Q4.")
                            .font(.subheadline)
                        if library.active == artifact {
                            if library.downloading {
                                ProgressView(value: library.progress)
                                Text("\(Int(library.progress * 100))% downloaded").font(.caption)
                                Button("Cancel download") { library.cancelDownload() }
                            } else { ProgressView("Removing model…") }
                        } else if library.downloaded.contains(artifact) {
                            Label("Downloaded", systemImage: "checkmark.circle")
                            if assistant.selectedArtifact != artifact {
                                Button("Use this model") { assistant.select(artifact) }
                                    .disabled(assistant.busy || library.active != nil)
                            } else if assistant.ready {
                                Button("Unload from memory") { assistant.cancel() }
                                    .disabled(assistant.busy)
                            } else {
                                Button("Load into memory") { assistant.prepare() }
                                    .disabled(assistant.busy || library.active != nil)
                            }
                            Button("Delete download", role: .destructive) { deleting = artifact }
                                .disabled(assistant.busy || library.active != nil)
                        } else {
                            Button("Download · \(artifact.sizeLabel)", systemImage: "arrow.down.circle") { library.download(artifact) }
                                .disabled(library.active != nil)
                        }
                    }
                }
                Section {
                    Text("Unloading releases model memory and keeps the download. Deleting removes the weights; you can download them again. Keep the app open during downloads; backgrounding cancels them.")
                        .font(.caption).foregroundStyle(.secondary)
                    Link("Model source and license", destination: URL(string: "https://huggingface.co/ggml-org/Qwen3-1.7B-GGUF")!)
                }
            }
            .navigationTitle("Models")
            .onAppear { library.refresh() }
            .confirmationDialog("Delete downloaded model?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
                if let artifact = deleting {
                    Button("Delete \(artifact.name)", role: .destructive) { library.delete(artifact, assistant: assistant); deleting = nil }
                }
            } message: { Text("The model will be unloaded and its file removed from this iPhone.") }
    }
}
