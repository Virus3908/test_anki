import Foundation

struct KanaStudyCard: Identifiable, Sendable {
    var id: String { character }

    let character: String
    let reading: String
    let strokes: [KanjiStroke]

    init(character: String, reading: String, strokes: [KanjiStroke]? = nil) {
        self.character = character
        self.reading = reading
        self.strokes = strokes ?? KanaStrokePresets.strokes(for: character)
    }

    static let hiragana: [KanaStudyCard] = HiraganaPresets.cards
    static let katakana: [KanaStudyCard] = KatakanaPresets.cards
}
