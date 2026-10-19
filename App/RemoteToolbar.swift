import SwiftUI

struct RemoteToolbar: ViewModifier {
    @State private var settings = false
    @State private var projectors = false
    @EnvironmentObject private var remote: RemoteStore

    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { projectors = true } label: {
                    Label(remote.connectedAddress == nil ? "Connect" : "Projector", systemImage: remote.connectedAddress == nil ? "link" : "video.fill")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Settings", systemImage: "gearshape") { settings = true }
                    .labelStyle(.iconOnly)
            }
        }
        .sheet(isPresented: $settings) { SettingsView() }
        .sheet(isPresented: $projectors) {
            NavigationStack {
                DiscoveryView().toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { projectors = false } } }
            }
        }
    }
}

extension View {
    func remoteToolbar() -> some View { modifier(RemoteToolbar()) }
}

struct ConnectionPrompt: View {
    @State private var showing = false
    var body: some View {
        ContentUnavailableView {
            Label("Connect your projector", systemImage: "video")
        } description: {
            Text("Join the same Wi-Fi network, then choose your projector.")
        } actions: {
            Button("Find projector") { showing = true }.buttonStyle(.borderedProminent)
        }
        .sheet(isPresented: $showing) {
            NavigationStack {
                DiscoveryView().toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showing = false } } }
            }
        }
    }
}
