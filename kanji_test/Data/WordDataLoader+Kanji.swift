import Foundation

extension WordDataLoader {
    static func loadKanjiCards(for entries: [WordDictionaryEntry], provider _: KanjiProviding) async -> [KanjiCard] {
        let characters = requiredKanjiCharacters(in: entries)
        return (try? await BundledStudyData.shared.bundledKanjiCards(characters: characters)) ?? []
    }

    static func loadSourceKanjiCards() async -> [KanjiCard] {
        let availableCards = await KanjiDataLoader.loadAvailableCards(deck: .all)
        if !availableCards.isEmpty {
            return availableCards
        }

        let masterCards = await KanjiDataLoader.loadBundledMasterCards()
        return masterCards.isEmpty ? await KanjiDataLoader.loadLocalCards() : masterCards
    }

    nonisolated static func requiredKanjiCharacters(in entries: [WordDictionaryEntry]) -> Set<String> {
        Set(entries.flatMap { entry in
            entry.word.map(String.init).filter(isKanji)
        })
    }
}
