import Foundation

public enum FlowError: LocalizedError, Equatable {
    case missingAPIKey
    case invalidBaseURL(String)
    case invalidHTTPResponse
    case httpError(statusCode: Int, message: String)
    case emptyTranscript
    case recordingTooShort
    case fileTooLarge(bytes: Int64, limitBytes: Int64)
    case permissionMissing(String)
    case unsupportedResponse

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            "Add an API key in Settings before dictating."
        case let .invalidBaseURL(value):
            "The provider URL is not valid: \(value)"
        case .invalidHTTPResponse:
            "The provider returned an invalid response."
        case let .httpError(statusCode, message):
            "Provider error \(statusCode): \(message)"
        case .emptyTranscript:
            "No speech was detected in that recording."
        case .recordingTooShort:
            "The recording was too short to transcribe."
        case let .fileTooLarge(bytes, limitBytes):
            "The recording is too large (\(bytes) bytes). The current limit is \(limitBytes) bytes."
        case let .permissionMissing(name):
            "\(name) permission is required."
        case .unsupportedResponse:
            "The provider response could not be read."
        }
    }
}

public struct STTProviderConfig: Equatable, Codable, Sendable {
    public var baseURL: String
    public var apiKey: String
    public var model: String
    public var language: String?
    public var prompt: String?
    public var responseFormat: String
    public var timeoutSeconds: TimeInterval
    public var maxFileSizeBytes: Int64
    public var streamCompletedRecording: Bool

    public init(
        baseURL: String = "https://api.openai.com/v1",
        apiKey: String = "",
        model: String = "gpt-4o-mini-transcribe",
        language: String? = nil,
        prompt: String? = nil,
        responseFormat: String = "text",
        timeoutSeconds: TimeInterval = 60,
        maxFileSizeBytes: Int64 = 24 * 1_024 * 1_024,
        streamCompletedRecording: Bool = false
    ) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.model = model
        self.language = language
        self.prompt = prompt
        self.responseFormat = responseFormat
        self.timeoutSeconds = timeoutSeconds
        self.maxFileSizeBytes = maxFileSizeBytes
        self.streamCompletedRecording = streamCompletedRecording
    }
}

public struct PolisherConfig: Equatable, Codable, Sendable {
    public var enabled: Bool
    public var baseURL: String
    public var apiKey: String
    public var model: String
    public var timeoutSeconds: TimeInterval

    public init(
        enabled: Bool = true,
        baseURL: String = "https://api.openai.com/v1",
        apiKey: String = "",
        model: String = "gpt-4.1-mini",
        timeoutSeconds: TimeInterval = 60
    ) {
        self.enabled = enabled
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.model = model
        self.timeoutSeconds = timeoutSeconds
    }
}

public struct TranscriptResult: Equatable, Codable, Sendable {
    public var text: String
    public var provider: String
    public var model: String
    public var duration: TimeInterval?
    public var rawResponse: String?

    public init(
        text: String,
        provider: String,
        model: String,
        duration: TimeInterval? = nil,
        rawResponse: String? = nil
    ) {
        self.text = text
        self.provider = provider
        self.model = model
        self.duration = duration
        self.rawResponse = rawResponse
    }
}

public enum HistoryStatus: String, Codable, Sendable {
    case succeeded
    case failed
}

public struct HistoryRecord: Identifiable, Equatable, Codable, Sendable {
    public var id: UUID
    public var createdAt: Date
    public var appName: String?
    public var bundleIdentifier: String?
    public var rawTranscript: String?
    public var polishedText: String?
    public var provider: String
    public var model: String
    public var duration: TimeInterval?
    public var status: HistoryStatus
    public var errorMessage: String?

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        appName: String? = nil,
        bundleIdentifier: String? = nil,
        rawTranscript: String? = nil,
        polishedText: String? = nil,
        provider: String,
        model: String,
        duration: TimeInterval? = nil,
        status: HistoryStatus,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.rawTranscript = rawTranscript
        self.polishedText = polishedText
        self.provider = provider
        self.model = model
        self.duration = duration
        self.status = status
        self.errorMessage = errorMessage
    }
}

