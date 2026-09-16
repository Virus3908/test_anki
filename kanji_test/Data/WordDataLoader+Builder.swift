import Foundation

extension WordDataLoader {
    static func buildWords(
        from entries: [WordDictionaryEntry],
        cardsByCharacter: [String: KanjiCard]
    ) -> [WordStudyCard] {
        var seen: Set<String> = []

        return entries.compactMap { entry in
            guard seen.insert(entry.word).inserted else {
                return nil
            }

            let characterCards = entry.word.map(String.init).compactMap { character -> KanjiCard? in
                if let card = cardsByCharacter[character] {
                    return card
                }

                guard isKana(character) else {
                    return nil
                }

                return kanaCard(for: character)
            }

            guard characterCards.count == entry.word.count else {
                return nil
            }

            return WordStudyCard(
                word: entry.word,
                reading: entry.reading,
                meaning: entry.meaning,
                examples: entry.examples,
                kanjiCards: characterCards
            )
        }
    }

    static func kanaCard(for character: String) -> KanjiCard {
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

    nonisolated static func isKanji(_ text: String) -> Bool {
        guard let scalar = text.unicodeScalars.first else {
            return false
        }

        return (0x4E00...0x9FFF).contains(Int(scalar.value))
    }

    nonisolated static func isKana(_ text: String) -> Bool {
        guard let scalar = text.unicodeScalars.first else {
            return false
        }

        let value = Int(scalar.value)
        return (0x3040...0x309F).contains(value)
            || (0x30A0...0x30FF).contains(value)
    }
}
