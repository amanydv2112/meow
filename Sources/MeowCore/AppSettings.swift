import Foundation

public struct AppSettings: Equatable, Codable, Sendable {
    public var sttBaseURL: String
    public var sttModel: String
    public var sttLanguage: String
    public var sttPrompt: String
    public var sttResponseFormat: String
    public var cleanupEnabled: Bool
    public var cleanupModel: String
    public var saveHistory: Bool
    public var restoreClipboard: Bool
    public var shortcutUsesFunctionKey: Bool
    public var shortcutKeyCode: Int
    public var shortcutRequiresOption: Bool

    public init(
        sttBaseURL: String = "https://api.openai.com/v1",
        sttModel: String = "gpt-4o-mini-transcribe",
        sttLanguage: String = "",
        sttPrompt: String = "",
        sttResponseFormat: String = "text",
        cleanupEnabled: Bool = true,
        cleanupModel: String = "gpt-4.1-mini",
        saveHistory: Bool = true,
        restoreClipboard: Bool = true,
        shortcutUsesFunctionKey: Bool = true,
        shortcutKeyCode: Int = 49,
        shortcutRequiresOption: Bool = false
    ) {
        self.sttBaseURL = sttBaseURL
        self.sttModel = sttModel
        self.sttLanguage = sttLanguage
        self.sttPrompt = sttPrompt
        self.sttResponseFormat = sttResponseFormat
        self.cleanupEnabled = cleanupEnabled
        self.cleanupModel = cleanupModel
        self.saveHistory = saveHistory
        self.restoreClipboard = restoreClipboard
        self.shortcutUsesFunctionKey = shortcutUsesFunctionKey
        self.shortcutKeyCode = shortcutKeyCode
        self.shortcutRequiresOption = shortcutRequiresOption
    }

    private enum CodingKeys: String, CodingKey {
        case sttBaseURL
        case sttModel
        case sttLanguage
        case sttPrompt
        case sttResponseFormat
        case cleanupEnabled
        case cleanupModel
        case saveHistory
        case restoreClipboard
        case shortcutUsesFunctionKey
        case shortcutKeyCode
        case shortcutRequiresOption
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sttBaseURL = try container.decodeIfPresent(String.self, forKey: .sttBaseURL) ?? "https://api.openai.com/v1"
        sttModel = try container.decodeIfPresent(String.self, forKey: .sttModel) ?? "gpt-4o-mini-transcribe"
        sttLanguage = try container.decodeIfPresent(String.self, forKey: .sttLanguage) ?? ""
        sttPrompt = try container.decodeIfPresent(String.self, forKey: .sttPrompt) ?? ""
        sttResponseFormat = try container.decodeIfPresent(String.self, forKey: .sttResponseFormat) ?? "text"
        cleanupEnabled = try container.decodeIfPresent(Bool.self, forKey: .cleanupEnabled) ?? true
        cleanupModel = try container.decodeIfPresent(String.self, forKey: .cleanupModel) ?? "gpt-4.1-mini"
        saveHistory = try container.decodeIfPresent(Bool.self, forKey: .saveHistory) ?? true
        restoreClipboard = try container.decodeIfPresent(Bool.self, forKey: .restoreClipboard) ?? true
        shortcutUsesFunctionKey = try container.decodeIfPresent(Bool.self, forKey: .shortcutUsesFunctionKey) ?? true
        shortcutKeyCode = try container.decodeIfPresent(Int.self, forKey: .shortcutKeyCode) ?? 49
        shortcutRequiresOption = try container.decodeIfPresent(Bool.self, forKey: .shortcutRequiresOption) ?? false
    }

    public func sttConfig(apiKey: String) -> STTProviderConfig {
        STTProviderConfig(
            baseURL: sttBaseURL,
            apiKey: apiKey,
            model: sttModel,
            language: sttLanguage.isEmpty ? nil : sttLanguage,
            prompt: sttPrompt.isEmpty ? nil : sttPrompt,
            responseFormat: sttResponseFormat
        )
    }

    public func polisherConfig(apiKey: String) -> PolisherConfig {
        PolisherConfig(
            enabled: cleanupEnabled,
            baseURL: sttBaseURL,
            apiKey: apiKey,
            model: cleanupModel
        )
    }
}
