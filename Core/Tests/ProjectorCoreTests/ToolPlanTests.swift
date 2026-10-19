import Testing
@testable import ProjectorCore

struct ToolPlanTests {
    @Test func acceptsOrderedCompoundPlan() throws {
        let plan = try ToolPlan(json: #"{"calls":[{"name":"open_app","arguments":{"app":"Jellyfin"}},{"name":"set_volume","arguments":{"level":20}}]}"#,
                                installedApps: [.jellyfin])
        #expect(plan.actions == [.open(.jellyfin), .volume(20)])
    }

    @Test func rejectsUnsafeAndMalformedPlans() {
        let invalid = [
            #"{"calls":[{"name":"set_volume","arguments":{"level":150}}]}"#,
            #"{"calls":[{"name":"set_volume","arguments":{"level":-1}}]}"#,
            #"{"calls":[{"name":"set_volume","arguments":{"level":true}}]}"#,
            #"{"calls":[{"name":"set_volume","arguments":{"level":30.5}}]}"#,
            #"{"calls":[{"name":"set_volume","arguments":{"level":"30"}}]}"#,
            #"{"calls":[{"name":"shell","arguments":{"command":"reboot"}}]}"#,
            #"{"calls":[{"name":"open_app","arguments":{"app":"Netflix"}}]}"#,
            #"{"calls":[{"name":"pause_media","arguments":{"extra":1}}]}"#,
            #"{"calls":[],"extra":true}"#,
            #"{"calls":[{"name":"pause_media","arguments":{}},{"name":"shell","arguments":{}}]}"#,
            #"{"calls":[{"name":"go_home","arguments":{}},{"name":"go_home","arguments":{}},{"name":"go_home","arguments":{}},{"name":"go_home","arguments":{}}]}"#,
            #"{"calls":[]"#
        ]
        for json in invalid {
            #expect(throws: (any Error).self) { try ToolPlan(json: json, installedApps: [.youtube, .jellyfin]) }
        }
    }

    @Test func unavailableAppRejectedAndEmptyPlanAllowed() throws {
        #expect(throws: (any Error).self) {
            try ToolPlan(json: #"{"calls":[{"name":"open_app","arguments":{"app":"YouTube"}}]}"#, installedApps: [])
        }
        #expect(try ToolPlan(json: #"{"calls":[]}"#, installedApps: []).actions.isEmpty)
    }
}
