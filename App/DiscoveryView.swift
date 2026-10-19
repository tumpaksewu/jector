import SwiftUI
import ProjectorCore

struct DiscoveryView: View {
    @EnvironmentObject private var remote: RemoteStore

    var body: some View {
            List {
                Section {
                    Label("Your projector, on your Wi-Fi", systemImage: "wifi")
                        .font(.headline).padding(.vertical, 4)
                    Text("Search for network ADB, then connect to confirm the projector. This version supports Formovie S5 controls.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Section("Nearby devices") {
                    Button(remote.scanning ? "Stop search" : "Search LAN", systemImage: remote.scanning ? "stop.circle" : "magnifyingglass") {
                        if remote.scanning { remote.stopScan() } else { remote.scan() }
                    }.disabled(remote.activity != nil)
                    if remote.scanning { ProgressView(value: remote.progress) }
                    Text(remote.scanStatus).font(.caption).foregroundStyle(.secondary)
                    ForEach(remote.devices) { device in
                        Button { remote.connect(device.endpoint) } label: {
                            HStack {
                                Image(systemName: "video.fill").frame(width: 28)
                                VStack(alignment: .leading) {
                                    Text(device.label).foregroundStyle(.primary)
                                    Text(device.endpoint.id).font(.caption.monospaced()).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption)
                            }
                        }.disabled(remote.activity != nil)
                    }
                }
                Section("Connect by address") {
                    TextField("IP address", text: $remote.host)
                        .keyboardType(.decimalPad).textInputAutocapitalization(.never).autocorrectionDisabled()
                        .accessibilityIdentifier("projectorHost")
                    TextField("Port", text: $remote.port).keyboardType(.numberPad)
                    Button("Connect", systemImage: "link") { remote.connect() }
                        .disabled(remote.activity != nil).accessibilityIdentifier("connectProjector")
                }
                Section {
                    if let activity = remote.activity {
                        HStack { ProgressView(); Text(activity).font(.subheadline) }
                        Button("Cancel", role: .cancel) { remote.disconnect() }
                    } else {
                        Label(remote.status, systemImage: remote.connectedAddress == nil ? "circle" : "checkmark.circle.fill")
                    }
                    if let error = remote.error { Text(error).foregroundStyle(.red).font(.subheadline) }
                    if let address = remote.connectedAddress {
                        Text(address).font(.caption.monospaced()).foregroundStyle(.secondary)
                        Button("Disconnect", role: .destructive) { remote.disconnect() }
                    }
                } footer: {
                    Text("On first connection, use the projector remote to allow this phone’s debugging key. The key stays in the iPhone Keychain. Search checks port 5555; use manual entry for other ports.")
                }
            }.navigationTitle("Projectors")
    }
}
