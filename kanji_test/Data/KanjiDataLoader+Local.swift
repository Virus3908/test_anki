import Foundation

extension KanjiDataLoader {
    static func loadBundledMasterCards() async -> [KanjiCard] {
        let metadata = (try? await BundledStudyData.shared.bundledKanjiMetadata()) ?? []
        return (try? await BundledStudyData.shared.bundledKanjiCards(characters: Set(metadata.map(\.kanji)))) ?? []
    }

    static func loadAvailableCards(deck: KanjiDeck) async -> [KanjiCard] {
        let metadata = (try? await BundledStudyData.shared.bundledKanjiMetadata()) ?? []
        let characters = Set(metadata.filter { metadata in
            switch deck {
            case .joyo: metadata.joyo
            case .jinmeiyo: metadata.jinmeiyo
            case .all: true
            default: metadata.makeCardFilter(deck)
            }
        }.map(\.kanji))
        return (try? await BundledStudyData.shared.bundledKanjiCards(characters: characters)) ?? []
    }

    static func loadLocalCards() async -> [KanjiCard] {
        await loadBundledMasterCards()
    }
}

private extension BundledKanjiMetadata {
    func makeCardFilter(_ deck: KanjiDeck) -> Bool {
        switch deck {
        case .jlpt5: jlpt == 5
        case .jlpt4: jlpt == 4
        case .jlpt3: jlpt == 3
        case .jlpt2: jlpt == 2
        case .jlpt1: jlpt == 1
        case .grade1: grade == 1
        case .grade2: grade == 2
        case .grade3: grade == 3
        case .grade4: grade == 4
        case .grade5: grade == 5
        case .grade6: grade == 6
        case .grade8: grade == 8
        case .joyo, .jinmeiyo, .all: false
        }
    }
}
