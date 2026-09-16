import Foundation

enum FrontFieldKind: String, CaseIterable, Identifiable {
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

enum MeaningLanguage: String, CaseIterable, Identifiable {
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
