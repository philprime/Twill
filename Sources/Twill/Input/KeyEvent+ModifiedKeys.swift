extension KeyEvent {
    /// Adds reported modifier flags while preserving flags already present.
    /// Use a base key for combined chords, such as `.s.withModifiers([.control, .superKey])`.
    public func withModifiers(_ additional: KeyModifiers) -> Self {
        Self(key, modifiers: modifiers.union(additional))
    }

    /// A with the terminal-reported Super (Command on macOS) modifier.
    public static let superA = Self.a.withModifiers(.superKey)

    /// B with the terminal-reported Super (Command on macOS) modifier.
    public static let superB = Self.b.withModifiers(.superKey)

    /// C with the terminal-reported Super (Command on macOS) modifier.
    public static let superC = Self.c.withModifiers(.superKey)

    /// D with the terminal-reported Super (Command on macOS) modifier.
    public static let superD = Self.d.withModifiers(.superKey)

    /// E with the terminal-reported Super (Command on macOS) modifier.
    public static let superE = Self.e.withModifiers(.superKey)

    /// F with the terminal-reported Super (Command on macOS) modifier.
    public static let superF = Self.f.withModifiers(.superKey)

    /// G with the terminal-reported Super (Command on macOS) modifier.
    public static let superG = Self.g.withModifiers(.superKey)

    /// H with the terminal-reported Super (Command on macOS) modifier.
    public static let superH = Self.h.withModifiers(.superKey)

    /// I with the terminal-reported Super (Command on macOS) modifier.
    public static let superI = Self.i.withModifiers(.superKey)

    /// J with the terminal-reported Super (Command on macOS) modifier.
    public static let superJ = Self.j.withModifiers(.superKey)

    /// K with the terminal-reported Super (Command on macOS) modifier.
    public static let superK = Self.k.withModifiers(.superKey)

    /// L with the terminal-reported Super (Command on macOS) modifier.
    public static let superL = Self.l.withModifiers(.superKey)

    /// M with the terminal-reported Super (Command on macOS) modifier.
    public static let superM = Self.m.withModifiers(.superKey)

    /// N with the terminal-reported Super (Command on macOS) modifier.
    public static let superN = Self.n.withModifiers(.superKey)

    /// O with the terminal-reported Super (Command on macOS) modifier.
    public static let superO = Self.o.withModifiers(.superKey)

    /// P with the terminal-reported Super (Command on macOS) modifier.
    public static let superP = Self.p.withModifiers(.superKey)

    /// Q with the terminal-reported Super (Command on macOS) modifier.
    public static let superQ = Self.q.withModifiers(.superKey)

    /// R with the terminal-reported Super (Command on macOS) modifier.
    public static let superR = Self.r.withModifiers(.superKey)

    /// S with the terminal-reported Super (Command on macOS) modifier.
    public static let superS = Self.s.withModifiers(.superKey)

    /// T with the terminal-reported Super (Command on macOS) modifier.
    public static let superT = Self.t.withModifiers(.superKey)

    /// U with the terminal-reported Super (Command on macOS) modifier.
    public static let superU = Self.u.withModifiers(.superKey)

    /// V with the terminal-reported Super (Command on macOS) modifier.
    public static let superV = Self.v.withModifiers(.superKey)

    /// W with the terminal-reported Super (Command on macOS) modifier.
    public static let superW = Self.w.withModifiers(.superKey)

    /// X with the terminal-reported Super (Command on macOS) modifier.
    public static let superX = Self.x.withModifiers(.superKey)

    /// Y with the terminal-reported Super (Command on macOS) modifier.
    public static let superY = Self.y.withModifiers(.superKey)

    /// Z with the terminal-reported Super (Command on macOS) modifier.
    public static let superZ = Self.z.withModifiers(.superKey)
}
