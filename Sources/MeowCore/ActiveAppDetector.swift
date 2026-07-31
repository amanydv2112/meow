import AppKit
import Foundation

public struct ActiveAppInfo: Equatable, Sendable {
    public var name: String?
    public var bundleIdentifier: String?

    public init(name: String?, bundleIdentifier: String?) {
        self.name = name
        self.bundleIdentifier = bundleIdentifier
    }
}

public enum ActiveAppDetector {
    public static func current() -> ActiveAppInfo {
        let app = NSWorkspace.shared.frontmostApplication
        return ActiveAppInfo(
            name: app?.localizedName,
            bundleIdentifier: app?.bundleIdentifier
        )
    }
}

