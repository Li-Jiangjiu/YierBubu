/// Core Graphics / IOLLEvent device-side modifier masks. Kept pure for testing.
public enum InputNormalizer {
    public static func modifier(code: UInt16, flags: UInt64) -> DeviceInput? {
        let mask: UInt64
        switch code {
        case 59: mask = 0x1    // left control
        case 56: mask = 0x2    // left shift
        case 60: mask = 0x4    // right shift
        case 55: mask = 0x8    // left command
        case 54: mask = 0x10   // right command
        case 58: mask = 0x20   // left option
        case 61: mask = 0x40   // right option
        case 62: mask = 0x2000 // right control
        case 57: mask = 0x10000 // caps lock toggle state
        default: return nil
        }
        return flags & mask != 0 ? .keyDown(code: code, isRepeat: false) : .keyUp(code: code)
    }
    public static func button(number: Int64) -> MouseButton? {
        switch number { case 0: .left; case 1: .right; case 2: .middle; default: nil }
    }
}
