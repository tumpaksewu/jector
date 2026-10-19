import Foundation
import Darwin

public enum IPv4 {
    public static func parse(_ text: String) -> UInt32? {
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return nil }
        var value: UInt32 = 0
        for part in parts {
            guard !part.isEmpty, part.allSatisfy({ $0.isASCII && $0.isNumber }),
                  let byte = UInt8(part) else { return nil }
            value = (value << 8) | UInt32(byte)
        }
        return value
    }
    public static func text(_ value: UInt32) -> String {
        [24, 16, 8, 0].map { String((value >> $0) & 255) }.joined(separator: ".")
    }
}

public struct LANSubnet: Sendable {
    public let address: UInt32
    public let mask: UInt32
    public let isLimited: Bool
    public var description: String {
        "\(IPv4.text(address & mask))/\(mask.nonzeroBitCount)" + (isLimited ? " (local /24 segment)" : "")
    }
    public init(address: String, mask: String) throws {
        guard let ip = IPv4.parse(address), let mask = IPv4.parse(mask),
              mask != 0, (~mask &+ 1) & ~mask == 0 else {
            throw RemoteError.message("Invalid Wi-Fi subnet.")
        }
        self.address = ip
        self.isLimited = mask.nonzeroBitCount < 22
        self.mask = isLimited ? 0xFFFFFF00 : mask
    }
    public var hosts: [String] {
        let network = address & mask
        let broadcast = network | ~mask
        guard UInt64(broadcast) > UInt64(network) + 1 else { return [] }
        return ((network + 1)..<broadcast).filter { $0 != address }.map(IPv4.text)
    }
    public static func wifi() throws -> LANSubnet {
        var interfaces: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaces) == 0, let first = interfaces else {
            throw RemoteError.message("Could not read network interfaces.")
        }
        defer { freeifaddrs(interfaces) }
        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let item = cursor {
            defer { cursor = item.pointee.ifa_next }
            let iface = item.pointee
            guard String(cString: iface.ifa_name) == "en0",
                  let addr = iface.ifa_addr, let mask = iface.ifa_netmask,
                  addr.pointee.sa_family == UInt8(AF_INET) else { continue }
            func host(_ address: UnsafeMutablePointer<sockaddr>) -> String {
                var buffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                getnameinfo(address, socklen_t(address.pointee.sa_len), &buffer,
                            socklen_t(buffer.count), nil, 0, NI_NUMERICHOST)
                return String(cString: buffer)
            }
            return try LANSubnet(address: host(addr), mask: host(mask))
        }
        throw RemoteError.message("Join Wi-Fi to search the LAN, or enter the projector address manually.")
    }
}
