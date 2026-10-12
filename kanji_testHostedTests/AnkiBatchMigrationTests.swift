import XCTest
@testable import AnkiImport
@testable import kanji_test

/// Executed only by the hosted CI job, including the measurement below.
final class AnkiBatchMigrationTests: XCTestCase {
    private let date = Date(timeIntervalSince1970: 1_700_000_000)

    private func collection(count: Int, historyCount: Int = 3) -> AnkiCollection {
        let cards = (0..<count).map { index in
            let id = Int64(index + 1)
            let history = (0..<historyCount).map { offset in
                AnkiReviewLogEntry(id: 1_700_000_000_000 + Int64(offset) * 86_400_000,
                    cardID: id, updateSequenceNumber: 0, ease: offset % 4 + 1,
                    interval: 2, previousInterval: 1, factor: 2500,
                    answerTimeMilliseconds: 100, type: 1)
            }
            return AnkiCard(id: id, noteID: id, deckID: 40, ordinal: 0,
                scheduling: ["type": 2, "queue": 2, "due": 30, "ivl": 10, "reps": Int64(historyCount)],
                reviewHistory: history)
        }
        return AnkiCollection(decks: [.init(id: 40, name: "Deck")], noteTypes: [], notes: [],
            cards: cards, creationTime: 1_690_000_000)
    }

