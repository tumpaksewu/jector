import Foundation

public enum RemoteError: LocalizedError {
    case message(String)
    public var errorDescription: String? {
        switch self { case .message(let text): return text }
    }
}

public struct Endpoint: Hashable, Identifiable, Sendable {
    public let host: String
    public let port: UInt16
    public var id: String { "\(host):\(port)" }
    public init(host: String, port: UInt16 = 5555) throws {
        let host = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard IPv4.parse(host) != nil, port > 0 else {
            throw RemoteError.message("Enter an IPv4 address and a port between 1 and 65535.")
        }
        self.host = host
        self.port = port
    }
}

public struct DiscoveredDevice: Identifiable, Sendable {
    public let endpoint: Endpoint
    public let label: String
    public let needsAuthorization: Bool
    public var id: String { endpoint.id }
}

public struct Volume: Equatable, Sendable {
    public let index: Int
    public let maximum: Int
    public var percent: Int { Int((Double(index) * 100 / Double(maximum)).rounded()) }
    public init(output: String) throws {
        let pattern = #"volume is (\d+) in range \[0\.\.(\d+)\]"#
        let regex = try NSRegularExpression(pattern: pattern)
        let range = NSRange(output.startIndex..., in: output)
        guard let match = regex.firstMatch(in: output, range: range),
              let a = Range(match.range(at: 1), in: output),
              let b = Range(match.range(at: 2), in: output),
              let index = Int(output[a]), let maximum = Int(output[b]),
              maximum > 0, index <= maximum else {
            throw RemoteError.message("The projector returned an unsupported volume response.")
        }
        self.index = index
        self.maximum = maximum
    }
    public func index(for percent: Int) throws -> Int {
        guard (0...100).contains(percent) else {
            throw RemoteError.message("Volume must be between 0 and 100 percent.")
        }
        return Int((Double(percent) * Double(maximum) / 100).rounded())
    }
}

public enum RemoteKey: String, CaseIterable, Sendable {
    case up = "19", down = "20", left = "21", right = "22", select = "23", back = "4"
}

public struct ProjectorInfo: Sendable {
    public let model: String
    public let android: String
    public let apps: [ProjectorApp]
    public let volume: Volume
    public let launchers: [HomeLauncher]
    public let projectivyAccessibilityEnabled: Bool
}
