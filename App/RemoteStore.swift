import SwiftUI
import ProjectorCore

@MainActor
final class RemoteStore: ObservableObject {
    @Published var host = UserDefaults.standard.string(forKey: "projector.host") ?? ""
    @Published var port = UserDefaults.standard.string(forKey: "projector.port") ?? "5555"
    @Published var devices: [DiscoveredDevice] = []
    @Published var scanStatus = "Search your Wi-Fi network or enter an address."
    @Published var scanning = false
    @Published var progress = 0.0
    @Published var info: ProjectorInfo?
    @Published var volume: Volume?
    @Published var volumeDraft = 28.0
    @Published var connectedAddress: String?
    @Published var activity: String?
    @Published var status = "Not connected"
    @Published var error: String?
    @Published var atvSearchEnabled = UserDefaults.standard.bool(forKey: "search.atvEnabled") {
        didSet { UserDefaults.standard.set(atvSearchEnabled, forKey: "search.atvEnabled") }
    }
    @Published var homeLauncherID = "" {
        didSet {
            if let connectedAddress { UserDefaults.standard.set(homeLauncherID, forKey: "home.launcher." + connectedAddress) }
        }
    }
    var availableApps: [ProjectorApp] {
        (info?.apps ?? []).filter { $0 != .atvSearch || atvSearchEnabled }
    }
    private let session = ProjectorSession()
    private var scanTask: Task<Void, Never>?
    private var commandTask: Task<Void, Never>?
    var controls: ProjectorCommands { ProjectorCommands(session: session) }

    func scan() {
        guard !scanning else { return }
        do {
            let subnet = try LANSubnet.wifi()
            devices = []; progress = 0; scanning = true
            scanStatus = "Searching \(subnet.description) · port 5555"
            scanTask = Task {
                await ADBDiscovery.scan(subnet) { done, total, device in
                    await MainActor.run {
                        guard self.scanning else { return }
                        self.progress = Double(done) / Double(max(total, 1))
                        if let device, !self.devices.contains(where: { $0.id == device.id }) {
                            self.devices.append(device)
                        }
                    }
                }
                if !Task.isCancelled {
                    scanStatus = devices.isEmpty
                        ? "No ADB devices found. Check Wi-Fi, Local Network permission and network ADB; then search again."
                        : "Found \(devices.count) ADB device(s). Connect to confirm the model."
                }
                scanning = false
            }
        } catch { self.error = error.localizedDescription }
    }

    func stopScan() {
        scanTask?.cancel(); scanTask = nil
        scanning = false; scanStatus = "Search cancelled."
    }

    func connect(_ endpoint: Endpoint? = nil) {
        guard activity == nil else { return }
        do {
            let target: Endpoint
            if let endpoint { target = endpoint }
            else {
                guard let port = UInt16(port) else { throw RemoteError.message("Enter a valid port.") }
                target = try Endpoint(host: host, port: port)
            }
            stopScan()
            info = nil; volume = nil; connectedAddress = nil
            perform("Connecting… Allow debugging on the projector if prompted.") {
                try await self.session.connect(to: target)
                let info = try await self.controls.inspect()
                self.info = info; self.volume = info.volume
                self.volumeDraft = Double(info.volume.percent)
                self.connectedAddress = target.id
                self.homeLauncherID = UserDefaults.standard.string(forKey: "home.launcher." + target.id) ?? ""
                self.host = target.host; self.port = String(target.port)
                UserDefaults.standard.set(target.host, forKey: "projector.host")
                UserDefaults.standard.set(String(target.port), forKey: "projector.port")
                return "Connected to \(info.model)"
            }
        } catch { self.error = error.localizedDescription }
    }

    func perform(_ title: String, operation: @escaping @MainActor () async throws -> String) {
        guard activity == nil else { return }
        error = nil; activity = title
        commandTask = Task {
            defer { activity = nil }
            do {
                let result = try await operation()
                try Task.checkCancellation()
                status = result
            } catch {
                if !Task.isCancelled { self.error = error.localizedDescription }
                await session.disconnect()
                connectedAddress = nil; info = nil; volume = nil
                status = "Disconnected. Reconnect before retrying."
            }
        }
    }

    func applyVolume() {
        guard let volume else { return }
        let percent = Int(volumeDraft.rounded())
        perform("Setting volume…") {
            let actual = try await self.controls.setVolume(percent: percent, current: volume)
            self.volume = actual; self.volumeDraft = Double(actual.percent)
            return "Volume verified: \(actual.percent)%"
        }
    }

    func refreshVolume() {
        perform("Reading volume…") {
            let actual = try await self.controls.readVolume()
            self.volume = actual; self.volumeDraft = Double(actual.percent)
            return "Volume refreshed"
        }
    }

    func key(_ key: RemoteKey) { perform("Sending button…") { try await self.controls.key(key); return "Button sent" } }
    func home() {
        guard let info else { return }
        do {
            let launcher = try selectedHomeLauncher()
            perform("Opening Home…") {
                try await self.controls.home(launcher: launcher, available: info.launchers)
                return "\(launcher?.title ?? "Home") verified"
            }
        } catch { self.error = error.localizedDescription }
    }
    func launch(_ app: ProjectorApp) {
        perform("Opening \(app.title)…") { try await self.controls.launch(app); return "\(app.title) opened" }
    }
    func playback(play: Bool) { perform("Sending playback command…") { try await self.controls.media(play: play) } }

    func search(_ app: ProjectorApp, query: String) {
        guard connectedAddress != nil, availableApps.contains(app) else {
            error = "Connect to a projector with this app installed and enabled."
            return
        }
        do {
            let request = try SearchRequest(app: app, query: query)
            perform("Searching \(app.title)…") {
                try await self.controls.search(app, query: request.query)
                return "Search sent to \(app.title). Results appear on the projector."
            }
        } catch { self.error = error.localizedDescription }
    }

    func disconnect() {
        commandTask?.cancel()
        connectedAddress = nil; info = nil; volume = nil; status = "Disconnected"
        Task { await session.disconnect() }
    }
    func suspend() { stopScan(); disconnect() }
}
