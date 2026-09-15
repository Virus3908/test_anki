import Foundation

enum ReviewRating: String, CaseIterable, Identifiable, Codable {
    case again
    case hard
    case good

    var id: String { rawValue }

    var title: String {
        switch self {
        case .again:
            return "Неправильно"
        case .hard:
            return "Почти"
        case .good:
            return "Правильно"
        }
    }

    var iconName: String {
        switch self {
        case .again:
            return "xmark.circle.fill"
        case .hard:
            return "exclamationmark.circle.fill"
        case .good:
            return "checkmark.circle.fill"
        }
    }
}

struct KanjiReviewRecord: Codable {
    var attempts: Int
    var successes: Int
    var streak: Int
    var intervalDays: Double
    var dueDate: Date
    var lastRating: ReviewRating
    var lastReviewedAt: Date
}

struct KanjiReviewScheduleBucket: Identifiable {
    let id: String
    let title: String
    let count: Int
}

struct KanjiReviewStore: Codable {
    static let defaultLearningSuccessTarget = 2

    private(set) var records: [String: KanjiReviewRecord]

    static func load() -> KanjiReviewStore {
        do {
            let url = try storageURL()
            guard FileManager.default.fileExists(atPath: url.path) else {
                return KanjiReviewStore(records: [:])
            }

            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(KanjiReviewStore.self, from: data)
        } catch {
            assertionFailure("Failed to load review memory: \(error)")
            return KanjiReviewStore(records: [:])
        }
    }

    mutating func apply(
        _ rating: ReviewRating,
        to kanji: String,
        learningSuccessTarget: Int = Self.defaultLearningSuccessTarget,
        resetIntervalOnGood: Bool = false,
        now: Date = Date()
    ) {
        let successTarget = max(1, learningSuccessTarget)
        var record = records[kanji] ?? KanjiReviewRecord(
            attempts: 0,
            successes: 0,
            streak: 0,
            intervalDays: 0,
            dueDate: now,
            lastRating: rating,
            lastReviewedAt: now
        )

        record.attempts += 1
        record.lastRating = rating
        record.lastReviewedAt = now
        let wasLearned = record.successes >= successTarget

        switch rating {
        case .again:
            record.streak = 0
            if wasLearned {
                record.intervalDays = 1
                record.dueDate = Self.nextDay(after: now)
            } else {
                record.intervalDays = 0
                record.dueDate = now
            }
        case .hard:
            record.streak = max(0, record.streak)
            if wasLearned {
                record.intervalDays = 1
                record.dueDate = Self.nextDay(after: now)
            } else {
                record.intervalDays = max(0.02, record.intervalDays * 0.5)
                record.dueDate = now.addingTimeInterval(30 * 60)
            }
        case .good:
            record.successes += 1
            record.streak += 1

            if !wasLearned && record.successes < successTarget {
                record.intervalDays = 0
                record.dueDate = now
            } else if resetIntervalOnGood || record.intervalDays == 0 {
                record.intervalDays = 1
                record.dueDate = Self.nextDay(after: now)
            } else {
                record.intervalDays = min(record.intervalDays * 2.5, 180)
                record.dueDate = now.addingTimeInterval(record.intervalDays * 24 * 60 * 60)
            }
        }

        records[kanji] = record
        save()
    }

    func record(for kanji: String) -> KanjiReviewRecord? {
        records[kanji]
    }

    func orderedCards(_ cards: [KanjiCard], now: Date = Date()) -> [KanjiCard] {
        cards.sorted { left, right in
            let leftDate = records[left.kanji]?.dueDate ?? .distantPast
            let rightDate = records[right.kanji]?.dueDate ?? .distantPast
            let leftDue = leftDate <= now
            let rightDue = rightDate <= now

            if leftDue != rightDue {
                return leftDue
            }

            if leftDate != rightDate {
                return leftDate < rightDate
            }

            return left.kanji < right.kanji
        }
    }

    func learningCards(
        from cards: [KanjiCard],
        newCardLimit: Int,
        learningSuccessTarget: Int = Self.defaultLearningSuccessTarget,
        now: Date = Date()
    ) -> [KanjiCard] {
        dueReviewCards(
            from: cards,
            learningSuccessTarget: learningSuccessTarget,
            now: now
        ) + newLearningCards(
            from: cards,
            newCardLimit: newCardLimit,
            learningSuccessTarget: learningSuccessTarget,
            now: now
        )
    }

    func dueReviewCards(
        from cards: [KanjiCard],
        learningSuccessTarget: Int = Self.defaultLearningSuccessTarget,
        now: Date = Date()
    ) -> [KanjiCard] {
        let successTarget = max(1, learningSuccessTarget)
        return cards
            .filter { card in
                guard let record = records[card.kanji] else {
                    return false
                }

                return record.successes >= successTarget && record.dueDate <= now
            }
            .sorted { left, right in
                let leftDate = records[left.kanji]?.dueDate ?? .distantPast
                let rightDate = records[right.kanji]?.dueDate ?? .distantPast

                if leftDate != rightDate {
                    return leftDate < rightDate
                }

                return left.kanji < right.kanji
            }
    }

    func newLearningCards(
        from cards: [KanjiCard],
        newCardLimit: Int,
        learningSuccessTarget: Int = Self.defaultLearningSuccessTarget,
        now: Date = Date()
    ) -> [KanjiCard] {
        let successTarget = max(1, learningSuccessTarget)
        let inProgressCards = cards
            .filter { card in
                guard let record = records[card.kanji] else {
                    return false
                }

                return record.successes < successTarget && record.dueDate <= now
            }
            .sorted { left, right in
                let leftDate = records[left.kanji]?.dueDate ?? .distantPast
                let rightDate = records[right.kanji]?.dueDate ?? .distantPast

                if leftDate != rightDate {
                    return leftDate < rightDate
                }

                return left.kanji < right.kanji
            }

        let newCards = cards
            .filter { records[$0.kanji] == nil }
            .prefix(max(0, newCardLimit))

        return inProgressCards + Array(newCards)
    }

    func scheduleBuckets(for cards: [KanjiCard], now: Date = Date()) -> [KanjiReviewScheduleBucket] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
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

    mutating func advanceReviewDates(byDays days: Int = 1) {
        let dayCount = max(1, days)
        for key in records.keys {
            guard var record = records[key] else {
                continue
            }

            record.dueDate = Self.date(record.dueDate, addingDays: -dayCount)
            records[key] = record
        }

        save()
    }

    private func save() {
        do {
            let url = try Self.storageURL()
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(self)
            try data.write(to: url, options: .atomic)
        } catch {
            assertionFailure("Failed to save review memory: \(error)")
        }
    }

    private static func nextDay(after date: Date) -> Date {
        Self.date(date, addingDays: 1)
    }

    private static func date(_ date: Date, addingDays days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: date) ?? date.addingTimeInterval(Double(days) * 24 * 60 * 60)
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

    private static func storageURL() throws -> URL {
        let directory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        return directory
            .appendingPathComponent("KanjiTrainer", isDirectory: true)
            .appendingPathComponent("review-memory.json")
    }
}
