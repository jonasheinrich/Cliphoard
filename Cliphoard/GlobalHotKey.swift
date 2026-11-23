import AppKit
import Carbon.HIToolbox
import Observation

nonisolated struct HotKey: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt
    /// The key as typed when recorded, for display.
    var keyLabel: String

    static let `default` = HotKey(
        keyCode: UInt32(kVK_ANSI_C),
        modifiers: NSEvent.ModifierFlags([.command, .shift]).rawValue,
        keyLabel: "C"
    )

    private static let supportedModifiers: NSEvent.ModifierFlags = [.control, .option, .shift, .command]

    init(keyCode: UInt32, modifiers: UInt, keyLabel: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.keyLabel = keyLabel
    }

    /// Nil unless ⌘, ⌥ or ⌃ is held: a bare key would fire while typing.
    init?(event: NSEvent) {
        let flags = event.modifierFlags.intersection(Self.supportedModifiers)
        guard !flags.isDisjoint(with: [.command, .option, .control]) else { return nil }
        keyCode = UInt32(event.keyCode)
        modifiers = flags.rawValue
        keyLabel = Self.specialKeyNames[Int(event.keyCode)]
            ?? event.charactersIgnoringModifiers?.uppercased()
            ?? "?"
    }

    var modifierFlags: NSEvent.ModifierFlags { NSEvent.ModifierFlags(rawValue: modifiers) }

    var displayString: String {
        let flags = modifierFlags
        var result = ""
        if flags.contains(.control) { result += "⌃" }
        if flags.contains(.option) { result += "⌥" }
        if flags.contains(.shift) { result += "⇧" }
        if flags.contains(.command) { result += "⌘" }
        return result + keyLabel
    }

    var carbonModifiers: UInt32 {
        let flags = modifierFlags
        var result = 0
        if flags.contains(.control) { result |= controlKey }
        if flags.contains(.option) { result |= optionKey }
        if flags.contains(.shift) { result |= shiftKey }
        if flags.contains(.command) { result |= cmdKey }
        return UInt32(result)
    }

    private static let specialKeyNames: [Int: String] = [
        kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Delete: "⌫",
        kVK_ForwardDelete: "⌦", kVK_Escape: "⎋",
        kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
        kVK_Home: "↖", kVK_End: "↘", kVK_PageUp: "⇞", kVK_PageDown: "⇟",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
        kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
    ]
}

/// Uses Carbon's RegisterEventHotKey, which, unlike a global NSEvent monitor,
/// needs no Accessibility permission and swallows the key press.
@Observable
final class GlobalHotKeyController {
    private static let enabledKey = "globalHotKeyEnabled"
    private static let hotKeyKey = "globalHotKey"

    var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Self.enabledKey)
            updateRegistration()
        }
    }

    var hotKey: HotKey {
        didSet {
            if let data = try? JSONEncoder().encode(hotKey) {
                UserDefaults.standard.set(data, forKey: Self.hotKeyKey)
            }
            updateRegistration()
        }
    }

    /// Set while the settings page records a new shortcut, so the current one
    /// can be typed.
    var isPaused = false {
        didSet { updateRegistration() }
    }

    private(set) var registrationError: String?

    @ObservationIgnored var action: () -> Void = {}
    @ObservationIgnored private var hotKeyRef: EventHotKeyRef?

    init() {
        let defaults = UserDefaults.standard
        isEnabled = defaults.bool(forKey: Self.enabledKey)
        hotKey = defaults.data(forKey: Self.hotKeyKey)
            .flatMap { try? JSONDecoder().decode(HotKey.self, from: $0) }
            ?? .default
        installHandler()
        updateRegistration()
    }

    private func installHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                guard let userData else { return OSStatus(eventNotHandledErr) }
                let controller = Unmanaged<GlobalHotKeyController>.fromOpaque(userData).takeUnretainedValue()
                // Carbon delivers hot key events on the main thread.
                MainActor.assumeIsolated { controller.action() }
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            nil
        )
        if status != noErr {
            print("Could not install hot key handler: \(status)")
        }
    }

    private func updateRegistration() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        registrationError = nil
        guard isEnabled, !isPaused else { return }

        let id = EventHotKeyID(signature: OSType(0x434C_4950), id: 1) // "CLIP"
        let status = RegisterEventHotKey(
            hotKey.keyCode, hotKey.carbonModifiers, id, GetApplicationEventTarget(), 0, &hotKeyRef
        )
        if status != noErr {
            hotKeyRef = nil
            registrationError = status == eventHotKeyExistsErr
                ? "\(hotKey.displayString) is already used by another app."
                : "Could not register \(hotKey.displayString) (error \(status))."
        }
    }
}
