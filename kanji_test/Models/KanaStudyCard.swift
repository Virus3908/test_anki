import Foundation

nonisolated struct KanaStudyCard: Identifiable, Sendable {
    var id: String { character }

    let character: String
    let script: KanaDeck
    let reading: String
    let drawingCards: [KanjiCard]

    /// Total stroke count; drawing always evaluates each character separately.
    var strokes: [KanjiStroke] { drawingCards.flatMap(\.strokes) }

    init(character: String, reading: String, script: KanaDeck, drawingCards: [KanjiCard]) {
        self.character = character
        self.reading = reading
        self.script = script
        self.drawingCards = drawingCards
    }

    /// Adapter to the existing multi-character drawing session, without word progress keys.
    @MainActor var drawingWordCard: WordStudyCard {
        WordStudyCard(word: character, reading: reading, meaning: "", examples: [], kanjiCards: drawingCards)
    }
}
