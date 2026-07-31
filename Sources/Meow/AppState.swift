import Combine
import MeowCore
import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var settings: AppSettings
    @Published var apiKey: String
    @Published var lastMessage: String = "Ready"
    @Published var isPaused: Bool = false
    @Published var accessibilityTrusted: Bool = false
    @Published var shortcutMonitorActive: Bool = false

    let settingsStore: UserDefaultsSettingsStore
    let historyStore: SQLiteHistoryStore?

    init(
        settingsStore: UserDefaultsSettingsStore = UserDefaultsSettingsStore()
    ) {
        self.settingsStore = settingsStore
        settings = settingsStore.load()
        apiKey = settingsStore.loadAPIKey()
        historyStore = try? SQLiteHistoryStore(databaseURL: SQLiteHistoryStore.defaultDatabaseURL())
    }

    func save() {
        settingsStore.save(settings)
        settingsStore.saveAPIKey(apiKey)
    }

    func sttConfig() -> STTProviderConfig {
        settings.sttConfig(apiKey: apiKey)
    }

    func polisherConfig() -> PolisherConfig {
        settings.polisherConfig(apiKey: apiKey)
    }
}
