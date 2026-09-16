import Foundation

enum ReviewRating: String, CaseIterable, Identifiable, Codable {
    case again
    case hard
    case good

    var id: String { rawValue }

    var title: String {
        switch self {
        case .again:
            return "Неправильно"
        case .hard:
            return "Почти"
        case .good:
            return "Правильно"
        }
    }

    var iconName: String {
        switch self {
        case .again:
            return "xmark.circle.fill"
        case .hard:
            return "exclamationmark.circle.fill"
        case .good:
            return "checkmark.circle.fill"
        }
    }
}
