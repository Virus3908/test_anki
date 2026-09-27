import Foundation

/// Presentation flavor of a study card: what the learner sees and how the
/// answer is validated. Pure presentation — progress and scheduling never
/// depend on the card type.
nonisolated enum TrainingCardType: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case drawing
    case flip
    case choice
    case typed
    case audio

    var id: String { rawValue }

    var title: String {
        switch self {
        case .drawing: return "Рисование"
        case .flip: return "Карточка"
        case .choice: return "Тест"
        case .typed: return "Ввод значения"
        case .audio: return "На слух"
        }
    }

    var symbolName: String {
        switch self {
        case .drawing: return "scribble"
        case .flip: return "rectangle.on.rectangle"
        case .choice: return "list.bullet.rectangle"
        case .typed: return "keyboard"
        case .audio: return "speaker.wave.2"
        }
    }

    /// Types that make sense for a content kind; Anki is outside the feature.
    static func allowed(for mode: PracticeMode) -> [Self] {
        switch mode {
        case .kanji: return allCases
        case .words: return [.flip, .choice, .typed, .audio]
        case .kana: return [.drawing, .flip, .choice, .audio]
        case .anki: return []
        }
    }

    /// Types used when a deck has no explicit configuration; preserves the
    /// pre-feature behavior of every content kind.
    static func defaults(for mode: PracticeMode) -> [Self] {
        switch mode {
        case .kanji, .kana: return [.drawing]
        case .words: return [.flip]
        case .anki: return []
        }
    }

    /// Types a session should actually use: stored selection filtered by what
    /// the content kind allows, falling back to the kind's defaults.
    static func effectiveTypes(configured: [Self]?, mode: PracticeMode) -> [Self] {
        guard let configured, !configured.isEmpty else { return defaults(for: mode) }
        let configuredSet = Set(configured)
        let filtered = allowed(for: mode).filter { configuredSet.contains($0) }
        return filtered.isEmpty ? defaults(for: mode) : filtered
    }

    /// Deterministic canonical order for persisted arrays.
    static func canonicalOrder(_ types: Set<Self>) -> [Self] {
        allCases.filter { types.contains($0) }
    }

    /// Pseudo-random but stable pick for one card within one day, so queue
    /// rebuilds and undo keep showing the same type.
    static func resolve(cardID: String, deckID: String, date: Date = Date(), allowed types: [Self]) -> Self {
        guard !types.isEmpty else { return .drawing }
        let dayOrdinal = Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0
        let index = Int(stableHash("\(deckID)|\(cardID)|\(dayOrdinal)") % UInt64(types.count))
        return types[index]
    }

    /// FNV-1a: stable across launches, unlike `String.hashValue`.
    private static func stableHash(_ seed: String) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in seed.utf8 {
            hash = (hash ^ UInt64(byte)) &* 0x100000001b3
        }
        return hash
    }
}
