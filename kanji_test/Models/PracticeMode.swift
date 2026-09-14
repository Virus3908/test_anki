import Foundation

enum PracticeMode: String, CaseIterable, Identifiable {
    case kanji
    case words
    case kana

    var id: String { rawValue }

    var title: String {
        switch self {
        case .kanji:
            return "Кандзи"
        case .words:
            return "Слова"
        case .kana:
            return "Кана"
        }
    }
}
