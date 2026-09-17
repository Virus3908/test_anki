import Foundation

nonisolated extension KanjiReviewStore {
    func scheduleBuckets(for cards: [KanjiCard], now: Date = Date()) -> [KanjiReviewScheduleBucket] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: studyDate(now: now))
        let deckKanji = Set(cards.map(\.kanji))
        let deckRecords = records.filter { deckKanji.contains($0.key) }.map(\.value)
        let futureStart = calendar.date(byAdding: .day, value: 7, to: today) ?? today.addingTimeInterval(7 * 24 * 60 * 60)

        var buckets: [KanjiReviewScheduleBucket] = (0..<7).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: today) ?? today
            let nextDate = calendar.date(byAdding: .day, value: offset + 1, to: today) ?? date.addingTimeInterval(24 * 60 * 60)
            let count = deckRecords.filter { record in
                if offset == 0 {
                    return record.dueDate < nextDate
                }

                return record.dueDate >= date && record.dueDate < nextDate
            }.count

            return KanjiReviewScheduleBucket(
                id: "day-\(offset)",
                title: scheduleTitle(forDayOffset: offset),
                count: count
            )
        }

        let futureCount = deckRecords.filter { $0.dueDate >= futureStart }.count
        buckets.append(KanjiReviewScheduleBucket(id: "future", title: "В будущем", count: futureCount))
        return buckets
    }

    private func scheduleTitle(forDayOffset offset: Int) -> String {
        switch offset {
        case 0:
            return "Сегодня"
        case 1:
            return "Завтра"
        case 2:
            return "Послезавтра"
        default:
            return "Через \(offset) дн."
        }
    }
}
