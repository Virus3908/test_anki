import Foundation

struct WordStudyCard: Identifiable, Sendable {
    var id: String { "\(word)-\(reading)" }

    let word: String
    let reading: String
    let meaning: String
    let examples: [WordUsageExample]
    let kanjiCards: [KanjiCard]

    var kanjiText: String {
        kanjiCards.map(\.kanji).joined()
    }

    static func build(from cards: [KanjiCard]) -> [WordStudyCard] {
        let cardsByKanji = Dictionary(cards.map { ($0.kanji, $0) }, uniquingKeysWith: { current, _ in current })
        var seen: Set<String> = []
        var result: [WordStudyCard] = []

        for card in cards {
            for example in card.examples {
                let characters = example.word.map(String.init)
                let wordStudyCards = characters.compactMap { character -> KanjiCard? in
                    if let card = cardsByKanji[character] {
                        return card
                    }

                    guard isKana(character) else {
                        return nil
                    }

                    return kanaCard(for: character)
                }
                guard characters.allSatisfy(isJapaneseStudyCharacter),
                      wordStudyCards.count == characters.count,
                      seen.insert(example.word).inserted else {
                    continue
                }

                result.append(
                    WordStudyCard(
                        word: example.word,
                        reading: example.reading,
                        meaning: example.meaning,
                        examples: [],
                        kanjiCards: wordStudyCards
                    )
                )
            }
        }

        return result.sorted { left, right in
            if left.kanjiCards.count != right.kanjiCards.count {
                return left.kanjiCards.count < right.kanjiCards.count
            }

            if left.word.count != right.word.count {
                return left.word.count < right.word.count
            }

            return left.word < right.word
        }
    }

    nonisolated private static func isKanji(_ text: String) -> Bool {
        guard let scalar = text.unicodeScalars.first else {
            return false
        }

        return (0x4E00...0x9FFF).contains(Int(scalar.value))
    }

    nonisolated private static func isKana(_ text: String) -> Bool {
        guard let scalar = text.unicodeScalars.first else {
            return false
        }

        let value = Int(scalar.value)
        return (0x3040...0x309F).contains(value)
            || (0x30A0...0x30FF).contains(value)
    }

    private static func kanaCard(for character: String) -> KanjiCard {
        KanjiCard(
            kanji: character,
            meanings: [],
            onyomi: [],
            kunyomi: [],
            examples: [],
            source: KanjiSource(name: "Kana", file: "local-kana", license: "App data"),
            strokes: KanaStrokePresets.strokes(for: character),
            translationState: "ru-system"
        )
    }

    nonisolated private static func isJapaneseStudyCharacter(_ text: String) -> Bool {
        guard let scalar = text.unicodeScalars.first else {
            return false
        }

        let value = Int(scalar.value)
        return (0x3040...0x309F).contains(value)
            || (0x30A0...0x30FF).contains(value)
            || (0x4E00...0x9FFF).contains(value)
    }
}
