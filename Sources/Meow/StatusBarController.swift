import AppKit
import Combine
import MeowCore
import Foundation

@MainActor
final class StatusBarController {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let appState: AppState
    private let dictationController: DictationController
    private let openSettings: () -> Void
    private var cancellables: Set<AnyCancellable> = []
    private var processingTimer: Timer?
    private var processingPhase = 0

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
        let currentMenu = buildMenu()
        let currentTooltip = tooltip
        setProcessingAnimation(enabled: isTranscribing)

        DispatchQueue.main.async { [weak self] in
            guard let self, let button = self.statusItem.button else { return }
            button.imagePosition = .imageOnly
            button.title = ""
            button.toolTip = currentTooltip
            button.image = CatIcon.menuBarImage(state: self.iconState)
            self.statusItem.menu = currentMenu
        }
    }

    /// The cat's own expression carries the state, so the menu bar item never
    /// grows a word or a second glyph.
    private var iconState: CatIcon.State {
        switch dictationController.status {
        case .idle:
            if !appState.accessibilityTrusted {
                return .attention
            }
            return appState.isPaused ? .paused : .idle
        case .recording:
            return .listening
        case .processing:
            return .thinking(phase: processingPhase)
        case .failed:
            return .attention
        }
    }

    private var tooltip: String {
        switch dictationController.status {
        case .idle:
            if !appState.accessibilityTrusted {
                return "meow: Accessibility permission required"
            }
            return appState.isPaused ? "meow: paused" : "meow"
        case .recording:
            return "meow: recording"
        case .processing:
            return "meow: transcribing"
        case .failed:
            return "meow: \(appState.lastMessage)"
        }
    }

    private var isTranscribing: Bool {
        if case .processing = dictationController.status { return true }
        return false
    }

    /// Twitches the cat's ears while transcribing. Only the button image is
    /// redrawn so an open menu is left alone.
    private func setProcessingAnimation(enabled: Bool) {
        guard enabled else {
            processingTimer?.invalidate()
            processingTimer = nil
            processingPhase = 0
            return
        }
        guard processingTimer == nil else { return }

        processingTimer = Timer.scheduledTimer(withTimeInterval: 0.28, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.processingPhase = (self.processingPhase + 1) % 3
                self.statusItem.button?.image = CatIcon.menuBarImage(
                    state: .thinking(phase: self.processingPhase)
                )
            }
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

        let cleanupItem = NSMenuItem(title: "Clean Up Text", action: #selector(toggleCleanup), keyEquivalent: "")
        cleanupItem.state = appState.settings.cleanupEnabled ? .on : .off
        cleanupItem.target = self
        menu.addItem(cleanupItem)

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
        let quitItem = NSMenuItem(title: "Quit meow", action: #selector(quit), keyEquivalent: "q")
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

    @objc private func toggleCleanup() {
        appState.settings.cleanupEnabled.toggle()
        appState.save()
        appState.lastMessage = appState.settings.cleanupEnabled ? "Cleanup on" : "Cleanup off"
        refresh()
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
