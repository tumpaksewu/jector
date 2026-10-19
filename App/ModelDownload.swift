import Foundation
import ProjectorInference

/// URLSession owns temporary bytes; only a complete, verified download is installed.
final class ModelDownload: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private let expectedBytes: Int64
    private let progress: @Sendable (Double) -> Void
    private var continuation: CheckedContinuation<URL, Error>?
    private var session: URLSession?
    private var transfer: URLSessionDownloadTask?
    private var cancelled = false

    init(expectedBytes: Int64, progress: @escaping @Sendable (Double) -> Void) {
        self.expectedBytes = expectedBytes; self.progress = progress
    }

    func fetch(_ url: URL) async throws -> URL {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                lock.lock()
                if cancelled { lock.unlock(); continuation.resume(throwing: CancellationError()); return }
                self.continuation = continuation
                let config = URLSessionConfiguration.ephemeral
                config.allowsCellularAccess = false
                config.timeoutIntervalForResource = 3600
                let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
                self.session = session
                let transfer = session.downloadTask(with: url)
                self.transfer = transfer
                lock.unlock()
                transfer.resume()
            }
        } onCancel: { self.cancel() }
    }

    private func cancel() {
        lock.lock(); cancelled = true; let transfer = transfer; lock.unlock()
        transfer?.cancel()
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        progress(min(1, Double(totalBytesWritten) / Double(expectedBytes)))
        if totalBytesWritten > expectedBytes { downloadTask.cancel() }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        do {
            guard (downloadTask.response as? HTTPURLResponse)?.statusCode == 200 else {
                throw InferenceError.message("Model download failed. Check Wi-Fi and retry.")
            }
            let destination = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".gguf")
            try FileManager.default.moveItem(at: location, to: destination)
            lock.lock(); let wasCancelled = cancelled; lock.unlock()
            if wasCancelled { try? FileManager.default.removeItem(at: destination); throw CancellationError() }
            complete(.success(destination))
        } catch { complete(.failure(error)) }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error { complete(.failure(error)) }
    }

    private func complete(_ result: Result<URL, Error>) {
        lock.lock()
        let continuation = continuation; self.continuation = nil
        let session = session; self.session = nil; transfer = nil
        lock.unlock()
        continuation?.resume(with: result)
        session?.finishTasksAndInvalidate()
    }
}
