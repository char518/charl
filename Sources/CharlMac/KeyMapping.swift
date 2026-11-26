import Carbon.HIToolbox
import CharlCore

enum KeyMapping {
    static func carbonKeyCode(for key: KeyCombo.Key) -> Int? {
        switch key {
        case .a: return kVK_ANSI_A
        case .b: return kVK_ANSI_B
        case .c: return kVK_ANSI_C
        case .d: return kVK_ANSI_D
        case .e: return kVK_ANSI_E
        case .f: return kVK_ANSI_F
        case .g: return kVK_ANSI_G
        case .h: return kVK_ANSI_H
        case .i: return kVK_ANSI_I
        case .j: return kVK_ANSI_J
        case .k: return kVK_ANSI_K
        case .l: return kVK_ANSI_L
        case .m: return kVK_ANSI_M
        case .n: return kVK_ANSI_N
        case .o: return kVK_ANSI_O
        case .p: return kVK_ANSI_P
        case .q: return kVK_ANSI_Q
        case .r: return kVK_ANSI_R
        case .s: return kVK_ANSI_S
        case .t: return kVK_ANSI_T
        case .u: return kVK_ANSI_U
        case .v: return kVK_ANSI_V
        case .w: return kVK_ANSI_W
        case .x: return kVK_ANSI_X
        case .y: return kVK_ANSI_Y
        case .z: return kVK_ANSI_Z
        case .zero: return kVK_ANSI_0
        case .one: return kVK_ANSI_1
        case .two: return kVK_ANSI_2
        case .three: return kVK_ANSI_3
        case .four: return kVK_ANSI_4
        case .five: return kVK_ANSI_5
        case .six: return kVK_ANSI_6
        case .seven: return kVK_ANSI_7
        case .eight: return kVK_ANSI_8
        case .nine: return kVK_ANSI_9
        case .space: return kVK_Space
        case .escape: return kVK_Escape
        case .return: return kVK_Return
        case .tab: return kVK_Tab
        case .delete: return kVK_Delete
        case .up: return kVK_UpArrow
        case .down: return kVK_DownArrow
        case .left: return kVK_LeftArrow
        case .right: return kVK_RightArrow
        case .f1: return kVK_F1
        case .f2: return kVK_F2
        case .f3: return kVK_F3
        case .f4: return kVK_F4
        case .f5: return kVK_F5
        case .f6: return kVK_F6
        case .f7: return kVK_F7
        case .f8: return kVK_F8
        case .f9: return kVK_F9
        case .f10: return kVK_F10
        case .f11: return kVK_F11
        case .f12: return kVK_F12
        }
    }

    static func carbonModifiers(for modifiers: KeyCombo.Modifiers) -> Int {
        var flags = 0
        if modifiers.contains(.command) { flags |= cmdKey }
        if modifiers.contains(.control) { flags |= controlKey }
        if modifiers.contains(.option) { flags |= optionKey }
        if modifiers.contains(.shift) { flags |= shiftKey }
        return flags
    }

    private static let reverse: [Int: KeyCombo.Key] = {
        var map: [Int: KeyCombo.Key] = [:]
        for key in KeyCombo.Key.allCases {
            if let code = carbonKeyCode(for: key) {
                map[code] = key
            }
        }
        return map
    }()

    static func key(forCarbonKeyCode code: Int) -> KeyCombo.Key? {
        reverse[code]
    }
}