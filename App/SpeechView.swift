import SwiftUI

struct SpeechView: View {
    @EnvironmentObject private var speech: SpeechProbe

    var body: some View {
            List {
                Section {
                    Label("On-device speech probe", systemImage: "iphone.and.arrow.forward")
                        .font(.headline)
                    Text("Test English and Russian separately. Transcripts stay in this app and do not trigger projector actions.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text("Use the physical iPhone to record. iPhone Mirroring does not provide microphone access.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Capabilities reported by this iPhone") {
                    ForEach(speech.capabilities) { capability in
                        VStack(alignment: .leading, spacing: 6) {
                            Text("\(capability.name) · \(capability.id)").font(.headline)
                            flag("Locale supported", capability.supported)
                            flag("Recognizer available", capability.available)
                            flag("On-device recognition", capability.onDevice)
                        }.padding(.vertical, 5)
                    }
                    Text(speech.permission).font(.caption).foregroundStyle(.secondary)
                    Button("Refresh capabilities", systemImage: "arrow.clockwise") { speech.refresh() }
                    Button("Request speech & microphone access") { Task { _ = await speech.authorize() } }
                        .disabled(speech.active || speech.authorizing)
                }
                Section("Try a phrase") {
                    Picker("Language", selection: $speech.locale) {
                        Text("English").tag("en-US")
                        Text("Русский").tag("ru-RU")
                    }.pickerStyle(.segmented).disabled(speech.active || speech.authorizing)
                    Text(speech.locale == "ru-RU" ? "«Продолжи воспроизведение»\n«Установи громкость на тридцать процентов»" : "“Resume playback”\n“Set the volume to thirty percent”")
                        .font(.subheadline).foregroundStyle(.secondary)
                    if speech.active {
                        if speech.recording {
                            Button("Finish recording", systemImage: "stop.fill") { speech.stopListening() }
                        } else { ProgressView("Finishing…") }
                        Button("Cancel", role: .cancel) { speech.cancel() }
                    } else {
                        Button("Record on this iPhone", systemImage: "mic.fill") { Task { await speech.start() } }
                            .disabled(speech.authorizing).accessibilityIdentifier("recordSpeech")
                    }
                    Text(speech.status).font(.caption).foregroundStyle(.secondary)
                    if let error = speech.error { Text(error).font(.subheadline).foregroundStyle(.red) }
                }
                Section("Transcript") {
                    Text(speech.transcript.isEmpty ? "Your words will appear here." : speech.transcript)
                        .foregroundStyle(speech.transcript.isEmpty ? .secondary : .primary)
                        .textSelection(.enabled).frame(minHeight: 60, alignment: .topLeading)
                }
                Section {
                    ShareLink("Share capability report", item: speech.diagnostics)
                } footer: {
                    Text("On-device recognition is required for every recording. If unavailable, recording is blocked. The report excludes transcript text. Audio is not saved.")
                }
            }.navigationTitle("Speech")
    }

    private func flag(_ title: String, _ value: Bool) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Label(value ? "Yes" : "No", systemImage: value ? "checkmark.circle.fill" : "minus.circle")
                .foregroundStyle(value ? .teal : .secondary)
        }.font(.caption)
    }
}
