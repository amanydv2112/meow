import AppKit
import Foundation

enum UserNotifier {
    @MainActor
    static func notify(title: String, body: String) {
        NSLog("%@: %@", title, body)

        if NSApp.isActive {
            NSSound.beep()
        } else {
            NSApp.requestUserAttention(.informationalRequest)
        }
    }
}
