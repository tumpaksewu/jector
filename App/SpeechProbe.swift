import Speech
import AVFoundation
import SwiftUI

struct SpeechCapability: Identifiable {
    let id: String
    let name: String
    let supported: Bool
    let available: Bool
    let onDevice: Bool
}

@MainActor
final class SpeechProbe: ObservableObject {
    @Published var capabilities: [SpeechCapability] = []
    @Published var locale = "en-US"
    @Published var transcript = ""
    @Published var status = "Check capabilities, then record a short phrase on the iPhone."
    @Published var error: String?
    @Published var active = false
    @Published var recording = false
    @Published var permission = "Not checked"
    @Published var authorizing = false
    @Published var completionID = UUID()
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var recognition: SFSpeechRecognitionTask?
    private var timer: Task<Void, Never>?
    private var tapInstalled = false
    private var runID: UUID?
    private var pendingStartID: UUID?

    init() { refresh() }

    func refresh() {
        let supported = Set(SFSpeechRecognizer.supportedLocales().map { $0.identifier.replacingOccurrences(of: "_", with: "-") })
        capabilities = [("en-US", "English"), ("ru-RU", "Русский")].map { code, name in
            let recognizer = SFSpeechRecognizer(locale: Locale(identifier: code))
            return SpeechCapability(id: code, name: name, supported: supported.contains(code),
                                    available: recognizer?.isAvailable ?? false,
                                    onDevice: recognizer?.supportsOnDeviceRecognition ?? false)
        }
        let speech: String
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized: speech = "allowed"
        case .denied: speech = "denied"
        case .restricted: speech = "restricted"
        case .notDetermined: speech = "not requested"
        @unknown default: speech = "unknown"
        }
        let mic: String
        switch AVAudioApplication.shared.recordPermission {
        case .granted: mic = "allowed"
        case .denied: mic = "denied"
        case .undetermined: mic = "not requested"
        @unknown default: mic = "unknown"
        }
        permission = "Speech: \(speech) · Microphone: \(mic)"
        saveCapabilityReport()
    }

    func authorize() async -> Bool {
        guard !authorizing else { return false }
        authorizing = true
        defer { authorizing = false; refresh() }
        let speech = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard speech == .authorized else {
            error = "Allow Speech Recognition for Jector in Settings."
            return false
        }
        let mic = await AVAudioApplication.requestRecordPermission()
        if !mic { error = "Allow Microphone access for Jector in Settings." }
        return mic
    }

    func start() async {
        guard !active, !authorizing else { return }
        error = nil
        let pendingID = UUID()
        pendingStartID = pendingID
        guard await authorize(), !Task.isCancelled, pendingStartID == pendingID,
              UIApplication.shared.applicationState == .active else { return }
        pendingStartID = nil
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: locale)),
              recognizer.isAvailable, recognizer.supportsOnDeviceRecognition else {
            error = "On-device recognition is not currently available for \(locale). No audio was recorded or sent to a server."
            return
        }
        let id = UUID()
        runID = id; active = true; transcript = ""
        do {
            let audio = AVAudioSession.sharedInstance()
            try audio.setCategory(.record, mode: .measurement)
            try audio.setActive(true)
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.requiresOnDeviceRecognition = true
            request.shouldReportPartialResults = true
            request.contextualStrings = ["YouTube", "Jellyfin", "проектор", "громкость"]
            self.request = request
            recognition = recognizer.recognitionTask(with: request) { [weak self] result, error in
                let text = result?.bestTranscription.formattedString
                let final = result?.isFinal ?? false
                let message = error?.localizedDescription
                Task { @MainActor in
                    guard let self, self.runID == id else { return }
                    if let text { self.transcript = text }
                    if final {
                        self.completionID = UUID()
                        self.status = "Final transcript · \(self.locale) · on-device required"
                        self.finish()
                    } else if let message {
                        self.error = message
                        self.status = "Recognition ended with an error"
                        self.finish()
                    }
                }
            }
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else {
                throw NSError(domain: "SpeechProbe", code: 1, userInfo: [NSLocalizedDescriptionKey: "Microphone unavailable. Use the physical iPhone, outside iPhone Mirroring."])
            }
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in request.append(buffer) }
            tapInstalled = true
            engine.prepare()
            try engine.start()
            recording = true
            status = "Listening locally · \(locale) · 30-second limit"
            timer = Task {
                do { try await Task.sleep(nanoseconds: 30_000_000_000) } catch { return }
                stopListening()
            }
        } catch { self.error = error.localizedDescription; finish() }
    }

    func stopListening() {
        guard active, recording else { return }
        stopAudio(); request?.endAudio()
        status = "Finishing transcript…"
        timer?.cancel()
        timer = Task {
            do { try await Task.sleep(nanoseconds: 5_000_000_000) } catch { return }
            status = "Final result timed out; displayed text may be partial."
            finish()
        }
    }

    func cancel() {
        pendingStartID = nil
        if active { status = "Recording cancelled; displayed text may be partial." }
        finish()
    }
    private func stopAudio() {
        engine.stop()
        if tapInstalled { engine.inputNode.removeTap(onBus: 0); tapInstalled = false }
        recording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    private func finish() {
        runID = nil; timer?.cancel(); timer = nil
        stopAudio(); recognition?.cancel(); recognition = nil; request = nil; active = false
        refresh()
    }

    var diagnostics: String {
        (["Jector speech probe", "iOS \(UIDevice.current.systemVersion)", permission]
         + capabilities.map { "\($0.id): supported=\($0.supported), available=\($0.available), onDevice=\($0.onDevice)" }
         + [status, error ?? ""]).joined(separator: "\n")
    }

    private func saveCapabilityReport() {
        let report: [String: Any] = [
            "date": ISO8601DateFormatter().string(from: Date()),
            "ios": UIDevice.current.systemVersion,
            "permissions": permission,
            "status": status,
            "locales": capabilities.map {
                ["locale": $0.id, "supported": $0.supported,
                 "available": $0.available, "onDevice": $0.onDevice] as [String: Any]
            }
        ]
        do {
            let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: directory.appendingPathComponent("SpeechCapabilities.json"), options: .atomic)
        } catch {
            print("Capability report could not be saved: \(error.localizedDescription)")
        }
    }
}
