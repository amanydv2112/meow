import Foundation

public struct OpenAICompatibleSTTProvider: STTProvider {
    public let displayName = "OpenAI-compatible"

    public init() {}

    public func transcribe(audioFile: URL, config: STTProviderConfig) async throws -> TranscriptResult {
        guard !config.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw FlowError.missingAPIKey
        }

        let values = try audioFile.resourceValues(forKeys: [.fileSizeKey])
        let fileSize = Int64(values.fileSize ?? 0)
        if fileSize > config.maxFileSizeBytes {
            throw FlowError.fileTooLarge(bytes: fileSize, limitBytes: config.maxFileSizeBytes)
        }

        let audioData = try Data(contentsOf: audioFile)
        let boundary = "EchoType-\(UUID().uuidString)"
        let request = try Self.makeTranscriptionRequest(
            audioFileURL: audioFile,
            fileData: audioData,
            config: config,
            boundary: boundary
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw FlowError.invalidHTTPResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw FlowError.httpError(
                statusCode: httpResponse.statusCode,
                message: ProviderErrorParser.message(from: data)
            )
        }

        let text = try Self.parseTranscript(data: data)
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw FlowError.emptyTranscript
        }

        return TranscriptResult(
            text: text,
            provider: displayName,
            model: config.model,
            rawResponse: String(data: data, encoding: .utf8)
        )
    }

    public static func makeTranscriptionRequest(
        audioFileURL: URL,
        fileData: Data,
        config: STTProviderConfig,
        boundary: String
    ) throws -> URLRequest {
        guard var components = URLComponents(string: config.baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))) else {
            throw FlowError.invalidBaseURL(config.baseURL)
        }
        components.path = components.path.appending("/audio/transcriptions")
        guard let url = components.url else {
            throw FlowError.invalidBaseURL(config.baseURL)
        }

        var fields: [String: String] = [
            "model": config.model,
            "response_format": config.responseFormat
        ]
        if let language = config.language, !language.isEmpty {
            fields["language"] = language
        }
        if let prompt = config.prompt, !prompt.isEmpty {
            fields["prompt"] = prompt
        }
        if config.streamCompletedRecording {
            fields["stream"] = "true"
        }

        let file = MultipartFile(
            fieldName: "file",
            fileName: audioFileURL.lastPathComponent.isEmpty ? "recording.wav" : audioFileURL.lastPathComponent,
            mimeType: "audio/wav",
            data: fileData
        )

        var request = URLRequest(url: url, timeoutInterval: config.timeoutSeconds)
        request.httpMethod = "POST"
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = MultipartFormData.build(fields: fields, file: file, boundary: boundary)
        return request
    }

    public static func parseTranscript(data: Data) throws -> String {
        if let response = try? JSONDecoder().decode(TranscriptionResponse.self, from: data) {
            return response.text
        }
        if let text = String(data: data, encoding: .utf8) {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        throw FlowError.unsupportedResponse
    }
}

private struct TranscriptionResponse: Decodable {
    let text: String
}

enum ProviderErrorParser {
    static func message(from data: Data) -> String {
        if let response = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data) {
            return response.error.message
        }
        return String(data: data, encoding: .utf8) ?? "Unknown error"
    }
}

private struct OpenAIErrorResponse: Decodable {
    struct ErrorBody: Decodable {
        let message: String
    }

    let error: ErrorBody
}
