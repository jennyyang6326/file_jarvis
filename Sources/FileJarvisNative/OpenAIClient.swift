import Foundation

struct OpenAIClient {
    private let endpoint = URL(string: "https://api.openai.com/v1/responses")!

    func askAboutFolder(question: String, folderURL: URL, files: [LocalFileItem]) async throws -> String {
        guard let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !apiKey.isEmpty else {
            throw OpenAIClientError.missingAPIKey
        }

        let fileSummary = files.prefix(20).map { file in
            var line = "- \(file.name) | \(file.kind) | \(file.sizeLabel) | \(file.modifiedLabel)"
            if let preview = file.preview, !preview.isEmpty {
                line += " | Preview: \(preview)"
            }
            return line
        }.joined(separator: "\n")

        let prompt = """
        You are file_jarvis, a privacy-scoped local file assistant.
        Only use the approved folder context below.
        Do not claim access beyond the provided folder and files.
        Be concise, practical, and calm.

        Approved folder: \(folderURL.path)
        Visible files:
        \(fileSummary.isEmpty ? "- No visible files were found." : fileSummary)

        User request: \(question)
        """

        let requestBody = ResponsesRequest(
            model: "gpt-5-mini",
            input: [
                .init(
                    role: "user",
                    content: [
                        .init(type: "input_text", text: prompt)
                    ]
                )
            ]
        )

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIClientError.invalidResponse
        }

        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown API error"
            throw OpenAIClientError.apiError(message)
        }

        return try parseResponseText(from: data)
    }

    private func parseResponseText(from data: Data) throws -> String {
        let object = try JSONSerialization.jsonObject(with: data)
        guard let dictionary = object as? [String: Any] else {
            throw OpenAIClientError.invalidResponse
        }

        if let outputText = dictionary["output_text"] as? String, !outputText.isEmpty {
            return outputText
        }

        if let output = dictionary["output"] as? [[String: Any]] {
            let text = output
                .flatMap { $0["content"] as? [[String: Any]] ?? [] }
                .compactMap { content -> String? in
                    if let text = content["text"] as? String {
                        return text
                    }
                    if
                        let textDictionary = content["text"] as? [String: Any],
                        let value = textDictionary["value"] as? String
                    {
                        return value
                    }
                    return nil
                }
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if !text.isEmpty {
                return text
            }
        }

        throw OpenAIClientError.invalidResponse
    }
}

struct ResponsesRequest: Encodable {
    let model: String
    let input: [ResponsesMessage]
}

struct ResponsesMessage: Encodable {
    let role: String
    let content: [ResponsesContent]
}

struct ResponsesContent: Encodable {
    let type: String
    let text: String
}

enum OpenAIClientError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Set OPENAI_API_KEY before launching the native MVP."
        case .invalidResponse:
            return "OpenAI returned a response the MVP could not parse."
        case let .apiError(message):
            return "OpenAI API error: \(message)"
        }
    }
}
