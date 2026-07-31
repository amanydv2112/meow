import AVFoundation
import Foundation
import Speech

/// Transcribes with Apple's on-device `SpeechAnalyzer`. Requires macOS 26; the models are
/// installed and shared by the system, so nothing ships inside the app bundle.
public struct AppleSpeechSTTProvider: STTProvider {
    public static let providerName = "Apple on-device"
    public static let modelName = "apple-speechanalyzer"

    public let displayName = AppleSpeechSTTProvider.providerName

    public init() {}

    public func transcribe(audioFile: URL, config: STTProviderConfig) async throws -> TranscriptResult {
        guard #available(macOS 26.0, *) else {
            throw FlowError.localTranscriptionUnavailable(
                "On-device transcription needs macOS 26 or later. Switch to the OpenAI-compatible engine in Settings."
            )
        }

        let text = try await AppleSpeechEngine.shared.transcribe(
            audioFile: audioFile,
            languageCode: config.language
        )
        guard !text.isEmpty else {
            throw FlowError.emptyTranscript
        }

        return TranscriptResult(
            text: text,
            provider: displayName,
            model: Self.modelName
        )
    }
}

/// Install state of the on-device language model, mirrored off `AssetInventory.Status` so callers
/// below macOS 26 can still reason about it.
public enum SpeechModelStatus: Equatable, Sendable {
    case unsupportedOS
    case unsupportedLanguage
    case supported
    case downloading
    case installed

    public var isInstalled: Bool { self == .installed }

    public var summary: String {
        switch self {
        case .unsupportedOS:
            "Requires macOS 26 or later."
        case .unsupportedLanguage:
            "This language has no on-device model."
        case .supported:
            "Not downloaded yet."
        case .downloading:
            "Downloading."
        case .installed:
            "Installed and ready."
        }
    }
}

/// Non-versioned facade over the macOS 26 Speech APIs, so UI and app code can call in without
/// scattering availability checks.
public enum AppleSpeechModels {
    public static var isSupportedOS: Bool {
        if #available(macOS 26.0, *) { true } else { false }
    }

    public static func status(languageCode: String?) async -> SpeechModelStatus {
        guard #available(macOS 26.0, *) else { return .unsupportedOS }
        return await AppleSpeechEngine.shared.status(languageCode: languageCode)
    }

    public static func supportedLanguageCodes() async -> [String] {
        guard #available(macOS 26.0, *) else { return [] }
        return await SpeechTranscriber.supportedLocales
            .map(\.identifier)
            .sorted()
    }

    /// Downloads the language model if it is missing. `onProgress` receives 0...1 while it runs.
    public static func install(
        languageCode: String?,
        onProgress: (@Sendable (Double) -> Void)? = nil
    ) async throws {
        guard #available(macOS 26.0, *) else {
            throw FlowError.localTranscriptionUnavailable(
                "On-device transcription needs macOS 26 or later."
            )
        }
        try await AppleSpeechEngine.shared.install(languageCode: languageCode, onProgress: onProgress)
    }

    /// Loads the model and opens an analysis session ahead of time so the first transcript after
    /// the user stops speaking does not pay for the cold start.
    public static func prewarm(languageCode: String?) async {
        guard #available(macOS 26.0, *) else { return }
        await AppleSpeechEngine.shared.prewarm(languageCode: languageCode)
    }
}

