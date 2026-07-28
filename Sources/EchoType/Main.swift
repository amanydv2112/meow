import AppKit
import EchoTypeCore
import SwiftUI

@main
@MainActor
final class MainApp: NSObject, NSApplicationDelegate {
    private var appState: AppState!
    private var dictationController: DictationController!
    private var statusBarController: StatusBarController!
    private var settingsWindowController: SettingsWindowController?
    private var shortcutMonitor: GlobalShortcutMonitor!
    private var accessibilityPollTimer: Timer?

    static func main() {
        let app = NSApplication.shared
        if CommandLine.arguments.contains("--notify-smoke-test") {
            app.setActivationPolicy(.accessory)
            UserNotifier.notify(title: "EchoType", body: "Notifier smoke test")
            return
        }

        let delegate = MainApp()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) {
            app.run()
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        appState = AppState()
        dictationController = DictationController(appState: appState)

        statusBarController = StatusBarController(
            appState: appState,
            dictationController: dictationController,
            openSettings: { [weak self] in self?.showSettings() }
        )

        shortcutMonitor = GlobalShortcutMonitor(
            usesFunctionKeyOnly: appState.settings.shortcutUsesFunctionKey,
            keyCode: appState.settings.shortcutKeyCode,
            requiresOption: appState.settings.shortcutRequiresOption
        )
        shortcutMonitor.onShortcutDown = { [weak self] in
            self?.dictationController.beginDictation()
        }
        shortcutMonitor.onShortcutUp = { [weak self] in
            self?.dictationController.endDictation()
        }

        refreshShortcutMonitor(promptForAccessibility: true)
        statusBarController.refresh()
    }

    func applicationWillTerminate(_ notification: Notification) {
        accessibilityPollTimer?.invalidate()
    }

    private func showSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(appState: appState) { [weak self] in
                guard let self else { return }
                self.shortcutMonitor.usesFunctionKeyOnly = self.appState.settings.shortcutUsesFunctionKey
                self.shortcutMonitor.keyCode = self.appState.settings.shortcutKeyCode
                self.shortcutMonitor.requiresOption = self.appState.settings.shortcutRequiresOption
                self.refreshShortcutMonitor(promptForAccessibility: false)
            }
        }
        settingsWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func refreshShortcutMonitor(promptForAccessibility: Bool) {
        let trusted = PermissionsManager.accessibilityGranted(prompt: promptForAccessibility)
        appState.accessibilityTrusted = trusted

        guard trusted else {
            shortcutMonitor.stop()
            appState.lastMessage = "Enable Accessibility permission for fn dictation"
            appState.shortcutMonitorActive = false
            statusBarController.refresh()
            if promptForAccessibility {
                UserNotifier.notify(
                    title: "EchoType needs Accessibility",
                    body: "Enable EchoType in System Settings > Privacy & Security > Accessibility."
                )
            }
            startAccessibilityPolling()
            return
        }

        accessibilityPollTimer?.invalidate()
        accessibilityPollTimer = nil

        guard shortcutMonitor.start() else {
            appState.lastMessage = "Unable to start dictation shortcut. Restart EchoType."
            appState.shortcutMonitorActive = false
            UserNotifier.notify(title: "EchoType shortcut unavailable", body: appState.lastMessage)
            statusBarController.refresh()
            return
        }

        appState.shortcutMonitorActive = true
        if appState.lastMessage.contains("Accessibility") || appState.lastMessage.contains("shortcut") {
            appState.lastMessage = "Ready"
        }
        statusBarController.refresh()
    }

    private func startAccessibilityPolling() {
        guard accessibilityPollTimer == nil else { return }
        accessibilityPollTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshShortcutMonitor(promptForAccessibility: false)
            }
        }
    }
}
