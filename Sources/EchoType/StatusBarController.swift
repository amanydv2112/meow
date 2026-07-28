import AppKit
import Combine
import EchoTypeCore
import Foundation

@MainActor
final class StatusBarController {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let appState: AppState
    private let dictationController: DictationController
    private let openSettings: () -> Void
    private var cancellables: Set<AnyCancellable> = []

    init(appState: AppState, dictationController: DictationController, openSettings: @escaping () -> Void) {
        self.appState = appState
        self.dictationController = dictationController
        self.openSettings = openSettings

        appState.$lastMessage.sink { [weak self] _ in self?.refresh() }.store(in: &cancellables)
        appState.$isPaused.sink { [weak self] _ in self?.refresh() }.store(in: &cancellables)
        appState.$accessibilityTrusted.sink { [weak self] _ in self?.refresh() }.store(in: &cancellables)
        appState.$shortcutMonitorActive.sink { [weak self] _ in self?.refresh() }.store(in: &cancellables)
        dictationController.$status.sink { [weak self] _ in self?.refresh() }.store(in: &cancellables)
    }

    func refresh() {
        let currentTitle = title
        let currentMenu = buildMenu()
        DispatchQueue.main.async { [weak self] in
            self?.statusItem.button?.title = currentTitle
            self?.statusItem.menu = currentMenu
        }
    }

    private var title: String {
        switch dictationController.status {
        case .idle:
            if !appState.accessibilityTrusted {
                return "Setup Required"
            }
            return appState.isPaused ? "EchoType Paused" : "EchoType"
        case .recording:
            return "Recording"
        case .processing:
            return "Processing"
        case .failed:
            return "EchoType Error"
        }
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(withTitle: appState.lastMessage, action: nil, keyEquivalent: "")
        let shortcutName = appState.settings.shortcutUsesFunctionKey ? "fn" : "custom"
        let shortcutState = appState.shortcutMonitorActive ? "Shortcut: \(shortcutName) active" : "Shortcut: not active"
        menu.addItem(withTitle: shortcutState, action: nil, keyEquivalent: "")
        menu.addItem(.separator())

        let pauseTitle = appState.isPaused ? "Resume Dictation" : "Pause Dictation"
        let pauseItem = NSMenuItem(title: pauseTitle, action: #selector(togglePaused), keyEquivalent: "")
        pauseItem.target = self
        menu.addItem(pauseItem)

        let permissionTitle = appState.accessibilityTrusted ? "Check Permissions" : "Enable Accessibility Permission"
        let permissionItem = NSMenuItem(title: permissionTitle, action: #selector(checkPermissions), keyEquivalent: "")
        permissionItem.target = self
        menu.addItem(permissionItem)

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettingsAction), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())
        for record in recentRecords().prefix(5) {
            let text = (record.polishedText ?? record.rawTranscript ?? record.errorMessage ?? "Transcript")
                .replacingOccurrences(of: "\n", with: " ")
            let clipped = text.count > 60 ? String(text.prefix(57)) + "..." : text
            let item = NSMenuItem(title: clipped, action: #selector(copyHistoryItem(_:)), keyEquivalent: "")
            item.representedObject = record.polishedText ?? record.rawTranscript
            item.target = self
            menu.addItem(item)
        }

        if !recentRecords().isEmpty {
            let clearItem = NSMenuItem(title: "Clear History", action: #selector(clearHistory), keyEquivalent: "")
            clearItem.target = self
            menu.addItem(clearItem)
        }

        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Quit EchoType", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        return menu
    }

    private func recentRecords() -> [HistoryRecord] {
        (try? appState.historyStore?.recent(limit: 5)) ?? []
    }

    @objc private func togglePaused() {
        appState.isPaused.toggle()
    }

    @objc private func checkPermissions() {
        _ = PermissionsManager.accessibilityGranted(prompt: true)
        Task { _ = await PermissionsManager.requestMicrophone() }
    }

    @objc private func openSettingsAction() {
        openSettings()
    }

    @objc private func copyHistoryItem(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? String else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }

    @objc private func clearHistory() {
        try? appState.historyStore?.deleteAll()
        refresh()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