@available(macOS 26.0, *)
actor AppleSpeechEngine {
    static let shared = AppleSpeechEngine()

    /// A transcriber paired with the analyzer that owns it. An analyzer cannot be reused once its
    /// session is finalized, so a prepared session is consumed by exactly one transcription.
    private struct Session {
        let locale: Locale
        let transcriber: SpeechTranscriber
        let analyzer: SpeechAnalyzer
    }

    private var prepared: Session?

    func transcribe(audioFile url: URL, languageCode: String?) async throws -> String {
        let locale = try await Self.resolveLocale(languageCode)
        let session = try await consumeSession(for: locale)
        let file = try AVAudioFile(forReading: url)

        // The results sequence has to be drained while audio is being fed, otherwise the analyzer
        // blocks waiting for its output to be read.
        async let collected = Self.collectText(from: session.transcriber)

        do {
            if let lastSampleTime = try await session.analyzer.analyzeSequence(from: file) {
                try await session.analyzer.finalizeAndFinish(through: lastSampleTime)
            } else {
                await session.analyzer.cancelAndFinishNow()
            }
        } catch {
            await session.analyzer.cancelAndFinishNow()
            _ = try? await collected
            throw error
        }

        return try await collected
    }

    func prewarm(languageCode: String?) async {
        guard let locale = try? await Self.resolveLocale(languageCode) else { return }
        guard await Self.assetStatus(for: locale) == .installed else { return }
        _ = try? await prepareSession(for: locale)
    }

    func status(languageCode: String?) async -> SpeechModelStatus {
        guard let locale = try? await Self.resolveLocale(languageCode) else {
            return .unsupportedLanguage
        }
        return switch await Self.assetStatus(for: locale) {
        case .unsupported: .unsupportedLanguage
        case .supported: .supported
        case .downloading: .downloading
        case .installed: .installed
        @unknown default: .supported
        }
    }

    func install(languageCode: String?, onProgress: (@Sendable (Double) -> Void)?) async throws {
        let locale = try await Self.resolveLocale(languageCode)
        let transcriber = SpeechTranscriber(locale: locale, preset: .transcription)
        guard let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) else {
            onProgress?(1)
            return
        }

        let reporter: Task<Void, Never>? = onProgress.map { report in
            let progress = request.progress
            return Task {
                while !Task.isCancelled {
                    report(progress.fractionCompleted)
                    try? await Task.sleep(for: .milliseconds(200))
                }
            }
        }
        defer { reporter?.cancel() }

        try await request.downloadAndInstall()
        onProgress?(1)
    }

    // MARK: - Session handling

    /// Returns the warm session when it matches, otherwise builds one. The cache is always cleared
    /// because the caller finalizes the analyzer, which ends its session for good.
    private func consumeSession(for locale: Locale) async throws -> Session {
        let session = try await prepareSession(for: locale)
        prepared = nil
        return session
    }

    private func prepareSession(for locale: Locale) async throws -> Session {
        if let prepared, prepared.locale == locale {
            return prepared
        }
        if let stale = prepared {
            await stale.analyzer.cancelAndFinishNow()
            prepared = nil
        }

        let transcriber = SpeechTranscriber(locale: locale, preset: .transcription)
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try await request.downloadAndInstall()
        }

        let analyzer = SpeechAnalyzer(modules: [transcriber])
        try? await analyzer.prepareToAnalyze(in: nil)

        let session = Session(locale: locale, transcriber: transcriber, analyzer: analyzer)
        prepared = session
        return session
    }

    // MARK: - Helpers

    private static func collectText(from transcriber: SpeechTranscriber) async throws -> String {
        var transcript = AttributedString()
        for try await result in transcriber.results where result.isFinal {
            transcript += result.text
        }
        return String(transcript.characters).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func resolveLocale(_ languageCode: String?) async throws -> Locale {
        let requested = if let languageCode, !languageCode.isEmpty {
            Locale(identifier: languageCode)
        } else {
            Locale.current
        }

        guard let supported = await SpeechTranscriber.supportedLocale(equivalentTo: requested) else {
            throw FlowError.localTranscriptionUnavailable(
                "No on-device model covers \(requested.identifier). Pick another language in Settings."
            )
        }
        return supported
    }

    private static func assetStatus(for locale: Locale) async -> AssetInventory.Status {
        let transcriber = SpeechTranscriber(locale: locale, preset: .transcription)
        return await AssetInventory.status(forModules: [transcriber])
    }
}
