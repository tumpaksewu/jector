import SwiftUI
import ProjectorCore

struct HomeSettingsSection: View {
    @EnvironmentObject private var remote: RemoteStore

    var body: some View {
        Section {
            if let info = remote.info {
                Picker("Home button", selection: $remote.homeLauncherID) {
                    Text("Projector default").tag("")
                    ForEach(info.launchers) { Text($0.title).tag($0.id) }
                    if !remote.homeLauncherID.isEmpty && !info.launchers.contains(where: { $0.id == remote.homeLauncherID }) {
                        Text("Unavailable launcher").tag(remote.homeLauncherID)
                    }
                }.disabled(remote.activity != nil)
                if remote.homeLauncherID.hasPrefix("com.tvfengmi.launcher/") && info.projectivyAccessibilityEnabled {
                    Text("Projectivy’s accessibility service is enabled. If FengOS redirects to Projectivy, turn off Override current launcher in Projectivy’s settings.")
                        .font(.caption).foregroundStyle(.orange)
                }
            } else {
                Text("Connect to choose a Home launcher.").foregroundStyle(.secondary)
            }
        } header: { Text("Home") } footer: {
            Text("Used by the Home button and voice commands. Saved for this projector. Projector default follows its Home key behavior. Explicit choices open the launcher directly; projector accessibility rules may still redirect it.")
        }
    }
}
