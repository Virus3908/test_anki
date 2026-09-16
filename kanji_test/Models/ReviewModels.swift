import Foundation

struct KanjiReviewStore: Codable {
    static let defaultLearningSuccessTarget = 2

    private(set) var records: [String: KanjiReviewRecord]

    mutating func apply(
        _ rating: ReviewRating,
        to kanji: String,
        learningSuccessTarget: Int = Self.defaultLearningSuccessTarget,
        resetIntervalOnGood: Bool = false,
        now: Date = Date()
    ) {
        records[kanji] = KanjiReviewScheduler.record(
            after: rating,
            existingRecord: records[kanji],
            learningSuccessTarget: learningSuccessTarget,
            resetIntervalOnGood: resetIntervalOnGood,
            now: now
        )
    }

    func record(for kanji: String) -> KanjiReviewRecord? {
        records[kanji]
    }

    mutating func restore(_ record: KanjiReviewRecord?, for key: String) {
        records[key] = record
    }

    mutating func advanceReviewDates(byDays days: Int = 1) {
        let dayCount = max(1, days)
        for key in records.keys {
            guard var record = records[key] else {
                continue
            }

            record.dueDate = Self.date(record.dueDate, addingDays: -dayCount)
            records[key] = record
        }
    }

    private static func date(_ date: Date, addingDays days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: date) ?? date.addingTimeInterval(Double(days) * 24 * 60 * 60)
    }

}
