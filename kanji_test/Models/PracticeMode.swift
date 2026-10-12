import Foundation

nonisolated enum PracticeMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case kanji
    case words
    case kana
    case anki
    case grammar

    var id: String { rawValue }

    var title: String {
        switch self {
        case .kanji:
            return "Кандзи"
        case .words:
            return "Слова"
        case .kana:
            return "Кана"
        case .grammar:
            return "Грамматика"
        case .anki:
            return "Анки"
        }
    }
}