    private func encoded(_ progress: StudyProgressStore) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try encoder.encode(progress)
    }

    func testBatchMatchesLegacyPerCardInsertionAndRoundTrips() throws {
        let collection = collection(count: 30)
        var batched = StudyProgressStore(records: [:])
        var legacy = StudyProgressStore(records: [:])
        // Existing progress and a pre-existing introduction must win in both paths.
        _ = try batched.apply(.easy, to: "anki:fixture:card:1", deckID: "anki:fixture:deck:40",
            options: DeckOptions(), now: date)
        batched.markShown("anki:fixture:card:2", now: date)
        legacy = batched
        XCTAssertEqual(try AnkiSchedulingMigrator.bootstrapCancellable(collection: collection, importID: "fixture",
            optionsByDeck: [:], progress: &batched), 29)
        // Freeze the old insertion rules rather than comparing two calls to the new batch API.
        for card in collection.cards {
            let single = AnkiCollection(decks: collection.decks, noteTypes: [], notes: [],
                cards: [card], creationTime: collection.creationTime)
            var seed = StudyProgressStore(records: [:])
            _ = AnkiSchedulingMigrator.bootstrap(collection: single, importID: "fixture", optionsByDeck: [:], progress: &seed)
            let key = "anki:fixture:card:\(card.id)"
            guard legacy.record(for: key) == nil, let record = seed.record(for: key) else { continue }
            // JSON fixture models the former append/dedup/rebuild-on-decode implementation.
            var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded(legacy)) as? [String: Any])
            let source = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded(seed)) as? [String: Any])
            var records = try XCTUnwrap(object["records"] as? [String: Any])
            records[key] = (source["records"] as? [String: Any])?[key]
            object["records"] = records
            var shown = (object["firstShownAt"] as? [String: Any]) ?? [:]
            if shown[key] == nil { shown[key] = (source["firstShownAt"] as? [String: Any])?[key] }
            object["firstShownAt"] = shown
            let oldLogs = (object["reviewLog"] as? [[String: Any]]) ?? []
            let ids = Set(oldLogs.compactMap { $0["id"] as? String })
            object["reviewLog"] = oldLogs + ((source["reviewLog"] as? [[String: Any]]) ?? []).filter {
                !ids.contains($0["id"] as? String ?? "")
            }
            legacy = try JSONDecoder().decode(StudyProgressStore.self, from: JSONSerialization.data(withJSONObject: object))
        }
        XCTAssertEqual(try encoded(batched), try encoded(legacy))
        let restored = try JSONDecoder().decode(StudyProgressStore.self, from: encoded(batched))
        XCTAssertEqual(try encoded(restored), try encoded(batched))
        let keys = Set(batched.records.keys)
        for now in [date, date.addingTimeInterval(86_400)] {
            XCTAssertEqual(batched.remainingNewCards(limit: 100, keys: keys, now: now),
                legacy.remainingNewCards(limit: 100, keys: keys, now: now))
            XCTAssertEqual(batched.remainingDailyCards(limit: 100, deckID: "anki:fixture:deck:40", keys: keys, now: now),
                restored.remainingDailyCards(limit: 100, deckID: "anki:fixture:deck:40", keys: keys, now: now))
        }
        let before = try encoded(batched)
        XCTAssertEqual(try AnkiSchedulingMigrator.bootstrapCancellable(collection: collection, importID: "fixture",
            optionsByDeck: [:], progress: &batched), 0)
        XCTAssertEqual(try encoded(batched), before)
    }

    func testThousandsDuplicatesEmptyAndLongHistoriesPreserveLimitsAndIDs() throws {
        let source = collection(count: 2000)
        let duplicate = AnkiCollection(decks: source.decks, noteTypes: [], notes: [],
            cards: source.cards + [source.cards[0]], creationTime: source.creationTime)
        var progress = StudyProgressStore(records: [:])
        XCTAssertEqual(try AnkiSchedulingMigrator.bootstrapCancellable(collection: duplicate, importID: "fixture",
            optionsByDeck: [:], progress: &progress), 2000)
        XCTAssertEqual(progress.reviewLog.count, 6000)
        XCTAssertEqual(Set(progress.reviewLog.map(\.id)).count, 6000)
        XCTAssertTrue(progress.reviewLog.allSatisfy { !$0.countsTowardReviewLimit })
        XCTAssertEqual(progress.remainingDailyCards(limit: 10, deckID: "anki:fixture:deck:40", keys: [], now: date), 10)
        XCTAssertEqual(progress.firstShownAt["anki:fixture:card:1"], date.addingTimeInterval(2 * 86_400))
        let entry = try XCTUnwrap(progress.reviewLog.first)
        let record = try XCTUnwrap(progress.record(for: entry.cardID))
        var store = StudyProgressStore(records: [:])
        XCTAssertEqual(store.bootstrap([.init(key: "one", record: record, logs: [entry, entry]),
                                       .init(key: "one", record: record, logs: [entry]),
                                       .init(key: "two", record: record, logs: [entry])]), 2)
        XCTAssertEqual(store.reviewLog.map(\.id), [entry.id])
        XCTAssertEqual(store.bootstrap([.init(key: "one", record: record, logs: [])]), 0)
        var empty = StudyProgressStore(records: [:])
        XCTAssertEqual(AnkiSchedulingMigrator.bootstrap(collection: collection(count: 3, historyCount: 0), importID: "empty",
            optionsByDeck: [:], progress: &empty), 3, "Reviewed cards with no history retain inferred scheduling")
        var long = StudyProgressStore(records: [:])
        XCTAssertEqual(AnkiSchedulingMigrator.bootstrap(collection: collection(count: 1, historyCount: 1000), importID: "long",
            optionsByDeck: [:], progress: &long), 1)
        XCTAssertEqual(long.reviewLog.count, 1000)
    }

    func testCancelledMigrationDoesNotMutateInput() async throws {
        let source = collection(count: 2000)
        let task = Task.detached {
            withUnsafeCurrentTask { $0?.cancel() }
            var progress = StudyProgressStore(records: [:])
            do {
                _ = try AnkiSchedulingMigrator.bootstrapCancellable(collection: source, importID: "fixture",
                    optionsByDeck: [:], progress: &progress)
                return false
            } catch is CancellationError {
                return progress.records.isEmpty && progress.reviewLog.isEmpty && progress.firstShownAt.isEmpty
            } catch { return false }
        }
        let unchanged = await task.value
        XCTAssertTrue(unchanged)
    }

    func testBatchVisitsAreLinearAndCancellationDuringApplicationIsAtomic() throws {
        let source = collection(count: 1000)
        var seed = StudyProgressStore(records: [:])
        _ = AnkiSchedulingMigrator.bootstrap(collection: source, importID: "fixture", optionsByDeck: [:], progress: &seed)
        let logs = Dictionary(grouping: seed.reviewLog, by: \.cardID)
        let entries = seed.records.keys.sorted().compactMap { key -> StudyProgressStore.BootstrapEntry? in
            guard let record = seed.record(for: key) else { return nil }
            return .init(key: key, record: record, logs: logs[key] ?? [])
        }
        var progress = StudyProgressStore(records: [:])
        var visits = 0
        XCTAssertEqual(progress.bootstrap(entries, checkCancellation: { visits += 1 }), 1000)
        // One visit per card/log during append, then one per introduction/log in the index rebuild.
        XCTAssertEqual(visits, 8000)
        var cancelled = StudyProgressStore(records: [:])
        let before = try encoded(cancelled)
        visits = 0
        XCTAssertThrowsError(try AnkiSchedulingMigrator.bootstrapCancellable(collection: source,
            importID: "fixture", optionsByDeck: [:], progress: &cancelled, checkCancellation: {
                visits += 1
                // 7000 preparation checks + boundary; interrupt the actual batch application.
                if visits == 7500 { throw CancellationError() }
            })) { XCTAssertTrue($0 is CancellationError) }
        XCTAssertEqual(try encoded(cancelled), before)
    }

    func testLargeSyntheticMigrationPerformance() {
        let source = collection(count: 3000, historyCount: 10)
        measure {
            var progress = StudyProgressStore(records: [:])
            XCTAssertEqual(AnkiSchedulingMigrator.bootstrap(collection: source, importID: "performance",
                optionsByDeck: [:], progress: &progress), 3000)
        }
    }
}
