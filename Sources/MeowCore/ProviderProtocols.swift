import Foundation

public protocol STTProvider: Sendable {
    var displayName: String { get }
    func transcribe(audioFile: URL, config: STTProviderConfig) async throws -> TranscriptResult
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

