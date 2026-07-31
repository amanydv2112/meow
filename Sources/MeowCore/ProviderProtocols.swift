import Foundation

public protocol STTProvider: Sendable {
    var displayName: String { get }
    func transcribe(audioFile: URL, config: STTProviderConfig) async throws -> TranscriptResult
}

public enum STTProviderFactory {
    public static func make(for engine: STTEngine) -> any STTProvider {
        switch engine {
        case .appleOnDevice: AppleSpeechSTTProvider()
        case .openAICompatible: OpenAICompatibleSTTProvider()
        }
    }

    /// The value recorded in history for a dictation, so past transcripts stay attributable.
    public static func modelIdentifier(for engine: STTEngine, settings: AppSettings) -> String {
        switch engine {
        case .appleOnDevice: AppleSpeechSTTProvider.modelName
        case .openAICompatible: settings.sttModel
        }
    }
}

public protocol TextPolisher: Sendable {
    var displayName: String { get }
    func polish(_ transcript: String, config: PolisherConfig) async throws -> String
}

public struct NoOpTextPolisher: TextPolisher {
    public let displayName = "Raw transcript"

    public init() {}

    public func polish(_ transcript: String, config: PolisherConfig) async throws -> String {
        transcript
    }
}

