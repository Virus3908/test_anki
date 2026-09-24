import Foundation

nonisolated struct StudyProgressStore: Codable, Sendable {
    private(set) var records: [String: StudyReviewRecord]
    private(set) var firstShownAt: [String: Date] = [:]
    private(set) var reviewLog: [StudyReviewLog] = []
    private(set) var excludedReviewKeys: Set<String> = []
    private(set) var studyDayOffset = 0

    init(records: [String: StudyReviewRecord]) { self.records = records }
    private enum CodingKeys: String, CodingKey { case records, firstShownAt, studyDayOffset, reviewLog, excludedReviewKeys }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        records = try values.decode([String: StudyReviewRecord].self, forKey: .records)
        firstShownAt = try values.decodeIfPresent([String: Date].self, forKey: .firstShownAt) ?? [:]
        reviewLog = try values.decodeIfPresent([StudyReviewLog].self, forKey: .reviewLog) ?? []
        excludedReviewKeys = try values.decodeIfPresent(Set<String>.self, forKey: .excludedReviewKeys) ?? []
        studyDayOffset = try values.decodeIfPresent(Int.self, forKey: .studyDayOffset) ?? 0
    }
    func studyDate(now: Date = Date()) -> Date {
        Calendar.current.date(byAdding: .day, value: studyDayOffset, to: now) ?? now
    }
    func remainingNewCards(limit: Int, keys: Set<String>, now: Date = Date()) -> Int {
        let today = studyDate(now: now)
        let introduced = firstShownAt.filter { keys.contains($0.key) && Calendar.current.isDate($0.value, inSameDayAs: today) }.count
        return max(0, limit - introduced)
    }
    func remainingDailyCards(limit: Int?, deckID: String, keys: Set<String>, now: Date = Date()) -> Int {
        guard let limit else { return Int.max }
        let today = studyDate(now: now)
        let reviewed = reviewLog.filter {
            $0.deckID == deckID && $0.countsTowardReviewLimit && Calendar.current.isDate($0.reviewedAt, inSameDayAs: today)
        }.count
        let introduced = firstShownAt.filter {
            keys.contains($0.key) && Calendar.current.isDate($0.value, inSameDayAs: today)
        }.count
        return max(0, limit - reviewed - introduced)
    }
    mutating func markShown(_ key: String, now: Date = Date()) {
        guard firstShownAt[key] == nil, records[key] == nil else { return }
        firstShownAt[key] = studyDate(now: now)
    }
    func isDue(_ record: StudyReviewRecord, now: Date = Date()) -> Bool {
        let today = studyDate(now: now)
        if record.state == .review || record.intervalDays >= 1 {
            return Calendar.current.startOfDay(for: record.dueDate) <= Calendar.current.startOfDay(for: today)
        }
        return record.dueDate <= today
    }
    func consumesReviewLimit(_ record: StudyReviewRecord) -> Bool {
        record.state == .review || record.intervalDays >= 1
    }
    @discardableResult
    mutating func apply(_ rating: ReviewRating, to key: String, deckID: String,
                        options: DeckOptions, now: Date = Date()) throws -> UUID {
        let date = studyDate(now: now)
        let previous = records[key]
        let next = try StudyScheduler.record(after: rating, cardID: key, existingRecord: previous, options: options, now: date)
        let id = UUID()
        let elapsed = previous.map { max(0, Calendar.current.dateComponents([.day],
            from: Calendar.current.startOfDay(for: $0.lastReviewedAt), to: Calendar.current.startOfDay(for: date)).day ?? 0) } ?? 0
        reviewLog.append(StudyReviewLog(id: id, cardID: key, deckID: deckID, grade: rating.ankiGrade,
            reviewedAt: date, elapsedDays: elapsed, previousInterval: previous?.logInterval ?? 0,
            scheduledInterval: next.logInterval,
            stateBefore: previous?.state, stability: next.stability, difficulty: next.difficulty,
            schedulerVersion: StudyScheduler.version,
            countsTowardReviewLimit: previous.map { consumesReviewLimit($0) } ?? false))
        markShown(key, now: now)
        records[key] = next
        return id
    }
    func record(for key: String) -> StudyReviewRecord? { records[key] }
    /// Seeds imported progress once. Imported history is persisted for audit and
    /// FSRS continuity, but never participates in the current session's undo stack.
    @discardableResult
    mutating func bootstrap(_ record: StudyReviewRecord, logs: [StudyReviewLog], for key: String) -> Bool {
        guard records[key] == nil else { return false }
        firstShownAt[key] = firstShownAt[key] ?? record.lastReviewedAt
        records[key] = record
        let existing = Set(reviewLog.map(\.id))
        reviewLog.append(contentsOf: logs.filter { !existing.contains($0.id) })
        return true
    }
    func isExcluded(_ key: String) -> Bool { excludedReviewKeys.contains(key) }
    mutating func exclude(_ key: String) { excludedReviewKeys.insert(key) }
    mutating func resetProgress(for keys: Set<String>) {
        guard !keys.isEmpty else { return }
        records = records.filter { !keys.contains($0.key) }
        firstShownAt = firstShownAt.filter { !keys.contains($0.key) }
        reviewLog.removeAll { keys.contains($0.cardID) }
        excludedReviewKeys.subtract(keys)
    }
    mutating func undo(logID: UUID, record: StudyReviewRecord?, key: String) {
        records[key] = record
        reviewLog.removeAll { $0.id == logID }
    }
    mutating func advanceStudyDay() { studyDayOffset += 1 }
}
