import AppKit
import Combine
import MeowCore
import Foundation

@MainActor
final class DictationController: ObservableObject {
    enum Status: Equatable {
        case idle
        case recording
        case processing
        case failed(String)
    }

    @Published private(set) var status: Status = .idle

    private let appState: AppState
    private let recorder = AudioRecorder()
    private let polisher: TextPolisher = OpenAIChatTextPolisher()
    private let clipboardInserter = ClipboardInserter()
    private let hud = RecordingHUD()
    private var activeAppAtStart: ActiveAppInfo?

    init(appState: AppState) {
        self.appState = appState
        recorder.setLevelHandler { [weak self] level in
            DispatchQueue.main.async {
                self?.hud.updateLevel(level)
            }
        }
    }

    func beginDictation() {
        guard !appState.isPaused else { return }
        guard status == .idle else { return }

        Task {
            let microphoneGranted: Bool
            switch PermissionsManager.microphoneState() {
            case .granted:
                microphoneGranted = true
            case .notDetermined:
                microphoneGranted = await PermissionsManager.requestMicrophone()
            case .denied:
                microphoneGranted = false
            }

            guard microphoneGranted else {
                fail("Microphone permission is required.")
                return
            }

            do {
                activeAppAtStart = ActiveAppDetector.current()
                _ = try recorder.start()
                status = .recording
                appState.lastMessage = "Recording"
                hud.show()
            } catch {
                fail(error.localizedDescription)
                return
            }

            // Load the model while the user is still speaking so releasing the shortcut does not
            // pay for a cold start.
            if appState.settings.sttEngine == .appleOnDevice {
                let language = appState.settings.sttLanguage
                Task.detached(priority: .userInitiated) {
                    await AppleSpeechModels.prewarm(languageCode: language.isEmpty ? nil : language)
                }
            }
        }
    }

    func endDictation() {
        guard status == .recording else { return }
        hud.hide()
        appState.lastMessage = "Processing"
        status = .processing

        let recording: RecordingResult
        do {
            recording = try recorder.stop()
        } catch {
            hud.hide()
            fail(error.localizedDescription)
            return
        }

        Task {
            await process(recording)
        }
    }

    private func process(_ recording: RecordingResult) async {
        let appInfo = activeAppAtStart
        let engine = appState.settings.sttEngine
        let sttProvider = STTProviderFactory.make(for: engine)
        var rawTranscript: String?

        do {
            let result = try await sttProvider.transcribe(
                audioFile: recording.fileURL,
                config: appState.sttConfig()
            )
            rawTranscript = result.text

            var finalText = result.text
            if canRunCleanup {
                do {
                    finalText = try await polisher.polish(result.text, config: appState.polisherConfig())
                } catch {
                    finalText = result.text
                    saveHistory(
                        appInfo: appInfo,
                        engine: engine,
                        rawTranscript: result.text,
                        polishedText: finalText,
                        recording: recording,
                        status: .failed,
                        errorMessage: "Cleanup failed: \(error.localizedDescription)"
                    )
                    UserNotifier.notify(title: "Cleanup failed", body: "Pasted the raw transcript instead.")
                }
            }

            let pasted = clipboardInserter.insert(
                finalText,
                restoreClipboard: appState.settings.restoreClipboard
            )
            saveHistory(
                appInfo: appInfo,
                engine: engine,
                rawTranscript: result.text,
                polishedText: finalText,
                recording: recording,
                status: .succeeded,
                errorMessage: pasted ? nil : "Accessibility permission missing; copied to clipboard instead."
            )
            status = .idle
            appState.lastMessage = pasted ? "Inserted transcript" : "Copied transcript"
            hud.hide()
            try? FileManager.default.removeItem(at: recording.fileURL)
        } catch {
            saveHistory(
                appInfo: appInfo,
                engine: engine,
                rawTranscript: rawTranscript,
                polishedText: nil,
                recording: recording,
                status: .failed,
                errorMessage: error.localizedDescription
            )
            fail(error.localizedDescription)
            try? FileManager.default.removeItem(at: recording.fileURL)
        }
    }

    /// Cleanup runs through a chat model, so it needs a key even when transcription is local.
    private var canRunCleanup: Bool {
        guard appState.settings.cleanupEnabled else { return false }
        return !appState.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func saveHistory(
        appInfo: ActiveAppInfo?,
        engine: STTEngine,
        rawTranscript: String?,
        polishedText: String?,
        recording: RecordingResult,
        status: HistoryStatus,
        errorMessage: String?
    ) {
        guard appState.settings.saveHistory else { return }
        let record = HistoryRecord(
            appName: appInfo?.name,
            bundleIdentifier: appInfo?.bundleIdentifier,
            rawTranscript: rawTranscript,
            polishedText: polishedText,
            provider: engine.displayName,
            model: STTProviderFactory.modelIdentifier(for: engine, settings: appState.settings),
            duration: recording.duration,
            status: status,
            errorMessage: errorMessage
        )
        try? appState.historyStore?.insert(record)
    }

    private func fail(_ message: String) {
        status = .failed(message)
        appState.lastMessage = message
        hud.hide()
        UserNotifier.notify(title: "meow", body: message)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            if case .failed = self?.status {
                self?.status = .idle
            }
        }
    }
}
