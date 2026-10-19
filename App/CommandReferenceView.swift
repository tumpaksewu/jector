import SwiftUI
import ProjectorCore

struct CommandReferenceView: View {
    @EnvironmentObject private var remote: RemoteStore
    private var apps: [ProjectorApp] {
        remote.info == nil
            ? ProjectorApp.allCases.filter { $0 != .atvSearch || remote.atvSearchEnabled }
            : remote.availableApps
    }

    var body: some View {
        DisclosureGroup("Available ADB commands") {
            Text("These are the actions exposed by this app. Voice uses six validated tools; navigation buttons are manual. No arbitrary shell commands are accepted.")
                .font(.caption).foregroundStyle(.secondary)
            entry("Volume · set_volume(level: 0–100)",
                  "media volume --stream 3 --set <device index>\nmedia volume --stream 3 --get",
                  detail: "Percent is converted to the projector’s volume range, then read back.")
            entry("Pause / play · pause_media / resume_media", "media dispatch pause\nmedia dispatch play")
            entry("Home · go_home", homeCommand,
                  detail: "Uses Settings → Home, for both the button and voice.")
            entry("Navigation · manual buttons", "input keyevent <code>\nUp 19 · Down 20 · Left 21 · Right 22 · OK 23 · Back 4")
            DisclosureGroup("Open apps · open_app(app)") {
                ForEach(apps) { app in
                    entry(app.title, app.launchCommand)
                }
            }
            DisclosureGroup("Search · search_app(app, query)") {
                Text("1–200 characters. Examples below use “space”; real queries are safely escaped and keep their language.")
                    .font(.caption).foregroundStyle(.secondary)
                ForEach(apps) { app in
                    if let request = try? SearchRequest(app: app, query: "space") {
                        entry(app.title, request.command)
                    }
                }
            }
            DisclosureGroup("Device checks · read only") {
                entry("Identity, apps and launcher detection", "getprop ro.product.model\ngetprop ro.build.version.release\npm list packages\ncmd package query-activities --brief -a android.intent.action.MAIN -c android.intent.category.HOME\ncmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.LAUNCHER -p com.spocky.projengmenu\nsettings get secure enabled_accessibility_services")
                entry("Foreground verification", "dumpsys window windows | grep mCurrentFocus")
            }
        }
    }

    private var homeCommand: String {
        if remote.homeLauncherID.isEmpty { return "input keyevent KEYCODE_HOME" }
        return remote.info?.launchers.first { $0.id == remote.homeLauncherID }?.command
            ?? "Selected launcher unavailable — choose another in Settings."
    }

    private func entry(_ title: String, _ command: String, detail: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline.weight(.medium))
            Text(command).font(.caption.monospaced()).textSelection(.enabled)
            if let detail { Text(detail).font(.caption).foregroundStyle(.secondary) }
        }.padding(.vertical, 4)
    }
}
