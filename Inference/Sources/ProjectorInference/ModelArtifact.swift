import Foundation
import CryptoKit

public enum ModelArtifact: String, CaseIterable, Identifiable, Sendable {
    case q4, q8
    public var id: String { rawValue }
    public var name: String { "Qwen3-1.7B \(self == .q4 ? "Q4_K_M" : "Q8_0")" }
    public var filename: String { "Qwen3-1.7B-\(self == .q4 ? "Q4_K_M" : "Q8_0").gguf" }
    public var bytes: Int64 { self == .q4 ? 1_282_439_264 : 2_165_039_200 }
    public var sha256: String {
        self == .q4 ? "d2387ca2dbfee2ffabce7120d3770dadca0b293052bc2f0e138fdc940d9bc7b5"
                    : "9860780f3a1fab1f8f909a1b549ea3e62c22d19ab1a492b3a1026b38c5bd3ec3"
    }
    public var downloadURL: URL {
        URL(string: "https://huggingface.co/ggml-org/Qwen3-1.7B-GGUF/resolve/daeb8e2d528a760970442092f6bf1e55c3b659eb/\(filename)")!
    }
    public var sizeLabel: String { ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file) }

    public func verify(_ url: URL) throws {
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize
        guard size == Int(bytes) else { throw InferenceError.message("Model size mismatch. Download it again.") }
        let file = try FileHandle(forReadingFrom: url)
        defer { try? file.close() }
        var hash = SHA256()
        while let data = try file.read(upToCount: 4 * 1024 * 1024), !data.isEmpty {
            try Task.checkCancellation()
            hash.update(data: data)
        }
        let digest = hash.finalize().map { String(format: "%02x", $0) }.joined()
        guard digest == sha256 else { throw InferenceError.message("Model checksum mismatch. Download it again.") }
    }
}
