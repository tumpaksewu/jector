import SwiftUI
import ProjectorCore

struct AppsView: View {
    @EnvironmentObject private var remote: RemoteStore

    var body: some View {
        NavigationStack {
            Group {
                if remote.connectedAddress == nil { ConnectionPrompt() }
                else {
                    List {
                        ForEach(remote.availableApps) { app in AppSearchSection(app: app) }
                        if remote.availableApps.isEmpty {
                            Text("No supported video apps found on this projector.")
                        }
                        Section {
                            if let activity = remote.activity { HStack { ProgressView(); Text(activity) } }
                            else { Text(remote.status).foregroundStyle(.secondary) }
                            if let error = remote.error { Text(error).foregroundStyle(.red) }
                        } footer: {
                            Text("Search in English or Russian, including keyboard dictation. Results open on the projector; use Remote to choose a video.")
                        }
                    }.scrollDismissesKeyboard(.interactively)
                }
            }.navigationTitle("Apps").remoteToolbar()
        }
    }
}

private struct AppSearchSection: View {
    let app: ProjectorApp
    @EnvironmentObject private var remote: RemoteStore
    @State private var query = ""
    @FocusState private var editing: Bool

    var body: some View {
        Section {
            HStack {
                Text(app.title).font(.headline)
                Spacer()
                Button("Open", systemImage: "arrow.up.right") {
                    editing = false
                    remote.launch(app)
                }.buttonStyle(.bordered).accessibilityLabel("Open \(app.title)")
            }
            HStack {
                TextField("Search \(app.title)", text: $query)
                    .focused($editing).submitLabel(.search).onSubmit { search() }
                    .accessibilityIdentifier("searchQuery.\(app.rawValue)")
                Button("Search", systemImage: "magnifyingglass") { search() }
                    .labelStyle(.iconOnly).buttonStyle(.borderedProminent)
                    .accessibilityLabel("Search \(app.title)")
                    .disabled((try? SearchRequest.validate(query)) == nil)
            }
        }.disabled(remote.activity != nil)
    }

    private func search() {
        guard remote.activity == nil else { return }
        editing = false
        remote.search(app, query: query)
    }
}
