import Foundation
import UIKit
import ProjectorCore
import ProjectorInference

extension AssistantStore {
    func runChecks() {
        guard ready, !busy else { return }
        busy = true; error = nil; clearPlan()
        let id = UUID(); operationID = id
        task = Task {
            defer { if operationID == id { busy = false } }
            do {
                guard let url = Bundle.main.url(forResource: "command-cases", withExtension: "json"),
                      let cases = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [[String: Any]] else {
                    throw InferenceError.message("Bundled command cases are missing.")
                }
                var rows = [[String: Any]]()
                for (index, item) in cases.enumerated() {
                    try Task.checkCancellation()
                    status = "Command check \(index + 1)/\(cases.count)…"
                    let text = item["query"] as! String
                    let result = try await model.interpret(text)
                    var row: [String: Any] = ["query": text, "json": result.json, "milliseconds": result.milliseconds]
                    do {
                        let plan = try ToolPlan(json: result.json, installedApps: ProjectorApp.allCases)
                        try plan.validateSearchTargets(in: text)
                        let expectedJSON = try JSONSerialization.data(withJSONObject: ["calls": item["expected"]!])
                        let expected = try ToolPlan(json: String(decoding: expectedJSON, as: UTF8.self), installedApps: ProjectorApp.allCases)
                        row["passed"] = plan.actions == expected.actions
                    } catch {
                        row["passed"] = false; row["validationError"] = error.localizedDescription
                        row["safeRejection"] = (item["expected"] as? [[String: Any]])?.isEmpty == true
                    }
                    rows.append(row)
                }
                try Task.checkCancellation()
                let passed = rows.filter { $0["passed"] as? Bool == true }.count
                var report: [String: Any] = ["device": UIDevice.current.model, "ios": UIDevice.current.systemVersion,
                    "model": selectedArtifact.name, "sha256": selectedArtifact.sha256, "runtime": "llama.cpp b11734",
                    "date": ISO8601DateFormatter().string(from: Date()), "passed": passed, "total": cases.count, "rows": rows]
                report["loadMilliseconds"] = loadMilliseconds
                report["processFootprintMiBAfterChecks"] = MemorySnapshot.footprintMiB()
                let destination = ModelFiles.directory.appendingPathComponent("InferenceChecks.json")
                try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]).write(to: destination, options: .atomic)
                status = "\(passed)/\(cases.count) command checks passed. No projector actions executed."
            } catch {
                if operationID == id { self.error = error.localizedDescription; status = "Command checks stopped" }
            }
        }
    }
}
