import Foundation

/// Stable identity independent of built-in deck enums; imported decks can use their own namespace.
nonisolated struct StudyDeck: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let title: String
    let mode: PracticeMode
}

extension StudyDeck {
    static func kanji(_ deck: KanjiDeck) -> Self { .init(id: "kanji:\(deck.rawValue)", title: deck.title, mode: .kanji) }
    static func words(_ deck: WordFrequencyDeck) -> Self { .init(id: "words:\(deck.rawValue)", title: deck.title, mode: .words) }
    static func kana(_ deck: KanaDeck) -> Self { .init(id: "kana:\(deck.rawValue)", title: deck.title, mode: .kana) }
    static var builtIn: [Self] {
        KanjiDeck.allCases.map(Self.kanji) + WordFrequencyDeck.allCases.map(Self.words) + KanaDeck.allCases.map(Self.kana)
    }
}

extension StudyRoute {
    var deck: StudyDeck? {
        switch self {
        case .kanjiDeck(let value): return .kanji(value)
        case .wordDeck(let value): return .words(value)
        case .kanaDeck(let value): return .kana(value)
        default: return nil
        }
    }
}
