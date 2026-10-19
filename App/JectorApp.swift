import SwiftUI
import AVFoundation

@main
struct JectorApp: App {
    @StateObject private var remote = RemoteStore()
    @StateObject private var speech = SpeechProbe()
    @StateObject private var assistant = AssistantStore()
    @StateObject private var library = ModelLibrary()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            TabView {
                ControlsView().tabItem { Label("Remote", systemImage: "dpad") }
                AssistantView().tabItem { Label("Voice", systemImage: "mic") }
                AppsView().tabItem { Label("Apps", systemImage: "square.grid.2x2") }
            }
            .tint(.teal)
            .environmentObject(remote)
            .environmentObject(speech)
            .environmentObject(assistant)
            .environmentObject(library)
            .task {
                // Explicit development-only launch option; never sends ADB commands.
                if ProcessInfo.processInfo.arguments.contains("--check-commands") {
                    assistant.prepare()
                    await assistant.task?.value
                    assistant.runChecks()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
                assistant.cancel()
            }
            .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)) { _ in
                speech.cancel()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background { remote.suspend(); speech.cancel(); assistant.cancel(); library.cancelDownload() }
                if phase == .active { speech.refresh(); library.refresh() }
            }
        }
    }
}
