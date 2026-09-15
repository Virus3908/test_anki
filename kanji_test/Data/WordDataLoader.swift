import Foundation

enum WordDataLoader {
    static func loadWords() async -> [WordStudyCard] {
        await Task.yield()

        let entries = await loadDictionaryEntries()
        let kanjiCards = await loadKanjiCards(for: entries)
        let cardsByCharacter = Dictionary(kanjiCards.map { ($0.kanji, $0) }, uniquingKeysWith: { current, _ in current })
        let loadedWords = buildWords(from: entries, cardsByCharacter: cardsByCharacter)

        if !loadedWords.isEmpty {
            return loadedWords
        }

        return WordStudyCard.build(from: kanjiCards)
    }

    private static func loadDictionaryEntries() async -> [WordDictionaryEntry] {
        loadBundledEntries()
    }

    private static func loadKanjiCards(for entries: [WordDictionaryEntry]) async -> [KanjiCard] {
        var sourceCards = loadSourceKanjiCards()
        let knownCharacters = Set(sourceCards.map(\.kanji))
        let missingCharacters = Array(requiredKanjiCharacters(in: entries).subtracting(knownCharacters)).sorted()

        guard !missingCharacters.isEmpty else {
            return sourceCards
        }

        do {
            let remoteCards = try await RemoteKanjiProvider.loadCards(for: missingCharacters)
            if !remoteCards.isEmpty {
                KanjiDataLoader.cacheCards(remoteCards)
                sourceCards.append(contentsOf: remoteCards)
            }
        } catch {
            assertionFailure("Failed to load kanji for word deck: \(error)")
        }

        return sourceCards
    }

    private static func loadSourceKanjiCards() -> [KanjiCard] {
        let availableCards = KanjiDataLoader.loadAvailableCards(deck: .all)
        if !availableCards.isEmpty {
            return availableCards
        }

        let masterCards = KanjiDataLoader.loadBundledMasterCards()
        return masterCards.isEmpty ? KanjiDataLoader.loadLocalCards() : masterCards
    }

    private static func requiredKanjiCharacters(in entries: [WordDictionaryEntry]) -> Set<String> {
        Set(entries.flatMap { entry in
            entry.word.map(String.init).filter(isKanji)
        })
    }

    private static func loadBundledEntries() -> [WordDictionaryEntry] {
        guard let url = Bundle.main.url(forResource: "word-data", withExtension: "json") else {
            assertionFailure("word-data.json is missing from the app bundle.")
            return WordSeed.common
        }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([WordDictionaryEntry].self, from: data)
        } catch {
            assertionFailure("Failed to decode word-data.json: \(error)")
            return WordSeed.common
        }
    }

    private static func buildWords(
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

    nonisolated private static func isUsableJapaneseWord(_ text: String) -> Bool {
        text.allSatisfy { character in
            let value = character.unicodeScalars.first.map { Int($0.value) } ?? 0
            return (0x3040...0x309F).contains(value)
                || (0x30A0...0x30FF).contains(value)
                || (0x4E00...0x9FFF).contains(value)
        }
    }
}
