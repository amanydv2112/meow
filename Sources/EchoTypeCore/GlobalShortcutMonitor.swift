import AppKit
import Foundation

public final class GlobalShortcutMonitor: @unchecked Sendable {
    public var keyCode: Int
    public var requiresOption: Bool
    public var onShortcutDown: (@MainActor @Sendable () -> Void)?
    public var onShortcutUp: (@MainActor @Sendable () -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isPressed = false
    private var optionIsDown = false

    public init(keyCode: Int = 49, requiresOption: Bool = true) {
        self.keyCode = keyCode
        self.requiresOption = requiresOption
    }

    deinit {
        stop()
    }

    @discardableResult
    public func start() -> Bool {
        stop()

        let mask = (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: Self.eventCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let eventTap else { return false }
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        if let runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        CGEvent.tapEnable(tap: eventTap, enable: true)
        return true
    }

    public func stop() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        isPressed = false
        optionIsDown = false
    }

    private static let eventCallback: CGEventTapCallBack = { _, type, event, userInfo in
        guard let userInfo else { return Unmanaged.passUnretained(event) }
        let monitor = Unmanaged<GlobalShortcutMonitor>.fromOpaque(userInfo).takeUnretainedValue()
        return monitor.handle(type: type, event: event)
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        guard type == .keyDown || type == .keyUp || type == .flagsChanged else {
            return Unmanaged.passUnretained(event)
        }

        let eventKeyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags
        let eventHasOption = flags.contains(.maskAlternate)
        let optionMatches = !requiresOption || eventHasOption || optionIsDown

        if type == .flagsChanged {
            optionIsDown = eventHasOption
            if isPressed, requiresOption, !optionIsDown {
                finishShortcut()
                return nil
            }
            return Unmanaged.passUnretained(event)
        }

        guard eventKeyCode == keyCode else {
            if isPressed, requiresOption, !optionMatches {
                finishShortcut()
                return nil
            }
            return Unmanaged.passUnretained(event)
        }

        if type == .keyDown {
            guard optionMatches else {
                return Unmanaged.passUnretained(event)
            }
            if !isPressed {
                isPressed = true
                let callback = onShortcutDown
                Task { @MainActor in callback?() }
            }
            return nil
        } else if type == .keyUp {
            if isPressed {
                finishShortcut()
                return nil
            }
        }

        return Unmanaged.passUnretained(event)
    }

    private func finishShortcut() {
        isPressed = false
        let callback = onShortcutUp
        Task { @MainActor in callback?() }
    }
}
