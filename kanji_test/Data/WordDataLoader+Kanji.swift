import Foundation

extension WordDataLoader {
    static func loadKanjiCards(for entries: [WordDictionaryEntry], provider: KanjiProviding) async -> [KanjiCard] {
        var sourceCards = loadSourceKanjiCards()
        let knownCharacters = Set(sourceCards.map(\.kanji))
        let missingCharacters = Array(requiredKanjiCharacters(in: entries).subtracting(knownCharacters)).sorted()

        guard !missingCharacters.isEmpty else {
            return sourceCards
        }

        do {
            let remoteCards = try await provider.loadCards(for: missingCharacters)
            if !remoteCards.isEmpty {
                KanjiDataLoader.cacheCards(remoteCards)
                sourceCards.append(contentsOf: remoteCards)
            }
        } catch {
            assertionFailure("Failed to load kanji for word deck: \(error)")
        }

        return sourceCards
    }

    static func loadSourceKanjiCards() -> [KanjiCard] {
        let availableCards = KanjiDataLoader.loadAvailableCards(deck: .all)
        if !availableCards.isEmpty {
            return availableCards
        }

        let masterCards = KanjiDataLoader.loadBundledMasterCards()
        return masterCards.isEmpty ? KanjiDataLoader.loadLocalCards() : masterCards
    }

    static func requiredKanjiCharacters(in entries: [WordDictionaryEntry]) -> Set<String> {
        Set(entries.flatMap { entry in
            entry.word.map(String.init).filter(isKanji)
        })
    }
}
