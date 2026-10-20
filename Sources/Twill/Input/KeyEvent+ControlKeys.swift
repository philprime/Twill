/// Legacy control chords use the identities actually delivered by the byte decoder.
/// Some chords share bytes with named special keys and cannot be distinguished.
extension KeyEvent {
    /// Ctrl-@, also used for Ctrl-Space.
    public static let controlAt = Self.control(0x00)

    /// Ctrl-A as a legacy terminal control byte.
    public static let controlA = Self.control(0x01)

    /// Ctrl-B as a legacy terminal control byte.
    public static let controlB = Self.control(0x02)

    /// Ctrl-C, normally used to request orderly application shutdown.
    public static let controlC = Self.control(0x03)

    /// Ctrl-D, conventionally associated with end-of-input.
    public static let controlD = Self.control(0x04)

    /// Ctrl-E as a legacy terminal control byte.
    public static let controlE = Self.control(0x05)

    /// Ctrl-F as a legacy terminal control byte.
    public static let controlF = Self.control(0x06)

    /// Ctrl-G as a legacy terminal control byte.
    public static let controlG = Self.control(0x07)

    /// Ctrl-H, indistinguishable from backspace in legacy terminal input.
    public static let controlH = Self.backspace

    /// Ctrl-I, indistinguishable from tab in legacy terminal input.
    public static let controlI = Self.tab

    /// Ctrl-J, indistinguishable from enter in legacy terminal input.
    public static let controlJ = Self.enter

    /// Ctrl-K as a legacy terminal control byte.
    public static let controlK = Self.control(0x0B)

    /// Ctrl-L as a legacy terminal control byte.
    public static let controlL = Self.control(0x0C)

    /// Ctrl-M, indistinguishable from enter in legacy terminal input.
    public static let controlM = Self.enter

    /// Ctrl-N as a legacy terminal control byte.
    public static let controlN = Self.control(0x0E)

    /// Ctrl-O as a legacy terminal control byte.
    public static let controlO = Self.control(0x0F)

    /// Ctrl-P as a legacy terminal control byte.
    public static let controlP = Self.control(0x10)

    /// Ctrl-Q as a legacy terminal control byte.
    public static let controlQ = Self.control(0x11)

    /// Ctrl-R as a legacy terminal control byte.
    public static let controlR = Self.control(0x12)

    /// Ctrl-S as a legacy terminal control byte.
    public static let controlS = Self.control(0x13)

    /// Ctrl-T as a legacy terminal control byte.
    public static let controlT = Self.control(0x14)

    /// Ctrl-U as a legacy terminal control byte.
    public static let controlU = Self.control(0x15)

    /// Ctrl-V as a legacy terminal control byte.
    public static let controlV = Self.control(0x16)

    /// Ctrl-W as a legacy terminal control byte.
    public static let controlW = Self.control(0x17)

    /// Ctrl-X as a legacy terminal control byte.
    public static let controlX = Self.control(0x18)

    /// Ctrl-Y as a legacy terminal control byte.
    public static let controlY = Self.control(0x19)

    /// Ctrl-Z as a legacy terminal control byte.
    public static let controlZ = Self.control(0x1A)

    /// Ctrl-[, indistinguishable from Escape in legacy terminal input.
    public static let controlLeftBracket = Self.escape

    /// Ctrl-Backslash as a legacy terminal control byte.
    public static let controlBackslash = Self.control(0x1C)

    /// Ctrl-] as a legacy terminal control byte.
    public static let controlRightBracket = Self.control(0x1D)

    /// Ctrl-^ as a legacy terminal control byte.
    public static let controlCaret = Self.control(0x1E)

    /// Ctrl-_ as a legacy terminal control byte.
    public static let controlUnderscore = Self.control(0x1F)

    /// Ctrl-Space, indistinguishable from Ctrl-@ in legacy terminal input.
    public static let controlSpace = Self.controlAt

    /// Ctrl-?, indistinguishable from Backspace in legacy terminal input.
    public static let controlQuestionMark = Self.backspace
}
