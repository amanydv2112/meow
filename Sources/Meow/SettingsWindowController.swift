import AppKit
import EchoTypeCore
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController {
    init(appState: AppState, onSaved: @MainActor @escaping () -> Void) {
        let rootView = SettingsView(appState: appState, onSaved: onSaved)
        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "EchoType Settings"
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

            Section("Cleanup") {
                Toggle("Clean up transcript before pasting", isOn: $appState.settings.cleanupEnabled)
                TextField("Cleanup model", text: $appState.settings.cleanupModel)
            }

            HStack {
                Spacer()
                saveConfirmation
                saveButton("Save", message: "Settings saved")
                    .keyboardShortcut(.defaultAction)
            }
        }
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
