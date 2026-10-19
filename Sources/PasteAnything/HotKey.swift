import Carbon.HIToolbox

/// Atajo de teclado global registrado con Carbon.
@MainActor
final class HotKey {
    private static var sharedAction: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    var action: (() -> Void)? {
        get { Self.sharedAction }
        set { Self.sharedAction = newValue }
    }

    init() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            Task { @MainActor in HotKey.sharedAction?() }
            return noErr
        }, 1, &eventType, nil, &handlerRef)
    }

    func register(_ preset: HotKeyPreset) {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        let hotKeyID = EventHotKeyID(signature: OSType(0x5041_4E59), id: 1) // "PANY"
        RegisterEventHotKey(preset.keyCode, preset.modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }
}
