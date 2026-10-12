import Foundation

nonisolated struct StudyProgressStore: Codable, Sendable {
    private(set) var records: [String: StudyReviewRecord]
    private(set) var firstShownAt: [String: Date] = [:]
    private(set) var reviewLog: [StudyReviewLog] = []
    private(set) var excludedReviewKeys: Set<String> = []
    private(set) var studyDayOffset = 0
    // Rebuilt from persisted data on decode; never encoded as another source of truth.
    private var dailyReviewCounts: [Date: [String: Int]] = [:]
    private var dailyIntroductions: [Date: Set<String>] = [:]

    init(records: [String: StudyReviewRecord]) { self.records = records }
    private enum CodingKeys: String, CodingKey { case records, firstShownAt, studyDayOffset, reviewLog, excludedReviewKeys }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        records = try values.decode([String: StudyReviewRecord].self, forKey: .records)
        firstShownAt = try values.decodeIfPresent([String: Date].self, forKey: .firstShownAt) ?? [:]
        reviewLog = try values.decodeIfPresent([StudyReviewLog].self, forKey: .reviewLog) ?? []
        excludedReviewKeys = try values.decodeIfPresent(Set<String>.self, forKey: .excludedReviewKeys) ?? []
        studyDayOffset = try values.decodeIfPresent(Int.self, forKey: .studyDayOffset) ?? 0
        rebuildDailyIndex()
    }
    private func day(_ date: Date) -> Date { Calendar.current.startOfDay(for: date) }
    private mutating func rebuildDailyIndex() {
        rebuildDailyIndex(checkCancellation: {})
    }
    private mutating func rebuildDailyIndex(checkCancellation: () throws -> Void) rethrows {
        dailyReviewCounts = [:]
        dailyIntroductions = [:]
        for (key, date) in firstShownAt {
            try checkCancellation()
            dailyIntroductions[day(date), default: []].insert(key)
        }
        for entry in reviewLog {
            try checkCancellation()
            guard entry.countsTowardReviewLimit else { continue }
            dailyReviewCounts[day(entry.reviewedAt), default: [:]][entry.deckID, default: 0] += 1
        }
    }
    func studyDate(now: Date = Date()) -> Date {
        Calendar.current.date(byAdding: .day, value: studyDayOffset, to: now) ?? now
    }
    func remainingNewCards(limit: Int, keys: Set<String>, now: Date = Date()) -> Int {
        let today = studyDate(now: now)
        let introduced = dailyIntroductions[day(today), default: []].intersection(keys).count
        return max(0, limit - introduced)
    }
    func remainingDailyCards(limit: Int?, deckID: String, keys: Set<String>, now: Date = Date()) -> Int {
        guard let limit else { return Int.max }
        let today = studyDate(now: now)
        let reviewed = dailyReviewCounts[day(today)]?[deckID] ?? 0
        let introduced = dailyIntroductions[day(today), default: []].intersection(keys).count
        return max(0, limit - reviewed - introduced)
    }
    mutating func markShown(_ key: String, now: Date = Date()) {
        guard firstShownAt[key] == nil, records[key] == nil else { return }
        firstShownAt[key] = studyDate(now: now)
        dailyIntroductions[day(studyDate(now: now)), default: []].insert(key)
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
        let countsTowardReviewLimit = previous.map { consumesReviewLimit($0) } ?? false
        reviewLog.append(StudyReviewLog(id: id, cardID: key, deckID: deckID, grade: rating.ankiGrade,
            reviewedAt: date, elapsedDays: elapsed, previousInterval: previous?.logInterval ?? 0,
            scheduledInterval: next.logInterval,
            stateBefore: previous?.state, stability: next.stability, difficulty: next.difficulty,
            schedulerVersion: StudyScheduler.version,
            countsTowardReviewLimit: countsTowardReviewLimit))
        if countsTowardReviewLimit { dailyReviewCounts[day(date), default: [:]][deckID, default: 0] += 1 }
        markShown(key, now: now)
        records[key] = next
        return id
    }
    func record(for key: String) -> StudyReviewRecord? { records[key] }
    /// Seeds imported progress once. Imported history is persisted for audit and
    /// FSRS continuity, but never participates in the current session's undo stack.
    @discardableResult
    mutating func bootstrap(_ record: StudyReviewRecord, logs: [StudyReviewLog], for key: String) -> Bool {
        bootstrap([BootstrapEntry(key: key, record: record, logs: logs)]) > 0
    }

    struct BootstrapEntry: Sendable {
        let key: String
        let record: StudyReviewRecord
        let logs: [StudyReviewLog]
    }

    /// One UUID set and one index rebuild per import. First occurrence wins;
    /// existing app progress and history order are preserved.
    @discardableResult
    mutating func bootstrap(_ entries: [BootstrapEntry]) -> Int {
        bootstrap(entries, checkCancellation: {})
    }

    @discardableResult
    mutating func bootstrap(_ entries: [BootstrapEntry], checkCancellation: () throws -> Void) rethrows -> Int {
        guard !entries.isEmpty else { return 0 }
        var existing = Set<UUID>()
        for log in reviewLog {
            try checkCancellation()
            existing.insert(log.id)
        }
        var imported = 0
        for entry in entries {
            try checkCancellation()
            guard records[entry.key] == nil else { continue }
            firstShownAt[entry.key] = firstShownAt[entry.key] ?? entry.record.lastReviewedAt
            records[entry.key] = entry.record
            for log in entry.logs {
                try checkCancellation()
                if existing.insert(log.id).inserted { reviewLog.append(log) }
            }
            imported += 1
        }
        if imported > 0 { try rebuildDailyIndex(checkCancellation: checkCancellation) }
        return imported
    }
    func isExcluded(_ key: String) -> Bool { excludedReviewKeys.contains(key) }
    mutating func exclude(_ key: String) { excludedReviewKeys.insert(key) }
    mutating func resetProgress(for keys: Set<String>) {
        guard !keys.isEmpty else { return }
        records = records.filter { !keys.contains($0.key) }
        firstShownAt = firstShownAt.filter { !keys.contains($0.key) }
        reviewLog.removeAll { keys.contains($0.cardID) }
        excludedReviewKeys.subtract(keys)
        rebuildDailyIndex()
    }
    mutating func removeAnkiImportProgress(importID: String) {
        let prefix = "anki:\(importID):"
        records = records.filter { !$0.key.hasPrefix(prefix) }
        firstShownAt = firstShownAt.filter { !$0.key.hasPrefix(prefix) }
        reviewLog.removeAll { $0.cardID.hasPrefix(prefix) }
        excludedReviewKeys = Set(excludedReviewKeys.filter { !$0.hasPrefix(prefix) })
        rebuildDailyIndex()
    }
    mutating func undo(logID: UUID, record: StudyReviewRecord?, key: String) {
        records[key] = record
        if let entry = reviewLog.first(where: { $0.id == logID }), entry.countsTowardReviewLimit {
            dailyReviewCounts[day(entry.reviewedAt), default: [:]][entry.deckID, default: 0] -= 1
        }
        reviewLog.removeAll { $0.id == logID }
    }
    mutating func advanceStudyDay() { studyDayOffset += 1 }
}
