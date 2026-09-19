import Foundation
import CryptoKit
import FSRS
import AnkiImport

/// Converts Anki's scheduling snapshot and revlog into the app-owned FSRS state.
/// The Anki due date remains authoritative for the first post-import appearance;
/// stability/difficulty come from deterministic FSRS-6 history replay.
nonisolated enum AnkiSchedulingMigrator {
    static let version = "anki-replay-fsrs-6"

    static func bootstrap(collection: AnkiCollection, importID: String,
                          optionsByDeck: [Int64: DeckOptions], progress: inout StudyProgressStore) -> Int {
        var imported = 0
        for card in collection.cards {
            let key = "anki:\(importID):card:\(card.id)"
            guard progress.record(for: key) == nil,
                  let migration = migration(for: card, collectionCreationTime: collection.creationTime,
                                            key: key, deckID: "anki:\(importID):deck:\(card.deckID)",
                                            options: optionsByDeck[card.deckID] ?? DeckOptions()) else { continue }
            if progress.bootstrap(migration.record, logs: migration.logs, for: key) { imported += 1 }
        }
        return imported
    }

    private static func migration(for card: AnkiCard, collectionCreationTime: Int64?, key: String,
                                  deckID: String, options: DeckOptions) -> (record: StudyReviewRecord, logs: [StudyReviewLog])? {
        let scheduling = card.scheduling
        let type = Int(scheduling["type", default: 0])
        let reps = Int(scheduling["reps", default: 0])
        let history = (card.reviewHistory ?? []).sorted { $0.id < $1.id }
        guard type != 0 || reps > 0 || !history.isEmpty else { return nil }

        let valid = history.filter { $0.rating != nil && $0.reviewedAt.timeIntervalSince1970 > 0 }
        let fallbackLast = inferredLastReview(scheduling: scheduling, due: dueDate(
            scheduling: scheduling, collectionCreationTime: collectionCreationTime))
        guard let lastReviewedAt = valid.last?.reviewedAt ?? fallbackLast else { return nil }
        let replay = replay(valid, options: options)
        let lastRating = valid.last.flatMap { reviewRating($0.ease) } ?? .good
        let state = reviewState(type: type)
        let due = dueDate(scheduling: scheduling, collectionCreationTime: collectionCreationTime)
            ?? fallbackDue(lastReviewedAt: lastReviewedAt, scheduling: scheduling)
        let interval = intervalDays(scheduling["ivl", default: 0], due: due, lastReview: lastReviewedAt)
        let seed = replay ?? seedMemory(at: lastReviewedAt, rating: lastRating, options: options)
        let record = StudyReviewRecord(
            attempts: max(reps, valid.count), intervalDays: interval, dueDate: due,
            lastRating: lastRating, lastReviewedAt: lastReviewedAt, state: state,
            learningStep: learningStep(scheduling["left", default: 0]),
            lapses: max(Int(scheduling["lapses", default: 0]), seed?.lapses ?? 0),
            stability: max(0.0001, seed?.stability ?? 1), difficulty: min(10, max(1, seed?.difficulty ?? 5)),
            schedulerVersion: version)
        return (record, importedLogs(history, cardKey: key, deckID: deckID))
    }

    private static func replay(_ history: [AnkiReviewLogEntry], options: DeckOptions) -> Card? {
        guard let first = history.first else { return nil }
        let scheduler = FSRS(parameters: parameters(options))
        var card = Card(due: first.reviewedAt)
        for entry in history {
            guard let rating = Rating(rawValue: entry.ease),
                  let result = try? scheduler.next(card: card, now: entry.reviewedAt, grade: rating) else { continue }
            card = result.card
        }
        return card
    }

    private static func seedMemory(at date: Date, rating: ReviewRating, options: DeckOptions) -> Card? {
        let scheduler = FSRS(parameters: parameters(options))
        guard let grade = Rating(rawValue: rating.ankiGrade) else { return nil }
        return try? scheduler.next(card: Card(due: date), now: date, grade: grade).card
    }

    private static func parameters(_ options: DeckOptions) -> FSRSParameters {
        let value = options.validated
        return FSRSParameters(requestRetention: value.desiredRetention, maximumInterval: Double(value.maximumInterval),
            w: FSRSDefaults.defaultWv6, enableFuzz: false, enableShortTerm: true,
            learningSteps: [], relearningSteps: [])
    }

    private static func reviewState(type: Int) -> StudyReviewState {
        switch type { case 1: return .learning; case 3: return .relearning; default: return .review }
    }

    private static func reviewRating(_ ease: Int) -> ReviewRating? {
        switch ease { case 1: return .again; case 2: return .hard; case 3: return .good; case 4: return .easy; default: return nil }
    }

    private static func dueDate(scheduling: [String: Int64], collectionCreationTime: Int64?) -> Date? {
        let type = Int(scheduling["type", default: 0])
        let queue = Int(scheduling["queue", default: Int64(type)])
        var due = scheduling["due", default: 0]
        if scheduling["odid", default: 0] != 0, scheduling["odue", default: 0] != 0 { due = scheduling["odue", default: due] }
        if queue == 1 { return due > 0 ? Date(timeIntervalSince1970: Double(due)) : nil }
        if queue == 2 || queue == 3 || type == 2 || type == 3 {
            guard let creationCollection = collectionCreationTime else { return nil }
            return Date(timeIntervalSince1970: Double(creationCollection)).addingTimeInterval(Double(due) * 86_400)
        }
        return nil
    }

    private static func inferredLastReview(scheduling: [String: Int64], due: Date?) -> Date? {
        let interval = max(0, scheduling["ivl", default: 0])
        guard let due, interval > 0 else { return nil }
        return due.addingTimeInterval(-Double(interval) * 86_400)
    }

    private static func fallbackDue(lastReviewedAt: Date, scheduling: [String: Int64]) -> Date {
        let interval = scheduling["ivl", default: 0]
        if interval < 0 { return lastReviewedAt.addingTimeInterval(Double(-interval)) }
        return lastReviewedAt.addingTimeInterval(Double(max(1, interval)) * 86_400)
    }

    private static func intervalDays(_ interval: Int64, due: Date, lastReview: Date) -> Double {
        if interval > 0 { return Double(interval) }
        return Calendar.current.isDate(due, inSameDayAs: lastReview) ? 0 :
            Double(max(1, Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: lastReview),
                                                           to: Calendar.current.startOfDay(for: due)).day ?? 1))
    }

    private static func learningStep(_ left: Int64) -> Int {
        let remaining = Int(left % 1_000)
        return max(0, remaining - 1)
    }

    private static func importedLogs(_ history: [AnkiReviewLogEntry], cardKey: String, deckID: String) -> [StudyReviewLog] {
        var previousDate: Date?
        return history.map { entry in
            let date = entry.reviewedAt
            let elapsed = previousDate.map { max(0, Calendar.current.dateComponents([.day], from: $0, to: date).day ?? 0) } ?? 0
            previousDate = date
            return StudyReviewLog(id: deterministicID(cardKey: cardKey, revlogID: entry.id), cardID: cardKey,
                deckID: deckID, grade: entry.rating?.rawValue ?? 0, reviewedAt: date, elapsedDays: elapsed,
                previousInterval: Double(entry.previousInterval), scheduledInterval: Double(entry.interval),
                stateBefore: stateBefore(entry.kind), stability: nil, difficulty: nil,
                schedulerVersion: version, countsTowardReviewLimit: false)
        }
    }

    private static func stateBefore(_ kind: AnkiReviewKind?) -> StudyReviewState? {
        switch kind { case .learning: return .learning; case .review, .filtered: return .review
        case .relearning: return .relearning; default: return nil }
    }

    private static func deterministicID(cardKey: String, revlogID: Int64) -> UUID {
        var bytes = Array(SHA256.hash(data: Data("\(cardKey):\(revlogID)".utf8)).prefix(16))
        bytes[6] = (bytes[6] & 0x0f) | 0x50
        bytes[8] = (bytes[8] & 0x3f) | 0x80
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                           bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
    }
}
