import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let logQ1       = Self("logQ1",       default: .init(.one,   modifiers: [.command, .control, .option]))
    static let logQ2       = Self("logQ2",       default: .init(.two,   modifiers: [.command, .control, .option]))
    static let logQ3       = Self("logQ3",       default: .init(.three, modifiers: [.command, .control, .option]))
    static let logQ4       = Self("logQ4",       default: .init(.four,  modifiers: [.command, .control, .option]))
    static let toggleBreak = Self("toggleBreak", default: .init(.zero,  modifiers: [.command, .control, .option]))
}

extension Quadrant {
    var shortcutName: KeyboardShortcuts.Name? {
        switch self {
        case .q1: .logQ1
        case .q2: .logQ2
        case .q3: .logQ3
        case .q4: .logQ4
        case .breakTime: nil
        }
    }
}
