import Foundation

/// Drawing resources for one character, shared by kana decks and word builders.
nonisolated enum BundledKanaDrawing {
    static func card(for character: String) throws -> KanjiCard {
        let strokes = try BundledKanjiVG.strokes(for: character)
        return KanjiCard(
            kanji: character, meanings: [], onyomi: [], kunyomi: [], examples: [],
            source: KanjiSource(
                name: "KanjiVG", file: BundledKanjiVG.fileName(for: character),
                license: "KanjiVG / CC BY-SA 3.0"
            ),
            strokes: strokes, translationState: "ru-system"
        )
    }
}
