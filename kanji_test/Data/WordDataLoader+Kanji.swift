import Foundation

extension WordDataLoader {
    static func loadKanjiCards(for _: [WordDictionaryEntry], provider _: KanjiProviding) async -> [KanjiCard] {
        await loadSourceKanjiCards()
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
