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

enum KanjiReviewState: String, Codable {
    case learning
    case review
    case relearning
}

struct KanjiReviewRecord: Codable {
    var attempts: Int
    var successes: Int
    var streak: Int
    var intervalDays: Double
    var dueDate: Date
    var lastRating: ReviewRating
    var lastReviewedAt: Date
    var state: KanjiReviewState
    var learningStep: Int
    var easeFactor: Double
    var lapses: Int

    init(
        attempts: Int,
        successes: Int,
        streak: Int,
        intervalDays: Double,
        dueDate: Date,
        lastRating: ReviewRating,
        lastReviewedAt: Date,
        state: KanjiReviewState = .learning,
        learningStep: Int = 0,
        easeFactor: Double = 2.5,
        lapses: Int = 0
    ) {
        self.attempts = attempts
        self.successes = successes
        self.streak = streak
        self.intervalDays = intervalDays
        self.dueDate = dueDate
        self.lastRating = lastRating
        self.lastReviewedAt = lastReviewedAt
        self.state = state
        self.learningStep = learningStep
        self.easeFactor = easeFactor
        self.lapses = lapses
    }

    enum CodingKeys: String, CodingKey {
        case attempts
        case successes
        case streak
        case intervalDays
        case dueDate
        case lastRating
        case lastReviewedAt
        case state
        case learningStep
        case easeFactor
        case lapses
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        attempts = try container.decodeIfPresent(Int.self, forKey: .attempts) ?? 0
        successes = try container.decodeIfPresent(Int.self, forKey: .successes) ?? 0
        streak = try container.decodeIfPresent(Int.self, forKey: .streak) ?? 0
        intervalDays = try container.decodeIfPresent(Double.self, forKey: .intervalDays) ?? 0
        dueDate = try container.decodeIfPresent(Date.self, forKey: .dueDate) ?? Date()
        lastRating = try container.decodeIfPresent(ReviewRating.self, forKey: .lastRating) ?? .again
        lastReviewedAt = try container.decodeIfPresent(Date.self, forKey: .lastReviewedAt) ?? Date()
        learningStep = try container.decodeIfPresent(Int.self, forKey: .learningStep) ?? min(successes, KanjiReviewStore.defaultLearningSuccessTarget)
        easeFactor = max(1.3, try container.decodeIfPresent(Double.self, forKey: .easeFactor) ?? 2.5)
        lapses = try container.decodeIfPresent(Int.self, forKey: .lapses) ?? 0

        if let decodedState = try container.decodeIfPresent(KanjiReviewState.self, forKey: .state) {
            state = decodedState
        } else {
            state = successes >= KanjiReviewStore.defaultLearningSuccessTarget ? .review : .learning
        }
    }
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
        if record.successes < successTarget, record.state == .review {
            record.state = .learning
        }

        switch rating {
        case .again:
            record.streak = 0
            if record.state == .review {
                record.state = .relearning
                record.lapses += 1
                record.learningStep = 0
                record.easeFactor = max(1.3, record.easeFactor - 0.2)
                record.intervalDays = max(1, min(record.intervalDays, 1))
                record.dueDate = now
            } else {
                record.state = .learning
                record.learningStep = 0
                record.intervalDays = 0
                record.dueDate = now
            }
        case .hard:
            record.streak = 0
            record.easeFactor = max(1.3, record.easeFactor - 0.15)
            if record.state == .review {
                let nextInterval = max(1, min(record.intervalDays * 1.2, 180))
                record.intervalDays = nextInterval
                record.dueDate = Self.date(now, addingDays: Int(ceil(nextInterval)))
            } else {
                record.learningStep = max(0, record.learningStep - 1)
                record.intervalDays = 0
                record.dueDate = now
            }
        case .good:
            record.successes += 1
            record.streak += 1

            switch record.state {
            case .learning:
                record.learningStep += 1
                if record.learningStep >= successTarget {
                    record.state = .review
                    record.intervalDays = 1
                    record.dueDate = Self.nextDay(after: now)
                } else {
                    record.intervalDays = 0
                    record.dueDate = now
                }
            case .relearning:
                record.learningStep += 1
                let relearningTarget = 1
                if record.learningStep >= relearningTarget {
                    record.state = .review
                    record.intervalDays = 1
                    record.dueDate = Self.nextDay(after: now)
                } else {
                    record.intervalDays = 0
                    record.dueDate = now
                }
            case .review:
                if resetIntervalOnGood || record.intervalDays == 0 {
                    record.intervalDays = 1
                } else {
                    record.intervalDays = min(max(1, record.intervalDays * record.easeFactor), 180)
                }
                record.dueDate = Self.date(now, addingDays: Int(ceil(record.intervalDays)))
            }
        }

        records[kanji] = record
        save()
    }

    func record(for kanji: String) -> KanjiReviewRecord? {
        records[kanji]
    }

    mutating func restore(_ record: KanjiReviewRecord?, for key: String) {
        records[key] = record
        save()
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

    func dueReviewItems<Item>(
        from items: [Item],
        key: (Item) -> String,
        learningSuccessTarget: Int = Self.defaultLearningSuccessTarget,
        now: Date = Date()
    ) -> [Item] {
        let successTarget = max(1, learningSuccessTarget)
        return items
            .filter { item in
                guard let record = records[key(item)] else {
                    return false
                }

                return record.state == .review && record.successes >= successTarget && record.dueDate <= now
            }
            .sorted { left, right in
                let leftDate = records[key(left)]?.dueDate ?? .distantPast
                let rightDate = records[key(right)]?.dueDate ?? .distantPast

                if leftDate != rightDate {
                    return leftDate < rightDate
                }

                return key(left) < key(right)
            }
    }

    func newLearningItems<Item>(
        from items: [Item],
        key: (Item) -> String,
        newCardLimit: Int,
        now: Date = Date()
    ) -> [Item] {
        let inProgressItems = items
            .filter { item in
                guard let record = records[key(item)] else {
                    return false
                }

                return record.state != .review && record.dueDate <= now
            }
            .sorted { left, right in
                let leftDate = records[key(left)]?.dueDate ?? .distantPast
                let rightDate = records[key(right)]?.dueDate ?? .distantPast

                if leftDate != rightDate {
                    return leftDate < rightDate
                }

                return key(left) < key(right)
            }

        let newItems = items
            .filter { records[key($0)] == nil }
            .prefix(max(0, newCardLimit))

        return inProgressItems + Array(newItems)
    }

    func dueReviewCards(
        from cards: [KanjiCard],
        learningSuccessTarget: Int = Self.defaultLearningSuccessTarget,
        now: Date = Date()
    ) -> [KanjiCard] {
        dueReviewItems(
            from: cards,
            key: \.kanji,
            learningSuccessTarget: learningSuccessTarget,
            now: now
        )
    }

    func newLearningCards(
        from cards: [KanjiCard],
        newCardLimit: Int,
        learningSuccessTarget: Int = Self.defaultLearningSuccessTarget,
        now: Date = Date()
    ) -> [KanjiCard] {
        newLearningItems(
            from: cards,
            key: \.kanji,
            newCardLimit: newCardLimit,
            now: now
        )
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
