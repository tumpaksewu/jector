import Foundation
import ProjectorInference

actor ModelFiles {
    static var directory: URL { FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0] }
    static func url(for artifact: ModelArtifact) -> URL { directory.appendingPathComponent(artifact.filename) }
    static func exists(_ artifact: ModelArtifact) -> Bool { FileManager.default.fileExists(atPath: url(for: artifact).path) }

    func verify(_ artifact: ModelArtifact) throws { try artifact.verify(Self.url(for: artifact)) }

    func download(_ artifact: ModelArtifact, progress: @escaping @Sendable (Double) -> Void) async throws {
        let capacity = try Self.directory.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        if let free = capacity.volumeAvailableCapacityForImportantUsage, free < artifact.bytes + 100_000_000 {
            throw InferenceError.message("Not enough free storage for this model.")
        }
        let transfer = ModelDownload(expectedBytes: artifact.bytes, progress: progress)
        let temporary = try await transfer.fetch(artifact.downloadURL)
        defer { try? FileManager.default.removeItem(at: temporary) }
        try artifact.verify(temporary)
        try Task.checkCancellation()
        let destination = Self.url(for: artifact)
        if Self.exists(artifact) { try FileManager.default.removeItem(at: destination) }
        try FileManager.default.moveItem(at: temporary, to: destination)
        var url = destination
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try url.setResourceValues(values)
    }

    func delete(_ artifact: ModelArtifact) throws {
        if Self.exists(artifact) { try FileManager.default.removeItem(at: Self.url(for: artifact)) }
    }
}
