import Foundation
import SwiftADB

public actor ProjectorSession {
    private var connection: AdbConnection?
    private var busy = false

    public init() {}

    public func connect(to endpoint: Endpoint, key: KeyPair? = nil) async throws {
        guard !busy else { throw RemoteError.message("Another projector request is running.") }
        busy = true
        defer { busy = false }
        await disconnect()
        let conn = AdbConnection(host: endpoint.host, port: endpoint.port,
                                 keyPair: try key ?? ADBKeyStore.loadOrCreate(), api: 28,
                                 deviceName: "Jector")
        connection = conn
        // The library timeout covers authentication only. Close the socket as well
        // so an unreachable TCP endpoint cannot leave the UI waiting indefinitely.
        let deadline = Task {
            do { try await Task.sleep(nanoseconds: 35_000_000_000) } catch { return }
            await conn.close()
        }
        defer { deadline.cancel() }
        do {
            let success = try await withTaskCancellationHandler {
                try await conn.connect(timeout: 30)
            } onCancel: { Task { await conn.close() } }
            guard success else { throw RemoteError.message("Connection timed out. Allow debugging on the projector, check Local Network permission, then retry.") }
        } catch {
            await disconnect()
            throw error
        }
    }

    public func disconnect() async {
        let previous = connection
        connection = nil
        await previous?.close()
    }

    public func shell(_ command: String, timeout: Double = 15) async throws -> String {
        guard !busy else { throw RemoteError.message("Another projector request is running.") }
        guard let conn = connection else { throw RemoteError.message("Connect to a projector first.") }
        busy = true
        defer { busy = false }
        let marker = "__REMOTE_\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))__"
        let destination = "shell:\(command); _remote_rc=$?; printf '\\n\(marker)%s\\n' \"$_remote_rc\""
        let deadline = Task {
            do { try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000)) } catch { return }
            await conn.close()
        }
        defer { deadline.cancel() }
        do {
            return try await withTaskCancellationHandler {
                let stream = try await conn.open(destination: destination)
                var output = Data()
                while true {
                    do {
                        let chunk = try await stream.read()
                        if chunk.isEmpty { break }
                        output.append(chunk)
                        guard output.count <= 512_000 else {
                            throw RemoteError.message("Projector response exceeded the size limit.")
                        }
                    } catch ADBError.streamClosed { break }
                }
                return try Self.parseResult(String(decoding: output, as: UTF8.self), marker: marker)
            } onCancel: { Task { await conn.close() } }
        } catch {
            // A missing sentinel can be timeout, cancellation or a dropped socket.
            // Invalidate the session instead of treating truncated output as success.
            await disconnect()
            throw error
        }
    }

    static func parseResult(_ text: String, marker: String) throws -> String {
        guard let range = text.range(of: "\n" + marker, options: .backwards),
              let code = Int(text[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw RemoteError.message("Incomplete command response. The connection may have timed out; reconnect before retrying.")
        }
        let output = String(text[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard code == 0, !output.contains("Error:"), !output.contains("Exception") else {
            throw RemoteError.message("Projector command failed (\(code)): \(output.prefix(400))")
        }
        return output
    }
}
