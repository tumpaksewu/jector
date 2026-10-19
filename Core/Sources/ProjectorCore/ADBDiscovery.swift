import Foundation
import Network
import SwiftADB

private final class EndpointProbe: @unchecked Sendable {
    let endpoint: Endpoint
    private let queue = DispatchQueue(label: "remote.adb.discovery")
    private var connection: NWConnection?
    private var continuation: CheckedContinuation<DiscoveredDevice?, Never>?
    private var buffer = Data()
    private var cancelled = false
    private var timeout: DispatchWorkItem?

    init(_ endpoint: Endpoint) { self.endpoint = endpoint }

    func run() async -> DiscoveredDevice? {
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                queue.async {
                    self.continuation = continuation
                    if self.cancelled { self.finish(nil); return }
                    self.start()
                }
            }
        } onCancel: { self.cancel() }
    }

    private func start() {
        let conn = NWConnection(host: .init(endpoint.host), port: .init(rawValue: endpoint.port)!, using: .tcp)
        connection = conn
        conn.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                conn.send(content: AdbProtocol.generateConnect(api: 28), completion: .contentProcessed { error in
                    if error != nil { self.finish(nil) } else { self.receive() }
                })
            case .failed, .cancelled: self.finish(nil)
            default: break
            }
        }
        let timeout = DispatchWorkItem { [weak self] in self?.finish(nil) }
        self.timeout = timeout
        queue.asyncAfter(deadline: .now() + 1.2, execute: timeout)
        conn.start(queue: queue)
    }

    private func receive() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, complete, error in
            guard let self, self.continuation != nil else { return }
            if let data { self.buffer.append(data) }
            if let result = Self.identify(self.buffer, endpoint: self.endpoint) { self.finish(result); return }
            if complete || error != nil || self.buffer.count > 4096 { self.finish(nil); return }
            self.receive()
        }
    }

    static func identify(_ data: Data, endpoint: Endpoint) -> DiscoveredDevice? {
        guard data.count >= 24 else { return nil }
        func word(_ offset: Int) -> UInt32 {
            (0..<4).reduce(0) { $0 | UInt32(data[offset + $1]) << (8 * $1) }
        }
        let command = word(0), length = Int(word(12))
        guard command == ~word(20), length <= 4072, data.count >= 24 + length else { return nil }
        if command == AdbProtocol.aAuth && word(4) == 1 && length == 20 {
            return DiscoveredDevice(endpoint: endpoint, label: "ADB device", needsAuthorization: true)
        }
        guard command == AdbProtocol.aCnxn else { return nil }
        let banner = String(decoding: data[24..<(24 + length)], as: UTF8.self)
        let model = banner.components(separatedBy: ";").first { $0.contains("ro.product.model=") }?
            .components(separatedBy: "=").last?.replacingOccurrences(of: "_", with: " ")
        return DiscoveredDevice(endpoint: endpoint, label: model ?? "ADB device", needsAuthorization: false)
    }

    private func cancel() { queue.async { self.cancelled = true; self.finish(nil) } }
    private func finish(_ device: DiscoveredDevice?) {
        timeout?.cancel()
        timeout = nil
        connection?.stateUpdateHandler = nil
        connection?.cancel()
        connection = nil
        let pending = continuation
        continuation = nil
        pending?.resume(returning: device)
    }
}

public enum ADBDiscovery {
    public static func probe(_ endpoint: Endpoint) async -> DiscoveredDevice? {
        await EndpointProbe(endpoint).run()
    }

    public static func scan(_ subnet: LANSubnet,
                            progress: @Sendable (Int, Int, DiscoveredDevice?) async -> Void) async {
        let hosts = subnet.hosts
        await withTaskGroup(of: DiscoveredDevice?.self) { group in
            var next = 0, completed = 0
            func enqueue(_ host: String) {
                group.addTask {
                    guard !Task.isCancelled, let endpoint = try? Endpoint(host: host) else { return nil }
                    return await probe(endpoint)
                }
            }
            while next < min(24, hosts.count) { enqueue(hosts[next]); next += 1 }
            for await device in group {
                completed += 1
                await progress(completed, hosts.count, device)
                if Task.isCancelled { group.cancelAll(); continue }
                if next < hosts.count { enqueue(hosts[next]); next += 1 }
            }
        }
    }
}
