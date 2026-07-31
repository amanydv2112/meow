import AppKit
import MeowCore
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController {
    init(appState: AppState, onSaved: @MainActor @escaping () -> Void) {
        let rootView = SettingsView(appState: appState, onSaved: onSaved)
        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "meow Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 620, height: 520))
        window.center()
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private struct SettingsView: View {
    @ObservedObject var appState: AppState
    let onSaved: @MainActor () -> Void
    @State private var confirmationMessage: String?
    @State private var confirmationID = UUID()

    var body: some View {
        TabView {
            providerTab
                .tabItem { Label("Provider", systemImage: "network") }
            shortcutTab
                .tabItem { Label("Shortcut", systemImage: "keyboard") }
            historyTab
                .tabItem { Label("History", systemImage: "clock") }
            privacyTab
                .tabItem { Label("Privacy", systemImage: "hand.raised") }
        }
        .padding(20)
        .frame(minWidth: 620, minHeight: 520)
    }

    private var providerTab: some View {
        Form {
            Section("Transcription") {
                Picker("Engine", selection: $appState.settings.sttEngine) {
                    ForEach(STTEngine.allCases, id: \.self) { engine in
                        Text(engine.displayName).tag(engine)
                    }
                }
                Text(appState.settings.sttEngine == .appleOnDevice
                    ? "Audio is transcribed on this Mac. No API key, no network, no per-minute cost."
                    : "Audio is uploaded to the provider below for transcription.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if appState.settings.sttEngine == .appleOnDevice {
                OnDeviceModelSection(languageCode: $appState.settings.sttLanguage)
            } else {
                Section("Provider") {
                    TextField("Base URL", text: $appState.settings.sttBaseURL)
                    SecureField("API key", text: $appState.apiKey)
                    TextField("STT model", text: $appState.settings.sttModel)
                    TextField("Language code", text: $appState.settings.sttLanguage)
                    TextField("Provider prompt", text: $appState.settings.sttPrompt, axis: .vertical)
                        .lineLimit(3)
                    Picker("Response format", selection: $appState.settings.sttResponseFormat) {
                        Text("text").tag("text")
                        Text("json").tag("json")
                    }
                }
            }

            Section("Cleanup") {
                Toggle("Clean up transcript before pasting", isOn: $appState.settings.cleanupEnabled)
                Text(cleanupSummary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                TextField("Cleanup model", text: $appState.settings.cleanupModel)
                    .disabled(!appState.settings.cleanupEnabled)
                if appState.settings.sttEngine == .appleOnDevice, appState.settings.cleanupEnabled {
                    SecureField("API key for cleanup", text: $appState.apiKey)
                }
            }

            HStack {
                Spacer()
                saveConfirmation
                saveButton("Save", message: "Settings saved")
                    .keyboardShortcut(.defaultAction)
            }
        }
    }

    private var cleanupSummary: String {
        guard appState.settings.cleanupEnabled else {
            return "Off. The transcript is pasted exactly as the speech-to-text engine returned it, with no second API call."
        }
        if appState.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Needs an API key. Without one the raw transcript is pasted unchanged."
        }
        return "Fixes punctuation, casing, and filler words through the chat model below. Adds an API call to every dictation."
    }

    private var shortcutTab: some View {
        Form {
            Section("Activation") {
                Toggle("Use fn as push-to-talk", isOn: $appState.settings.shortcutUsesFunctionKey)

                if appState.settings.shortcutUsesFunctionKey {
                    Text("Hold fn to record. Release fn to transcribe and paste.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Toggle("Require Option modifier", isOn: $appState.settings.shortcutRequiresOption)
                    Stepper(value: $appState.settings.shortcutKeyCode, in: 0...126) {
                        Text("Key code: \(appState.settings.shortcutKeyCode)")
                    }
                    Text("Fallback custom shortcut. macOS key code 49 is Space.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Spacer()
                saveConfirmation
                saveButton("Save Shortcut", message: "Shortcut saved")
            }
        }
    }

    private var historyTab: some View {
        Form {
            Section("Local History") {
                Toggle("Save transcript history locally", isOn: $appState.settings.saveHistory)
                Toggle("Restore clipboard after paste", isOn: $appState.settings.restoreClipboard)
                Button("Clear History") {
                    try? appState.historyStore?.deleteAll()
                    appState.lastMessage = "History cleared"
                    showConfirmation("History cleared")
                }
            }

            Section("Recent") {
                let records = (try? appState.historyStore?.recent(limit: 10)) ?? []
                if records.isEmpty {
                    Text("No saved transcripts yet.")
                        .foregroundStyle(.secondary)
                } else {
                    List(records) { record in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(record.polishedText ?? record.rawTranscript ?? record.errorMessage ?? "Transcript")
                                .lineLimit(2)
                            Text(record.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(height: 220)
                }
            }

            HStack {
                Spacer()
                saveConfirmation
                saveButton("Save", message: "History settings saved")
            }
        }
    }

    private var privacyTab: some View {
        Form {
            Section("Permissions") {
                Button("Request Microphone Permission") {
                    Task { _ = await PermissionsManager.requestMicrophone() }
                }
                Button("Open Accessibility Permission Prompt") {
                    _ = PermissionsManager.accessibilityGranted(prompt: true)
                }
            }

            Section("Data") {
                if appState.settings.sttEngine == .appleOnDevice {
                    Text("On-device transcription keeps audio on this Mac. Nothing is uploaded unless transcript cleanup is enabled.")
                        .foregroundStyle(.secondary)
                }
                Text("Audio is written to a temporary file during processing and deleted after the dictation finishes.")
                    .foregroundStyle(.secondary)
                Text("API keys are stored in local app settings to avoid repeated Keychain prompts during development builds. Transcript history is stored locally in Application Support when enabled.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var saveConfirmation: some View {
        Group {
            if let confirmationMessage {
                Label(confirmationMessage, systemImage: "checkmark.circle.fill")
                    .font(.callout)
                    .foregroundStyle(.green)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
        }
        .animation(.easeInOut(duration: 0.18), value: confirmationMessage)
    }

    private func saveButton(_ title: String, message: String) -> some View {
        Button(title) {
            appState.save()
            appState.lastMessage = message
            onSaved()
            showConfirmation(message)
        }
    }

    private func showConfirmation(_ message: String) {
        let id = UUID()
        confirmationID = id
        confirmationMessage = message

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            guard confirmationID == id else { return }
            confirmationMessage = nil
        }
    }
}

/// Language choice plus install state for Apple's on-device speech models. The models are
/// downloaded and shared by the system, so this only reports and triggers installation.
private struct OnDeviceModelSection: View {
    @Binding var languageCode: String

    @State private var supportedCodes: [String] = []
    @State private var status: SpeechModelStatus = .supported
    @State private var installProgress: Double?
    @State private var installError: String?

    var body: some View {
        Section("On-device model") {
            Picker("Language", selection: $languageCode) {
                Text("System default").tag("")
                ForEach(languageOptions, id: \.self) { code in
                    Text(Self.label(for: code)).tag(code)
                }
            }

            HStack(alignment: .firstTextBaseline) {
                Label(status.summary, systemImage: statusSymbol)
                    .font(.footnote)
                    .foregroundStyle(status.isInstalled ? Color.green : Color.secondary)
                Spacer()
                if let installProgress {
                    ProgressView(value: installProgress)
                        .frame(width: 140)
                } else if status == .supported {
                    Button("Download") { install() }
                }
            }

            if let installError {
                Text(installError)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .task(id: languageCode) { await refresh() }
    }

    private var languageOptions: [String] {
        guard !languageCode.isEmpty, !supportedCodes.contains(languageCode) else {
            return supportedCodes
        }
        return [languageCode] + supportedCodes
    }

    private var statusSymbol: String {
        switch status {
        case .installed: "checkmark.circle.fill"
        case .downloading: "arrow.down.circle"
        case .supported: "arrow.down.circle"
        case .unsupportedLanguage, .unsupportedOS: "exclamationmark.triangle"
        }
    }

    private static func label(for code: String) -> String {
        Locale.current.localizedString(forIdentifier: code).map { "\($0) (\(code))" } ?? code
    }

    private func refresh() async {
        if supportedCodes.isEmpty {
            supportedCodes = await AppleSpeechModels.supportedLanguageCodes()
        }
        status = await AppleSpeechModels.status(languageCode: languageCode.isEmpty ? nil : languageCode)
    }

    private func install() {
        installError = nil
        installProgress = 0
        let code = languageCode.isEmpty ? nil : languageCode

        Task {
            do {
                try await AppleSpeechModels.install(languageCode: code) { fraction in
                    Task { @MainActor in installProgress = fraction }
                }
            } catch {
                installError = error.localizedDescription
            }
            installProgress = nil
            await refresh()
        }
    }
}
