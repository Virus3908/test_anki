import Foundation

nonisolated enum ReviewRating: String, CaseIterable, Sendable, Identifiable, Codable {
    case again, hard, good, easy
    var id: String { rawValue }
    var ankiGrade: Int {
        switch self { case .again: 1; case .hard: 2; case .good: 3; case .easy: 4 }
    }
    var title: String {
        switch self { case .again: "Снова"; case .hard: "Трудно"; case .good: "Хорошо"; case .easy: "Легко" }
    }
    var iconName: String {
        switch self {
        case .again: "arrow.counterclockwise.circle.fill"
        case .hard: "exclamationmark.circle.fill"
        case .good: "checkmark.circle.fill"
        case .easy: "star.circle.fill"
        }
    }
}
