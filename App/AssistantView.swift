import SwiftUI
import ProjectorInference

struct AssistantView: View {
    @EnvironmentObject private var assistant: AssistantStore
    @EnvironmentObject private var speech: SpeechProbe
    @EnvironmentObject private var remote: RemoteStore
    @State private var awaitingSpeech = false

    var body: some View {
        NavigationStack {
            List {
                if !assistant.ready {
                    Section {
                        if assistant.busy { ProgressView("Preparing voice…") }
                        else if ModelFiles.exists(assistant.selectedArtifact) {
                            Button("Enable voice commands", systemImage: "mic") { assistant.prepare() }
                        } else {
                            Text("Download a model in Settings → Models to enable voice commands.")
                        }
                        if let error = assistant.error { Text(error).foregroundStyle(.red) }
                    }
                }
                Section("Speak or type a command") {
                    Picker("Language", selection: $speech.locale) {
                        Text("English").tag("en-US")
                        Text("Русский").tag("ru-RU")
                    }.pickerStyle(.segmented).disabled(speech.active || assistant.busy)
                    TextField("Find space on YouTube / Найди космос в VK", text: $assistant.input, axis: .vertical)
                        .lineLimit(2...5).disabled(assistant.busy || speech.active)
                    if speech.active {
                        Text(speech.transcript).font(.subheadline)
                        if speech.recording {
                            Button("Finish recording", systemImage: "stop.fill") { speech.stopListening() }
                        } else { ProgressView("Finishing transcription…") }
                        Button("Cancel recording") { awaitingSpeech = false; speech.cancel() }
                    } else {
                        Button("Speak on this iPhone", systemImage: "mic.fill") {
                            awaitingSpeech = true
                            Task { await speech.start() }
                        }.disabled(!assistant.ready || assistant.busy || speech.authorizing)
                    }
                    if let error = speech.error { Text(error).foregroundStyle(.red) }
                    Button("Interpret text", systemImage: "sparkle.magnifyingglass") { assistant.interpret(remote: remote) }
                        .disabled(!assistant.ready || assistant.busy || speech.active || assistant.input.isEmpty)

                }
                Section("Projector actions") {
                    ForEach(Array(assistant.actions.enumerated()), id: \.offset) { index, action in
                        Text("\(index + 1). \(action.title)")
                    }
                    if assistant.actions.isEmpty && assistant.plannedJSON != nil && !assistant.busy {
                        Text("No supported action. Name an app and query, or a specific remote command.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    if !assistant.actions.isEmpty {
                        Button("Run on projector", systemImage: "play.fill") { assistant.execute(remote: remote) }
                            .disabled(remote.connectedAddress == nil || remote.activity != nil || assistant.busy)
                    }
                    Text(remote.connectedAddress == nil ? "Tap Connect to choose your projector." : "Projector connected")
                        .font(.caption).foregroundStyle(.secondary)
                    if assistant.busy { ProgressView("Interpreting…") }
                    if !assistant.actions.isEmpty { Text("Review the app, query and actions before running.").font(.subheadline) }
                    if let error = assistant.error { Text(error).foregroundStyle(.red) }
                    Text(remote.activity ?? remote.status).font(.subheadline)
                    if let error = remote.error { Text(error).foregroundStyle(.red) }
                }

            }
            .navigationTitle("Voice").remoteToolbar()
            .onAppear { if !assistant.ready && !assistant.busy && ModelFiles.exists(assistant.selectedArtifact) { assistant.prepare() } }
            .onChange(of: assistant.input) { _, _ in assistant.clearPlan() }
            .onChange(of: remote.atvSearchEnabled) { _, _ in assistant.clearPlan() }
            .onChange(of: remote.connectedAddress) { _, _ in assistant.clearPlan() }
            .onChange(of: speech.completionID) { _, _ in
                guard awaitingSpeech else { return }
                awaitingSpeech = false
                assistant.input = speech.transcript
                assistant.interpret(remote: remote)
            }
            .onDisappear { awaitingSpeech = false; if speech.active { speech.cancel() } }
        }
    }
}
