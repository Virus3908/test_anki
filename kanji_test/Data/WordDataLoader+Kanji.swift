import Foundation

extension WordDataLoader {
    static func loadKanjiCards(for entries: [WordDictionaryEntry], provider: KanjiProviding) async -> [KanjiCard] {
        var sourceCards = await loadSourceKanjiCards()
        let knownCharacters = Set(sourceCards.map(\.kanji))
        let missingCharacters = Array(requiredKanjiCharacters(in: entries).subtracting(knownCharacters)).sorted()

        guard !missingCharacters.isEmpty else {
            return sourceCards
        }

        do {
            let remoteCards = try await provider.loadCards(for: missingCharacters)
            if !remoteCards.isEmpty {
                try? await KanjiDataLoader.cacheCards(remoteCards)
                sourceCards.append(contentsOf: remoteCards)
            }
        } catch {
            // Dictionary entries remain usable when drawing resources are unavailable.
        }

        return sourceCards
    }

    static func loadSourceKanjiCards() async -> [KanjiCard] {
        let availableCards = await KanjiDataLoader.loadAvailableCards(deck: .all)
        if !availableCards.isEmpty {
            return availableCards
        }

        let masterCards = await KanjiDataLoader.loadBundledMasterCards()
        return masterCards.isEmpty ? await KanjiDataLoader.loadLocalCards() : masterCards
    }

    static func requiredKanjiCharacters(in entries: [WordDictionaryEntry]) -> Set<String> {
        Set(entries.flatMap { entry in
            entry.word.map(String.init).filter(isKanji)
        })
    }
}
