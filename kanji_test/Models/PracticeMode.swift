import Foundation

nonisolated enum PracticeMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case kanji
    case words
    case kana
    case anki

    var id: String { rawValue }

    var title: String {
        switch self {
        case .kanji:
            return "Кандзи"
        case .words:
            return "Слова"
        case .kana:
            return "Кана"
        case .anki:
            return "Анки"
        }
    }
}
