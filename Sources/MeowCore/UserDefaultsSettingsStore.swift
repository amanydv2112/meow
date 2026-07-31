import Foundation

public final class UserDefaultsSettingsStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let key = "EchoType.AppSettings"
    private let apiKeyKey = "EchoType.OpenAICompatibleAPIKey"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> AppSettings {
        guard let data = defaults.data(forKey: key),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return AppSettings()
        }
        return settings
    }

    public func save(_ settings: AppSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: key)
    }

    public func loadAPIKey() -> String {
        defaults.string(forKey: apiKeyKey) ?? ""
    }

    public func saveAPIKey(_ apiKey: String) {
        defaults.set(apiKey, forKey: apiKeyKey)
    }
}
