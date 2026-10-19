import Foundation

public enum CommandPrompt {
    public static func make(_ input: String) throws -> String {
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              input.count <= 500, !input.contains("<|"), !input.contains("|>") else {
            throw InferenceError.message("Enter a short projector request (up to 500 characters).")
        }
        let system = """
        Translate a projector request into JSON: {"calls":[{"name":"tool","arguments":{}}]}.
        Tools:
        pause_media {} = pause playback / поставить на паузу.
        resume_media {} = resume playback / продолжить воспроизведение.
        set_volume {"level":integer} = absolute volume percentage 0–100 / громкость.
        Apps: YouTube, Jellyfin, Rutube, VK Video, ATV Search. VK / ВК / ВК Видео means VK Video; Рутуб means Rutube; Ютуб means YouTube.
        open_app {"app":app name} = open that app / открыть приложение.
        search_app {"app":app name,"query":search text} = find content inside the named app / найти, поиск. Copy the search text exactly in its original language, excluding the instruction and app name. Never translate the query. Search already opens the app: do not add open_app. If no app is specified, return no calls. ATV Search is only for an explicit request for ATV Search.
        go_home {} = home screen / главный экран.
        Return {"calls":[]} for negated, ambiguous, unsupported or unrelated requests. A negation means no action, never the opposite action. Reject volume outside 0–100, never clamp it. No guessing relative volume. Up to three requested calls in order. Only JSON, no explanation.
        """
        let examples: [(String, String)] = [
            ("Приостанови фильм", #"{"calls":[{"name":"pause_media","arguments":{}}]}"#),
            ("Не приостанавливай фильм", #"{"calls":[]}"#),
            ("Возобнови видео", #"{"calls":[{"name":"resume_media","arguments":{}}]}"#),
            ("Set the volume to 200 percent", #"{"calls":[]}"#),
            ("Make it quieter", #"{"calls":[]}"#),
            ("Find a documentary", #"{"calls":[]}"#),
            ("Find black holes on YouTube", #"{"calls":[{"name":"search_app","arguments":{"app":"YouTube","query":"black holes"}}]}"#),
            ("Найди космос в ВК Видео", #"{"calls":[{"name":"search_app","arguments":{"app":"VK Video","query":"космос"}}]}"#)
        ]
        var prompt = "<|im_start|>system\n\(system)<|im_end|>\n"
        for (question, answer) in examples {
            prompt += "<|im_start|>user\n\(question)<|im_end|>\n<|im_start|>assistant\n\(answer)<|im_end|>\n"
        }
        prompt += "<|im_start|>user\n\(input)<|im_end|>\n<|im_start|>assistant\n<think>\n\n</think>\n\n"
        return prompt
    }

    public static let grammar = #"""
    root ::= "{" ws "\"calls\"" ws ":" ws "[" ws (call (ws "," ws call){0,2})? ws "]" ws "}" ws
    call ::= "{" ws "\"name\"" ws ":" ws (volume | app | search | simple) ws "}"
    volume ::= "\"set_volume\"" ws "," ws "\"arguments\"" ws ":" ws "{" ws "\"level\"" ws ":" ws "-"? [0-9]{1,4} ws "}"
    app ::= "\"open_app\"" ws "," ws "\"arguments\"" ws ":" ws "{" ws "\"app\"" ws ":" ws "\"" [a-zA-Z0-9 _-]{1,40} "\"" ws "}"
    search ::= "\"search_app\"" ws "," ws "\"arguments\"" ws ":" ws "{" ws "\"app\"" ws ":" ws "\"" [a-zA-Z0-9 _-]{1,40} "\"" ws "," ws "\"query\"" ws ":" ws string ws "}"
    string ::= "\"" char{1,200} "\""
    char ::= [^"\\\x00-\x1F] | "\\" (["\\/bfnrt] | "u" [0-9a-fA-F]{4})
    simple ::= ("\"pause_media\"" | "\"resume_media\"" | "\"go_home\"") ws "," ws "\"arguments\"" ws ":" ws "{" ws "}"
    ws ::= [ \t\n\r]{0,4}
    """#
}

public enum InferenceError: LocalizedError {
    case message(String)
    public var errorDescription: String? { switch self { case .message(let text): return text } }
}
