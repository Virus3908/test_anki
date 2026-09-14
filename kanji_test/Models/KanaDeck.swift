import Foundation

enum KanaDeck: String, CaseIterable, Identifiable, Sendable {
    case hiragana
    case katakana

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hiragana:
            return "Хирагана"
        case .katakana:
            return "Катакана"
        }
    }

    var subtitle: String {
        switch self {
        case .hiragana:
            return "Японская слоговая азбука для слов японского происхождения"
        case .katakana:
            return "Слоговая азбука для заимствований, имен и выделения"
        }
    }

    var baseCards: [KanaStudyCard] {
        switch self {
        case .hiragana:
            return KanaStudyCard.hiragana
        case .katakana:
            return KanaStudyCard.katakana
        }
    }

    var cards: [KanaStudyCard] {
        baseCards
    }
}
