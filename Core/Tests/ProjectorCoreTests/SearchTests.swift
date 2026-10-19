import Testing
import Foundation
@testable import ProjectorCore

struct SearchTests {
    @Test func modelCannotInventSearchDestination() throws {
        let json = #"{"calls":[{"name":"search_app","arguments":{"app":"YouTube","query":"space"}}]}"#
        let plan = try ToolPlan(json: json, installedApps: [.youtube])
        #expect(throws: (any Error).self) { try plan.validateSearchTargets(in: "Find space") }
        #expect(throws: (any Error).self) { try plan.validateSearchTargets(in: "Search notyoutube for space") }
        try plan.validateSearchTargets(in: "Find space on YouTube")
        try plan.validateSearchTargets(in: "Найди космос на Ютубе")
        #expect(ProjectorApp.vkVideo.isNamed(in: "Найди космос в ВК Видео"))
        #expect(ProjectorApp.rutube.isNamed(in: "Найди космос в Рутубе"))
    }
    @Test func bilingualQueriesPreserveOrderAndText() throws {
        let plan = try ToolPlan(json: #"{"calls":[{"name":"search_app","arguments":{"app":"VK Video","query":"космос и наука"}},{"name":"search_app","arguments":{"app":"Rutube","query":"black holes"}}]}"#,
                                installedApps: [.vkVideo, .rutube])
        #expect(plan.actions == [.search(.vkVideo, "космос и наука"), .search(.rutube, "black holes")])
    }

    @Test func rejectsUnsupportedDisabledAndMalformedSearches() throws {
        for args: [String: Any] in [
            ["app": "Netflix", "query": "space"], ["app": "ATV Search", "query": "space"],
            ["app": "YouTube", "query": "  "], ["app": "YouTube", "query": 5],
            ["app": "YouTube", "query": "line\nbreak"], ["app": "YouTube", "query": String(repeating: "я", count: 201)],
            ["app": "YouTube", "query": "space", "shell": "reboot"]
        ] {
            let json = try JSONSerialization.data(withJSONObject: ["calls": [["name": "search_app", "arguments": args]]])
            #expect(throws: (any Error).self) {
                try ToolPlan(json: String(decoding: json, as: UTF8.self), installedApps: [.youtube])
            }
        }
    }

    @Test func deepLinksEncodeQueryWithoutAddingURLParameters() throws {
        let text = "космос & a+b?x=1#part 'quote'"
        for app in [ProjectorApp.youtube, .rutube, .vkVideo] {
            let command = try SearchRequest(app: app, query: text).command
            let url = try #require(command.split(separator: "'").dropFirst().first)
            let items = try #require(URLComponents(string: String(url))?.queryItems)
            #expect(items.count == 1)
            #expect(items.first?.value == text)
        }
    }

    #if os(macOS)
    @Test func shellArgumentRoundTripsWithoutExecutingContent() throws {
        let query = "O'Brien; $(printf injected) `printf bad` $HOME космос \\\""
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", "printf '%s' " + SearchRequest.quote(query)]
        let pipe = Pipe(); process.standardOutput = pipe
        try process.run()
        let output = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        #expect(process.terminationStatus == 0)
        #expect(String(decoding: output, as: UTF8.self) == query)
    }
    #endif
}
