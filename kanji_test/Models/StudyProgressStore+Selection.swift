import Foundation

nonisolated extension StudyProgressStore {
    func orderedCards(_ cards: [KanjiCard], now: Date = Date()) -> [KanjiCard] {
        cards.sorted {
            let left = records[$0.kanji]?.dueDate ?? .distantPast
            let right = records[$1.kanji]?.dueDate ?? .distantPast
            return left == right ? $0.kanji < $1.kanji : left < right
        }
    }
}
