import Testing
@testable import ProjectorCore

struct HomeLauncherTests {
    @Test func discoversLaunchersAndRejectsShellText() throws {
        let result = HomeLauncher.parse("""
        2 activities found:
          priority=0 preferredOrder=0
          com.tvfengmi.launcher/com.gala.video.app.epg.HomeActivity
          com.android.tv.settings/.system.FallbackHome
          com.spocky.projengmenu/.ui.home.MainActivity
          com.spocky.projengmenu/.ui.home.MainActivity
        """)
        #expect(result.map(\.title) == ["FengOS", "Projectivy"])
        for unsafe in ["com.example/.Home;reboot", "com.example/$(reboot)", "com.example/.Home\nreboot", "com.example/.Home\n", "-n com.example/.Home"] {
            #expect(throws: (any Error).self) { try HomeLauncher(component: unsafe) }
        }
        #expect(result[1].command == "am start -a android.intent.action.MAIN -f 0x10200000 -n com.spocky.projengmenu/.ui.home.MainActivity")
    }

    @Test func missingSelectionNeverSilentlyFallsBack() throws {
        let launcher = try HomeLauncher(component: "com.spocky.projengmenu/.ui.home.MainActivity")
        #expect(try HomeLauncher.selected("", installed: [launcher]) == nil)
        #expect(try HomeLauncher.selected(launcher.id, installed: [launcher]) == launcher)
        #expect(throws: (any Error).self) { try HomeLauncher.selected(launcher.id, installed: []) }
        #expect(throws: (any Error).self) { try HomeLauncher.selected("com.example/.Home", installed: [launcher]) }
    }
}
