import Carbon.HIToolbox
import CharlCore
import CharlPlatform
import Foundation

public final class CarbonHotkeyCenter: HotkeyService {
    private var handlers: [UInt32: () -> Void] = [:]
    private var refs: [UInt32: EventHotKeyRef] = [:]
    private var nextID: UInt32 = 1
    private var eventHandler: EventHandlerRef?

    private static let signature: OSType = 0x4348_414F // "CHAO"

    public init() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            hotKeyCallback,
            1,
            &eventType,
            selfPtr,
            &eventHandler
        )
        if status != noErr {
            Log.hotkey.error("InstallEventHandler failed: \(status)")
        }
    }

    deinit {
        unregisterAll()
        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }

    @discardableResult
    public func register(_ combo: KeyCombo, handler: @escaping () -> Void) -> Bool {
        guard let keyCode = KeyMapping.carbonKeyCode(for: combo.key) else { return false }
        let id = nextID
        nextID += 1
        let hotKeyID = EventHotKeyID(signature: Self.signature, id: id)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(keyCode),
            UInt32(KeyMapping.carbonModifiers(for: combo.modifiers)),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        guard status == noErr, let ref else {
            Log.hotkey.error("RegisterEventHotKey \(combo.displayString, privacy: .public) failed: \(status)")
            return false
        }
        handlers[id] = handler
        refs[id] = ref
        Log.hotkey.notice("registered \(combo.displayString, privacy: .public)")
        return true
    }

    public func unregisterAll() {
        for ref in refs.values {
            UnregisterEventHotKey(ref)
        }
        refs.removeAll()
        handlers.removeAll()
    }

    public func key(for keyCode: UInt16) -> KeyCombo.Key? {
        KeyMapping.key(forCarbonKeyCode: Int(keyCode))
    }

    fileprivate func handle(id: UInt32) {
        Log.hotkey.debug("received hotkey id=\(id)")
        handlers[id]?()
    }
}

private func hotKeyCallback(
    _: EventHandlerCallRef?,
    event: EventRef?,
    userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event, let userData else { return OSStatus(eventNotHandledErr) }
    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    guard status == noErr else { return status }
    let center = Unmanaged<CarbonHotkeyCenter>.fromOpaque(userData).takeUnretainedValue()
    center.handle(id: hotKeyID.id)
    return noErr
}