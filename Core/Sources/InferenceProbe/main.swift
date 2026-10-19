import Foundation
import ProjectorCore
import ProjectorInference

@main struct InferenceProbe {
    static func main() async throws {
        let args = CommandLine.arguments
        guard args.count == 4 else {
            print("Usage: InferenceProbe model.gguf cases.json results.json")
            return
        }
        let modelURL = URL(fileURLWithPath: args[1])
        try ModelArtifact.q4.verify(modelURL)
        let cases = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: args[2]))) as! [[String: Any]]
        let model = LocalModel()
        let start = Date()
        try await model.load(path: modelURL.path)
        let loadMS = Date().timeIntervalSince(start) * 1000
        var rows = [[String: Any]]()
        for item in cases {
            let query = item["query"] as! String
            do {
                let result = try await model.interpret(query)
                let plan = try ToolPlan(json: result.json, installedApps: ProjectorApp.allCases)
                try plan.validateSearchTargets(in: query)
                let expectedData = try JSONSerialization.data(withJSONObject: ["calls": item["expected"]!])
                let expected = try ToolPlan(json: String(decoding: expectedData, as: UTF8.self), installedApps: ProjectorApp.allCases)
                let passed = plan.actions == expected.actions
                rows.append(["query": query, "passed": passed, "json": result.json, "milliseconds": result.milliseconds])
                print("\(passed ? "PASS" : "FAIL") \(query): \(result.json) [\(Int(result.milliseconds)) ms]")
            } catch {
                rows.append(["query": query, "passed": false, "error": error.localizedDescription])
                print("FAIL \(query): \(error)")
            }
        }
        await model.unload()
        let report: [String: Any] = ["model": ModelArtifact.q4.name, "sha256": ModelArtifact.q4.sha256,
            "runtime": "llama.cpp b11734", "host": "Mac", "loadMS": loadMS, "rows": rows,
            "passed": rows.filter { $0["passed"] as? Bool == true }.count, "total": rows.count]
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
            .write(to: URL(fileURLWithPath: args[3]))
    }
}
