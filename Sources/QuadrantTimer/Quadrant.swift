import Foundation

enum Quadrant: String, Codable, CaseIterable, Identifiable {
    case q1, q2, q3, q4, breakTime

    var id: String { rawValue }

    var label: String {
        switch self {
        case .q1: "Urgent & Important"
        case .q2: "Important, Not Urgent"
        case .q3: "Urgent, Not Important"
        case .q4: "Neither Urgent nor Important"
        case .breakTime: "Break"
        }
    }

    var shortcutDigit: Int {
        switch self {
        case .q1: 1
        case .q2: 2
        case .q3: 3
        case .q4: 4
        case .breakTime: 0
        }
    }

    static let working: [Quadrant] = [.q1, .q2, .q3, .q4]
}
