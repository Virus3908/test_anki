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

struct KanjiReviewStore: Codable {
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

    mutating func apply(_ rating: ReviewRating, to kanji: String, now: Date = Date()) {
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

        switch rating {
        case .again:
            record.streak = 0
            record.intervalDays = 0
            record.dueDate = now
        case .hard:
            record.streak = max(0, record.streak)
            record.intervalDays = max(0.02, record.intervalDays * 0.5)
            record.dueDate = now.addingTimeInterval(30 * 60)
        case .good:
            record.successes += 1
            record.streak += 1
            if record.intervalDays == 0 {
                record.intervalDays = 1
            } else {
                record.intervalDays = min(record.intervalDays * 2.5, 180)
            }
            record.dueDate = now.addingTimeInterval(record.intervalDays * 24 * 60 * 60)
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
