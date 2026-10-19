import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var remote: RemoteStore
    @EnvironmentObject private var assistant: AssistantStore

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink { DiscoveryView() } label: { Label("Projector connection", systemImage: "video") }
                    NavigationLink { ModelsView() } label: { Label("Models", systemImage: "internaldrive") }
                }
                HomeSettingsSection()
                Section("Voice") {
                    Toggle("Run commands automatically", isOn: $assistant.autoExecute)
                    Text("Off by default. Review each interpreted action before sending it to the projector.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Optional integration") {
                    Toggle("Show ATV Search", isOn: $remote.atvSearchEnabled)
                    Text("Adds ATV Search as a separate destination when installed. Direct searches in the four video apps work independently.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section {
                    CommandReferenceView()
                    NavigationLink("Diagnostics") { DiagnosticsView() }
                }
            }
            .navigationTitle("Settings")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

struct DiagnosticsView: View {
    @EnvironmentObject private var assistant: AssistantStore
    @EnvironmentObject private var speech: SpeechProbe
    @EnvironmentObject private var remote: RemoteStore
    var body: some View {
        List {
            Section("On-device model") {
                Text(assistant.selectedArtifact.name)
                Text(assistant.status).font(.subheadline)
                if let time = assistant.latency { Text(String(format: "Last inference: %.0f ms", time)) }
                if let time = assistant.loadMilliseconds { Text(String(format: "Last model load: %.0f ms", time)) }
                if let error = assistant.error { Text(error).foregroundStyle(.red) }
                if assistant.ready || assistant.busy {
                    Button("Stop and unload model") { assistant.cancel() }
                } else {
                    Button("Load selected model") { assistant.prepare() }
                }
                Button("Run command checks — no projector actions") { assistant.runChecks() }
                    .disabled(!assistant.ready || assistant.busy || speech.active)
            }
            Section {
                NavigationLink("English / Russian speech probe") { SpeechView() }
            }
            Section("Connection") {
                Text(remote.connectedAddress ?? "Disconnected").font(.caption.monospaced())
                if let info = remote.info { Text("\(info.model) · Android \(info.android)") }
                Text(remote.activity ?? remote.status)
                if let error = remote.error { Text(error).foregroundStyle(.red) }
            }
        }.navigationTitle("Diagnostics")
    }
}
