import Foundation

nonisolated enum FrontFieldKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case readings
    case meanings
    case character

    var id: String { rawValue }

    var title: String {
        switch self {
        case .readings:
            return "Чтения"
        case .meanings:
            return "Значения"
        case .character:
            return "Знак"
        }
    }
}

nonisolated enum MeaningLanguage: String, CaseIterable, Identifiable, Codable, Sendable {
    case russian
    case english

    var id: String { rawValue }

    var title: String {
        switch self {
        case .russian:
            return "Русский"
        case .english:
            return "English"
        }
    }
}
