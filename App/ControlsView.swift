import SwiftUI
import ProjectorCore

struct ControlsView: View {
    @EnvironmentObject private var remote: RemoteStore

    var body: some View {
        NavigationStack {
            Group {
                if remote.info != nil {
                    List {
                        Section {
                            Label("Formovie S5", systemImage: "video.fill").font(.headline)
                            Text("Connected")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Section("Navigation") {
                            VStack(spacing: 12) {
                                keyButton("Up", icon: "chevron.up", key: .up)
                                HStack(spacing: 16) {
                                    keyButton("Left", icon: "chevron.left", key: .left)
                                    Button("OK") { remote.key(.select) }
                                        .font(.headline).frame(width: 64, height: 52).buttonStyle(.borderedProminent)
                                    keyButton("Right", icon: "chevron.right", key: .right)
                                }
                                keyButton("Down", icon: "chevron.down", key: .down)
                                HStack {
                                    Button("Back", systemImage: "arrow.uturn.backward") { remote.key(.back) }
                                    Spacer()
                                    Button("Home", systemImage: "house") { remote.home() }
                                }.buttonStyle(.bordered)
                            }.frame(maxWidth: .infinity).padding(.vertical, 8)
                        }.disabled(remote.activity != nil)
                        Section("Volume") {
                            HStack {
                                Text("\(Int(remote.volumeDraft))%").font(.title2.monospacedDigit())
                                Spacer()
                                if let volume = remote.volume {
                                    Text("Verified: \(volume.percent)%").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Slider(value: $remote.volumeDraft, in: 0...100, step: 2).accessibilityLabel("Volume percent")
                            HStack {
                                Button("Apply volume") { remote.applyVolume() }.buttonStyle(.borderedProminent)
                                Spacer()
                                Button("Refresh", systemImage: "arrow.clockwise") { remote.refreshVolume() }
                            }
                        }.disabled(remote.activity != nil)
                        Section {
                            HStack {
                                Button("Pause", systemImage: "pause.fill") { remote.playback(play: false) }
                                Spacer()
                                Button("Play", systemImage: "play.fill") { remote.playback(play: true) }
                            }.buttonStyle(.bordered)
                        } header: { Text("Playback") } footer: {
                            Text("Playback buttons send explicit commands. The current app must support media controls; check the projector for the result.")
                        }.disabled(remote.activity != nil)
                        Section {
                            if let activity = remote.activity { HStack { ProgressView(); Text(activity) } }
                            else { Text(remote.status).foregroundStyle(.secondary) }
                            if let error = remote.error { Text(error).foregroundStyle(.red) }
                        }
                    }
                } else {
                    ConnectionPrompt()
                }
            }.navigationTitle("Remote").remoteToolbar()
        }
    }

    private func keyButton(_ name: String, icon: String, key: RemoteKey) -> some View {
        Button { remote.key(key) } label: { Image(systemName: icon).frame(width: 42, height: 34) }
            .buttonStyle(.bordered).accessibilityLabel(name)
    }
}
