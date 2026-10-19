import Foundation
import llama

public struct ModelResult: Sendable {
    public let json: String
    public let milliseconds: Double
    public let generatedTokens: Int
}

/// All C model/context access stays on this actor, away from the main actor.
public actor LocalModel {
    private var model: OpaquePointer?
    private var context: OpaquePointer?
    private static let backend: Void = { llama_backend_init() }()

    public init() {}

    public func load(path: String) throws {
        guard model == nil else { return }
        _ = Self.backend
        try Task.checkCancellation()
        var params = llama_model_default_params()
        params.n_gpu_layers = 99
        #if targetEnvironment(simulator)
        params.n_gpu_layers = 0
        #endif
        guard let loaded = llama_model_load_from_file(path, params) else {
            throw InferenceError.message("Model could not load. Check the download and free memory.")
        }
        var ctx = llama_context_default_params()
        ctx.n_ctx = 2048; ctx.n_batch = 512; ctx.n_ubatch = 256
        ctx.n_threads = 4; ctx.n_threads_batch = 4
        guard let created = llama_init_from_model(loaded, ctx) else {
            llama_model_free(loaded)
            throw InferenceError.message("Could not allocate the model context.")
        }
        model = loaded; context = created
        if Task.isCancelled { unload(); throw CancellationError() }
    }

    public func unload() {
        if let context { llama_free(context) }
        if let model { llama_model_free(model) }
        context = nil; model = nil
    }

    public func interpret(_ input: String) throws -> ModelResult {
        guard let model, let context, let vocab = llama_model_get_vocab(model) else {
            throw InferenceError.message("Load the on-device model first.")
        }
        let prompt = try CommandPrompt.make(input)
        let started = Date()
        llama_memory_clear(llama_get_memory(context), true)
        defer { llama_memory_clear(llama_get_memory(context), true) }
        var tokens = [llama_token](repeating: 0, count: prompt.utf8.count + 16)
        let count = llama_tokenize(vocab, prompt, Int32(prompt.utf8.count), &tokens, Int32(tokens.count), true, true)
        guard count > 0, count + 256 <= 2048 else {
            throw InferenceError.message("Request exceeds the model context.")
        }
        tokens = Array(tokens.prefix(Int(count)))
        for offset in stride(from: 0, to: tokens.count, by: 512) {
            try checkDeadline(started)
            var chunk = Array(tokens[offset..<min(offset + 512, tokens.count)])
            let result = chunk.withUnsafeMutableBufferPointer { buffer in
                llama_decode(context, llama_batch_get_one(buffer.baseAddress, Int32(buffer.count)))
            }
            guard result == 0 else { throw InferenceError.message("Model prompt evaluation failed (\(result)).") }
        }
        guard let sampler = llama_sampler_chain_init(llama_sampler_chain_default_params()) else {
            throw InferenceError.message("Could not create the structured-output sampler.")
        }
        defer { llama_sampler_free(sampler) }
        guard let grammar = llama_sampler_init_grammar(vocab, CommandPrompt.grammar, "root") else {
            throw InferenceError.message("Could not initialize the command grammar.")
        }
        llama_sampler_chain_add(sampler, grammar)
        llama_sampler_chain_add(sampler, llama_sampler_init_greedy())
        var bytes = [UInt8]()
        for index in 0..<256 {
            try checkDeadline(started)
            var token = llama_sampler_sample(sampler, context, -1)
            if llama_vocab_is_eog(vocab, token) {
                guard let json = String(bytes: bytes, encoding: .utf8) else {
                    throw InferenceError.message("Model output was not valid UTF-8.")
                }
                return ModelResult(json: json, milliseconds: Date().timeIntervalSince(started) * 1000,
                                   generatedTokens: index)
            }
            var piece = [CChar](repeating: 0, count: 256)
            let size = llama_token_to_piece(vocab, token, &piece, 256, 0, false)
            guard size >= 0, size <= 256 else { throw InferenceError.message("Invalid model token.") }
            bytes.append(contentsOf: piece.prefix(Int(size)).map { UInt8(bitPattern: $0) })
            let result = withUnsafeMutablePointer(to: &token) { llama_decode(context, llama_batch_get_one($0, 1)) }
            guard result == 0 else { throw InferenceError.message("Model generation failed (\(result)).") }
        }
        throw InferenceError.message("Model output was truncated; no commands will run.")
    }

    private func checkDeadline(_ started: Date) throws {
        try Task.checkCancellation()
        guard Date().timeIntervalSince(started) < 30 else {
            throw InferenceError.message("Model timed out; no commands will run.")
        }
    }

    deinit {
        if let context { llama_free(context) }
        if let model { llama_model_free(model) }
    }
}
