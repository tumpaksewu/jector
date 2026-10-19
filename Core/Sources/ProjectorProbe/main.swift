import Foundation
import Security
import SwiftADB
import ProjectorCore

@main
struct ProjectorProbe {
    static func main() async throws {
        let args = CommandLine.arguments
        guard let host = args.dropFirst().first else {
            throw RemoteError.message("Usage: ProjectorProbe <projector IPv4> [--existing-mac-key] [--scan] [--exercise]")
        }
        let endpoint = try Endpoint(host: host)
        let subnet = try LANSubnet.wifi()
        print("LAN: \(subnet.description); \(subnet.hosts.count) candidate hosts")
        if args.contains("--scan") {
            await ADBDiscovery.scan(subnet) { _, _, device in
                if let device { print("Found: \(device.endpoint.id) · \(device.label)") }
            }
        }
        if let found = await ADBDiscovery.probe(endpoint) {
            print("Handshake: \(found.label), authorization challenge: \(found.needsAuthorization)")
        } else { throw RemoteError.message("ADB discovery handshake failed.") }
        guard args.contains("--existing-mac-key") else { return }
        // Read the already-authorized desktop key into memory for this Mac-only
        // diagnostic. Never copy it to the iOS app or print its contents.
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/openssl")
        process.arguments = ["rsa", "-in", NSHomeDirectory() + "/.android/adbkey", "-outform", "DER"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0,
              let privateKey = SecKeyCreateWithData(data as CFData, [
                kSecAttrKeyType: kSecAttrKeyTypeRSA, kSecAttrKeyClass: kSecAttrKeyClassPrivate
              ] as CFDictionary, nil),
              let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw RemoteError.message("Could not load the existing desktop ADB key.")
        }
        let session = ProjectorSession()
        do {
            try await session.connect(to: endpoint, key: KeyPair(privateKey: privateKey, publicKey: publicKey))
            let controls = ProjectorCommands(session: session)
            let info = try await controls.inspect()
            print("Connected: \(info.model), Android \(info.android)")
            print("Volume: \(info.volume.index)/\(info.volume.maximum) (\(info.volume.percent)%)")
            print("Apps: \(info.apps.map(\.title).joined(separator: ", "))")
            print("Home launchers: \(info.launchers.map(\.title).joined(separator: ", "))")
            if args.contains("--exercise") {
                let originalFocus = try await session.shell("dumpsys window windows | grep mCurrentFocus")
                guard originalFocus.contains("com.formovie.screensaver") else {
                    throw RemoteError.message("Controls test requires the projector to be on its screensaver.")
                }
                do {
                    let lower = max(0, info.volume.percent - 2)
                    let changed = try await controls.setVolume(percent: lower, current: info.volume)
                    print("Volume write/read: \(changed.index)/\(changed.maximum)")
                    _ = try await controls.setVolume(percent: info.volume.percent, current: changed)
                    try await controls.launch(.youtube)
                    print("YouTube foreground verified")
                    try await controls.home(launcher: nil, available: info.launchers)
                    print("Home foreground verified")
                    try await controls.launch(.jellyfin)
                    print("Jellyfin foreground verified")
                } catch {
                    // Restore over a new connection if a transport failure closed it.
                    await session.disconnect()
                    try await session.connect(to: endpoint, key: KeyPair(privateKey: privateKey, publicKey: publicKey))
                    _ = try await session.shell("media volume --stream 3 --set \(info.volume.index)")
                    _ = try await session.shell("am start -W -n com.formovie.screensaver/com.formovie.screensaver.FengDesktopActivity")
                    throw error
                }
                _ = try await session.shell("am start -W -n com.formovie.screensaver/com.formovie.screensaver.FengDesktopActivity")
                let restored = try await controls.readVolume()
                guard restored.index == info.volume.index else { throw RemoteError.message("Volume restoration failed") }
                print("Original volume and screensaver restored")
            }
            await session.disconnect()
            print("PASS: shared Swift transport authenticated and read device state. Disconnected.")
        } catch {
            await session.disconnect()
            throw error
        }
    }
}
