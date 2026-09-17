import Foundation

nonisolated struct KanjiReviewStore: Codable, Sendable {
    static let defaultLearningSuccessTarget = 2

    private(set) var records: [String: KanjiReviewRecord]
    private(set) var firstShownAt: [String: Date] = [:]
    private(set) var studyDayOffset = 0

    init(records: [String: KanjiReviewRecord]) { self.records = records }

    private enum CodingKeys: String, CodingKey { case records, firstShownAt, studyDayOffset }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        records = try values.decode([String: KanjiReviewRecord].self, forKey: .records)
        firstShownAt = try values.decodeIfPresent([String: Date].self, forKey: .firstShownAt) ?? [:]
        studyDayOffset = try values.decodeIfPresent(Int.self, forKey: .studyDayOffset) ?? 0
    }

    func studyDate(now: Date = Date()) -> Date {
        Calendar.current.date(byAdding: .day, value: studyDayOffset, to: now) ?? now
    }

    func remainingNewCards(limit: Int, now: Date = Date()) -> Int {
        let today = studyDate(now: now)
        let introduced = firstShownAt.values.filter { Calendar.current.isDate($0, inSameDayAs: today) }.count
        return max(0, limit - introduced)
    }

    mutating func markShown(_ key: String, now: Date = Date()) {
        guard firstShownAt[key] == nil, records[key] == nil else { return }
        firstShownAt[key] = studyDate(now: now)
    }

    func isDue(_ record: KanjiReviewRecord, now: Date = Date()) -> Bool {
        Calendar.current.startOfDay(for: record.dueDate) <= Calendar.current.startOfDay(for: studyDate(now: now))
    }

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
            now: studyDate(now: now)
        )
    }

    func record(for kanji: String) -> KanjiReviewRecord? {
        records[kanji]
    }

    mutating func restore(_ record: KanjiReviewRecord?, for key: String) {
        records[key] = record
    }

    mutating func advanceStudyDay() { studyDayOffset += 1 }
}
