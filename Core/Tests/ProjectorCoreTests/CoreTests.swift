import Testing
import Foundation
@testable import ProjectorCore

struct CoreTests {
    @Test func endpointValidation() throws {
        #expect(try Endpoint(host: " 192.168.1.226 ").id == "192.168.1.226:5555")
        for host in ["192.168.1.256", "127.1", "1.2.3.4; reboot", "::1", "1..3.4"] {
            #expect(throws: (any Error).self) { try Endpoint(host: host) }
        }
        #expect(throws: (any Error).self) { try Endpoint(host: "1.2.3.4", port: 0) }
    }

    @Test func subnetExcludesLocalAndBroadcast() throws {
        let subnet = try LANSubnet(address: "192.168.1.143", mask: "255.255.255.0")
        #expect(subnet.hosts.count == 253)
        #expect(subnet.hosts.contains("192.168.1.226"))
        #expect(!subnet.hosts.contains("192.168.1.143"))
        #expect(!subnet.hosts.contains("192.168.1.0"))
        #expect(!subnet.hosts.contains("192.168.1.255"))
        #expect(throws: (any Error).self) { try LANSubnet(address: "1.2.3.4", mask: "255.0.255.0") }
        #expect(try LANSubnet(address: "255.255.255.255", mask: "255.255.255.255").hosts.isEmpty)
    }

    @Test func wideNetworksAreBounded() throws {
        let subnet = try LANSubnet(address: "10.12.34.56", mask: "255.0.0.0")
        #expect(subnet.isLimited)
        #expect(subnet.hosts.count == 253)
        #expect(subnet.hosts.allSatisfy { $0.hasPrefix("10.12.34.") })
    }

    @Test func volumeConversionAndUnsafeInput() throws {
        let volume = try Volume(output: "[v] volume is 14 in range [0..50]")
        #expect(volume.percent == 28)
        #expect(try volume.index(for: 30) == 15)
        #expect(try volume.index(for: 100) == 50)
        #expect(try volume.index(for: 1) == 1)
        #expect(throws: (any Error).self) { try volume.index(for: 150) }
        #expect(throws: (any Error).self) { try volume.index(for: -1) }
        #expect(throws: (any Error).self) { try Volume(output: "Permission denied") }
        #expect(throws: (any Error).self) { try Volume(output: "volume is 51 in range [0..50]") }
    }

    @Test func shellRequiresCompleteSuccessfulResponse() throws {
        #expect(try ProjectorSession.parseResult("hello\n__END__0\n", marker: "__END__") == "hello")
        for output in ["partial", "hello\n__END__1\n", "Error: failed\n__END__0\n", "__END__0"] {
            #expect(throws: (any Error).self) { try ProjectorSession.parseResult(output, marker: "__END__") }
        }
    }

    @Test func discoveryCanBeCancelled() async throws {
        let endpoint = try Endpoint(host: "192.0.2.1")
        let task = Task { await ADBDiscovery.probe(endpoint) }
        task.cancel()
        #expect(await task.value == nil)
    }
}
