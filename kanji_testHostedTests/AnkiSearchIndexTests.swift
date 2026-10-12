import XCTest
@testable import AnkiImport
@testable import kanji_test

@MainActor
final class AnkiSearchIndexTests: XCTestCase {
    private func fixture() throws -> AnkiCollection {
        let json = #"{"decks":[{"id":10,"name":"Japanese::Animals"}],"noteTypes":[{"id":5,"name":"Custom","isCloze":false,"fields":["Front","Back","Extra"],"templates":[{"ordinal":0,"name":"Forward","question":"{{Front}}","answer":"{{Back}}"},{"ordinal":1,"name":"Reverse","question":"{{Back}}","answer":"{{Front}}"}],"css":"body{color:red}"}],"notes":[{"id":6,"guid":"guid","noteTypeID":5,"fields":["<b>猫</b>","cat","пользовательское значение"],"tags":["animal"]}],"cards":[{"id":7,"noteID":6,"deckID":10,"ordinal":0,"scheduling":{}},{"id":8,"noteID":6,"deckID":10,"ordinal":1,"scheduling":{}}],"media":[],"warnings":[]}"#
        return try JSONDecoder().decode(AnkiCollection.self, from: Data(json.utf8))
    }

    func testFieldsTagsDeckTypesReverseAndStableIDs() throws {
        var collection = try fixture()
        _ = collection.prepareNativeFields()
        let records = try AnkiSearchRecord.records(collection: collection, importID: "fixture", filename: "test.apkg")
        let index = CardSearchIndex(records: records)
        for query in ["猫", "cat", "пользовательское значение", "animal", "Japanese::Animals", "Custom"] {
            XCTAssertEqual(index.search(query).count, 2, query)
        }
        XCTAssertEqual(index.search("reverse").map(\.id), ["fixture:card:8"])
        XCTAssertEqual(index.search("猫 animal").map(\.id), ["fixture:card:7", "fixture:card:8"])
        XCTAssertEqual(records[0].displayTitle(using: .defaults(fieldCount: 3)), "猫")
        let encoded = String(decoding: try JSONEncoder().encode(records), as: UTF8.self)
        XCTAssertFalse(encoded.contains("scheduling"))
        XCTAssertFalse(encoded.contains("question"))
        XCTAssertFalse(encoded.contains("css"))
    }

    func testOldImportSavedIndexCorruptionVersionRebuildAndDeletion() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let source = root.appendingPathComponent("collection.json")
        let original = try JSONEncoder().encode(fixture())
        try original.write(to: source)
        let summary = AnkiImportSummary(id: "fixture", directory: UUID().uuidString, filename: "test.apkg",
            importedAt: Date(), decks: [], cardCount: 2, noteCount: 1, mediaCount: 0, warnings: [])
        let cache = AnkiSearchIndexRepository(root: root.appendingPathComponent("index"))
        let first = try await cache.records(for: summary, sourceURL: source)
        XCTAssertEqual(first.count, 2)
        XCTAssertEqual(try Data(contentsOf: source), original, "Indexing must not rewrite source")
        try Data("unreadable source".utf8).write(to: source)
        let saved = try await cache.records(for: summary, sourceURL: source)
        XCTAssertEqual(saved.map(\.id), first.map(\.id), "Saved index must avoid decoding source")
        try original.write(to: source)
        let indexFile = root.appendingPathComponent("index/\(summary.directory).json")
        for data in [Data("broken".utf8), Data(#"{"version":999,"importID":"fixture","records":[]}"#.utf8),
                     Data(#"{"version":1,"importID":"fixture","records":[]}"#.utf8)] {
            try data.write(to: indexFile)
            let rebuilt = try await cache.records(for: summary, sourceURL: source)
            XCTAssertEqual(rebuilt.map(\.id), first.map(\.id))
        }
        try await cache.remove(summary)
        XCTAssertFalse(FileManager.default.fileExists(atPath: indexFile.path))
        XCTAssertEqual(try Data(contentsOf: source), original)
    }

    func testSearchDoesNotDecodeCollectionsUntilOpeningSelectedHit() async throws {
        let collection = try fixture()
        let repository = SearchTestLibrary(collection: collection)
        let library = AnkiLibraryViewModel(repository: repository)
        let first = try await library.recordsForSearch()
        let reopened = try await library.recordsForSearch()
        XCTAssertEqual(first.map(\.id), reopened.map(\.id))
        let initialLoads = await repository.collectionLoads
        XCTAssertEqual(initialLoads, 0)
        let hit = try XCTUnwrap(first.first)
        let card = try await library.cardForSearchResult(hit, session: AnkiSearchPreviewSession())
        XCTAssertEqual(card.id, hit.id)
        XCTAssertEqual(card.reviewKey, "anki:fixture:card:7")
        XCTAssertEqual(card.noteType.css, "body{color:red}")
        XCTAssertEqual(card.note.fields.last, "пользовательское значение")
        let openedLoads = await repository.collectionLoads
        XCTAssertEqual(openedLoads, 1)
    }

    func testUnwritableCacheStillReturnsRecordsAndSourceFailuresPropagate() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let source = root.appendingPathComponent("collection.json")
        let bytes = try JSONEncoder().encode(fixture())
        try bytes.write(to: source)
        let blocked = root.appendingPathComponent("blocked")
        try Data("a file cannot be an index directory".utf8).write(to: blocked)
        let cache = AnkiSearchIndexRepository(root: blocked)
        let summary = AnkiImportSummary(id: "fixture", directory: UUID().uuidString, filename: "test.apkg",
            importedAt: Date(timeIntervalSince1970: 0), decks: [], cardCount: 2, noteCount: 1, mediaCount: 0, warnings: [])
        for _ in 0..<2 {
            let records = try await cache.records(for: summary, sourceURL: source)
            XCTAssertEqual(records.count, 2)
            XCTAssertEqual(try Data(contentsOf: source), bytes)
        }
        try Data("broken source".utf8).write(to: source)
        do { _ = try await cache.records(for: summary, sourceURL: source); XCTFail("Source failure must propagate") }
        catch is DecodingError { }
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await cache.records(for: summary, sourceURL: source)
        }
        do { _ = try await task.value; XCTFail("Cancellation must propagate") }
        catch is CancellationError { }
        XCTAssertEqual(try Data(contentsOf: source), Data("broken source".utf8))
    }

    func testSingleActiveCollectionLifetimeAndSwitchingImports() async throws {
        let repository = FollowupAnkiLibrary(content: try fixture(), ids: ["A", "B"])
        let library = AnkiLibraryViewModel(repository: repository)
        let records = try await library.recordsForSearch()
        let a = records.filter { $0.importID == "A" }
        let b = try XCTUnwrap(records.first { $0.importID == "B" })
        let session = AnkiSearchPreviewSession()
        for record in [a[0], a[1], a[0]] {
            let card = try await library.cardForSearchResult(record, session: session)
            XCTAssertEqual(card.reviewKey, "anki:\(record.id)")
            XCTAssertEqual(card.note.fields.last, "пользовательское значение")
            XCTAssertEqual(card.noteType.css, "body{color:red}")
            XCTAssertEqual(card.noteType.templates[1].question, "{{Back}}")
        }
        var loads = await repository.collectionLoads
        XCTAssertEqual(loads, ["A": 1])
        _ = try await library.cardForSearchResult(b, session: session)
        _ = try await library.cardForSearchResult(a[0], session: session)
        loads = await repository.collectionLoads
        XCTAssertEqual(loads, ["A": 2, "B": 1])
        session.close()
        XCTAssertNil(session.importID)
        _ = try await library.cardForSearchResult(a[1], session: session)
        loads = await repository.collectionLoads
        XCTAssertEqual(loads["A"], 3)
        // A disappeared import can never resolve a retained search hit.
        library.imports.removeAll { $0.id == "A" }
        do { _ = try await library.cardForSearchResult(a[0], session: session); XCTFail("Deleted import") }
        catch { XCTAssertNil(session.importID) }
    }

    func testPartialSearchRetryKeepsBuiltInResultsAndOpeningErrorsLocal() async throws {
        let repository = FollowupAnkiLibrary(content: try fixture(), ids: ["A", "B", "C"])
        await repository.fail("B")
        let library = AnkiLibraryViewModel(repository: repository)
        let records = try await library.recordsForSearch()
        XCTAssertEqual(records.map(\.importID), ["A", "A", "C", "C"])
        XCTAssertEqual(library.searchUnavailableImports.map(\.id), ["B"])
        let app = StudyAppViewModel()
        let model = CardSearchViewModel(scope: .all, translationState: app.translationState, ankiModel: library)
        await model.prepare()
        await model.updateResults(for: "cat")
        XCTAssertNil(model.loadError)
        XCTAssertEqual(model.unavailableAnkiImports.map(\.id), ["B"])
        XCTAssertFalse(model.wordResults.isEmpty)
        let total = model.totalFound
        let ids = model.ankiResults.map(\.id)
        await repository.fail("A")
        let failed = await model.openAnkiResult(records[0])
        XCTAssertNil(failed)
        XCTAssertNotNil(model.openingError)
        XCTAssertNil(model.loadError)
        XCTAssertEqual(model.ankiResults.map(\.id), ids)
        XCTAssertEqual(model.totalFound, total)
        let success = await model.openAnkiResult(records[2])
        XCTAssertNotNil(success)
        XCTAssertNil(model.openingError)
        model.closeAnkiPreview()
        await repository.recover("A")
        let reopened = await model.openAnkiResult(records[0])
        XCTAssertNotNil(reopened)
        await repository.recover("B")
        await model.retryAnkiSearch()
        XCTAssertTrue(model.unavailableAnkiImports.isEmpty)
        XCTAssertEqual(model.ankiResults.map(\.importID), ["A", "A", "B", "B", "C", "C"])
        await model.retryAnkiSearch()
        XCTAssertEqual(Set(model.ankiResults.map(\.id)).count, 6)
        let gate = FollowupGate()
        await repository.blockSearch("A", gate: gate)
        let retry = Task { await model.retryAnkiSearch() }
        await gate.entered()
        model.queryChanged(to: "reverse")
        await gate.release()
        await retry.value
        XCTAssertEqual(model.ankiResults.map(\.cardID), [8, 8, 8], "Retry must use the latest query")
        let deletions = await repository.deletions
        XCTAssertTrue(deletions.isEmpty)
    }

    func testCloseAndSupersededOpenSuppressErrorsAndCancelCollectionRead() async throws {
        let repository = FollowupAnkiLibrary(content: try fixture(), ids: ["A", "B"])
        let library = AnkiLibraryViewModel(repository: repository)
        let records = try await library.recordsForSearch()
        let app = StudyAppViewModel()
        let model = CardSearchViewModel(scope: .all, translationState: app.translationState, ankiModel: library)
        let gate = FollowupGate()
        await repository.blockCollection("A", gate: gate)
        let old = Task { await model.openAnkiResult(records[0]) }
        await gate.entered()
        let next = await model.openAnkiResult(records[2])
        XCTAssertNotNil(next)
        await gate.release()
        let stale = await old.value
        XCTAssertNil(stale)
        XCTAssertNil(model.openingError)
        let cancellations = await repository.cancelledReads
        XCTAssertEqual(cancellations, 1)
        let closeGate = FollowupGate()
        await repository.blockCollection("A", gate: closeGate)
        let closing = Task { await model.openAnkiResult(records[0]) }
        await closeGate.entered()
        model.close()
        await closeGate.release()
        let closed = await closing.value
        XCTAssertNil(closed)
        XCTAssertNil(model.openingError)
    }

    func testDeckCloseCancelsBuilderAndFastSwitchNeverPublishesStaleCards() async throws {
        let content = try fixture()
        let repository = FollowupAnkiLibrary(content: content, ids: ["A", "B"])
        let gate = FollowupGate()
        let library = AnkiLibraryViewModel(repository: repository, deckCardBuilder: { collection, media, deck in
            if deck.importID == "A" { try await gate.wait() }
            return try AnkiCollectionLookup.deckCards(collection: collection, media: media, deck: deck)
        })
        _ = try await library.recordsForSearch()
        let a = AnkiDeckReference(importID: "A", sourceDeckID: 10, title: "A", cardCount: 2)
        let b = AnkiDeckReference(importID: "B", sourceDeckID: 10, title: "B", cardCount: 2)
        let old = Task { await library.openDeck(a) }
        await gate.entered()
        await library.openDeck(b)
        XCTAssertEqual(library.previewDeck, b)
        XCTAssertEqual(library.previewCards.map(\.card.id), content.cards.map(\.id))
        await gate.release()
        await old.value
        XCTAssertEqual(library.previewCards.map(\.importID), ["B", "B"])
        XCTAssertNil(library.loadError)
        let cancelled = await gate.wasCancelled
        XCTAssertTrue(cancelled)
        library.closeDeck()
        XCTAssertTrue(library.previewCards.isEmpty)
        XCTAssertNil(library.previewDeck)
        await library.openDeck(b)
        XCTAssertEqual(library.previewCards.count, 2)
    }

    func testDeletionInvalidatesSessionAndCloseCancelsDeckRead() async throws {
        let repository = FollowupAnkiLibrary(content: try fixture(), ids: ["A"])
        let library = AnkiLibraryViewModel(repository: repository)
        let records = try await library.recordsForSearch()
        let cache = AnkiSearchPreviewSession()
        _ = try await library.cardForSearchResult(records[0], session: cache)
        let suite = "AnkiDeletion-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let session = TrainingSessionViewModel(repository: FollowupReviews(), catalog: StudyCardCatalog(),
            settings: StudyPreferences(defaults: defaults, errors: StorageStatus()), errors: StorageStatus())
        try await session.loadProgress()
        let deck = try XCTUnwrap(library.decks.first)
        let removed = await library.deleteImport(deck, trainingSession: session)
        XCTAssertTrue(removed)
        XCTAssertNil(cache.importID)
        do { _ = try await library.cardForSearchResult(records[1], session: cache); XCTFail("Deleted import") }
        catch { }

        let other = FollowupAnkiLibrary(content: try fixture(), ids: ["A"])
        let model = AnkiLibraryViewModel(repository: other)
        _ = try await model.recordsForSearch()
        let gate = FollowupGate()
        await other.blockCollection("A", gate: gate)
        let opening = Task { await model.openDeck(deck) }
        await gate.entered()
        model.closeDeck()
        await gate.release()
        await opening.value
        XCTAssertNil(model.previewDeck)
        XCTAssertTrue(model.previewCards.isEmpty)
        XCTAssertNil(model.loadError)
        let cancelled = await other.cancelledReads
        XCTAssertEqual(cancelled, 1)
        await model.openDeck(deck)
        XCTAssertEqual(model.previewCards.count, 2)
    }

    func testCancelledSearchStopsBeforeOtherImports() async throws {
        let repository = FollowupAnkiLibrary(content: try fixture(), ids: ["A", "B", "C"])
        let library = AnkiLibraryViewModel(repository: repository)
        let gate = FollowupGate()
        await repository.blockSearch("A", gate: gate)
        let search = Task { try await library.recordsForSearch() }
        await gate.entered()
        search.cancel()
        await gate.release()
        do { _ = try await search.value; XCTFail("Cancelled search") }
        catch is CancellationError { }
        let reads = await repository.searchReads
        XCTAssertEqual(reads, ["A"])
        XCTAssertTrue(library.searchUnavailableImports.isEmpty)
    }

    func testClozeAndCacheByteLimit() async throws {
        var collection = try fixture()
        let type = collection.noteTypes[0]
        let cloze = AnkiNoteType(id: type.id, name: "Cloze", isCloze: true, fields: type.fields,
            templates: type.templates, css: type.css)
        collection = AnkiCollection(decks: collection.decks, noteTypes: [cloze], notes: collection.notes, cards: collection.cards)
        let records = try AnkiSearchRecord.records(collection: collection, importID: "fixture", filename: "test.apkg")
        XCTAssertEqual(CardSearchIndex(records: records).search("пропуск 2").map(\.cardID), [8])
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let cache = AnkiSearchIndexRepository(root: root, byteLimit: 1)
        let summary = AnkiImportSummary(id: "fixture", directory: UUID().uuidString, filename: "test.apkg",
            importedAt: Date(), decks: [], cardCount: 2, noteCount: 1, mediaCount: 0, warnings: [])
        try await cache.save(records, for: summary)
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.path))
    }
}

private actor SearchTestLibrary: AnkiLibraryPersisting {
    let content: AnkiCollection
    private(set) var collectionLoads = 0
    let summary: AnkiImportSummary
    init(collection: AnkiCollection) {
        content = collection
        summary = AnkiImportSummary(id: "fixture", directory: UUID().uuidString, filename: "test.apkg",
            importedAt: Date(), decks: collection.decks, cardCount: collection.cards.count,
            noteCount: collection.notes.count, mediaCount: 0, warnings: [], deckCardCounts: ["10": 2])
    }
    func load() async throws -> [AnkiImportSummary] { [summary] }
    func hasRecoverableBackup() async -> Bool { false }
    func restoreBackup() async throws -> [AnkiImportSummary] { [summary] }
    func importPackage(_ url: URL) async throws -> AnkiImportResult { AnkiImportResult(summary: summary, alreadyImported: true) }
    func deleteImport(id: String) async throws { }
    func markSchedulingMigration(importID: String, version: String) async throws { }
    func collection(_ summary: AnkiImportSummary) async throws -> AnkiCollection { collectionLoads += 1; return content }
    func mediaDirectory(_ summary: AnkiImportSummary) async throws -> URL { FileManager.default.temporaryDirectory }
    func searchRecords(_ summary: AnkiImportSummary) async throws -> [AnkiSearchRecord] {
        try AnkiSearchRecord.records(collection: content, importID: summary.id, filename: summary.filename)
    }
}

actor FollowupGate {
    private var started = false
    private var released = false
    private var waiting: CheckedContinuation<Void, Never>?
    private var observers: [CheckedContinuation<Void, Never>] = []
    private(set) var wasCancelled = false
    func wait() async throws {
        started = true
        observers.forEach { $0.resume() }; observers = []
        if !released { await withCheckedContinuation { waiting = $0 } }
        if Task.isCancelled { wasCancelled = true }
        try Task.checkCancellation()
    }
    func entered() async {
        if !started { await withCheckedContinuation { observers.append($0) } }
    }
    func release() { released = true; waiting?.resume(); waiting = nil }
}

private actor FollowupAnkiLibrary: AnkiLibraryPersisting {
    let content: AnkiCollection
    private var summaries: [AnkiImportSummary]
    private var failures = Set<String>()
    private var gates: [String: FollowupGate] = [:]
    private var searchGates: [String: FollowupGate] = [:]
    private(set) var searchReads: [String] = []
    private(set) var collectionLoads: [String: Int] = [:]
    private(set) var cancelledReads = 0
    private(set) var deletions: [String] = []
    init(content: AnkiCollection, ids: [String]) {
        self.content = content
        summaries = ids.map { AnkiImportSummary(id: $0, directory: UUID().uuidString, filename: "test.apkg",
            importedAt: Date(timeIntervalSince1970: 0), decks: content.decks, cardCount: content.cards.count,
            noteCount: content.notes.count, mediaCount: 0, warnings: [], deckCardCounts: ["10": 2]) }
    }
    func fail(_ id: String) { failures.insert(id) }
    func recover(_ id: String) { failures.remove(id) }
    func blockCollection(_ id: String, gate: FollowupGate) { gates[id] = gate }
    func blockSearch(_ id: String, gate: FollowupGate) { searchGates[id] = gate }
    func load() async throws -> [AnkiImportSummary] { summaries }
    func hasRecoverableBackup() async -> Bool { false }
    func restoreBackup() async throws -> [AnkiImportSummary] { summaries }
    func importPackage(_ url: URL) async throws -> AnkiImportResult { throw CocoaError(.fileReadNoSuchFile) }
    func deleteImport(id: String) async throws { deletions.append(id); summaries.removeAll { $0.id == id } }
    func markSchedulingMigration(importID: String, version: String) async throws { }
    func collection(_ summary: AnkiImportSummary) async throws -> AnkiCollection {
        collectionLoads[summary.id, default: 0] += 1
        if let gate = gates.removeValue(forKey: summary.id) {
            do { try await gate.wait() }
            catch is CancellationError { cancelledReads += 1; throw CancellationError() }
        }
        if failures.contains(summary.id) { throw CocoaError(.fileReadCorruptFile) }
        try Task.checkCancellation()
        return content
    }
    func mediaDirectory(_ summary: AnkiImportSummary) async throws -> URL { FileManager.default.temporaryDirectory }
    func searchRecords(_ summary: AnkiImportSummary) async throws -> [AnkiSearchRecord] {
        searchReads.append(summary.id)
        if let gate = searchGates.removeValue(forKey: summary.id) { try await gate.wait() }
        try Task.checkCancellation()
        if failures.contains(summary.id) { throw CocoaError(.fileReadCorruptFile) }
        return try AnkiSearchRecord.records(collection: content, importID: summary.id, filename: summary.filename)
    }
}

@MainActor private final class FollowupReviews: ReviewPersisting {
    var progress = StudyProgressStore(records: [:])
    func load() async throws -> StudyProgressStore { progress }
    func save(_ value: StudyProgressStore) async throws { progress = value }
    func hasRecoverableBackup() async -> Bool { false }
    func restoreBackup() async throws -> StudyProgressStore { progress }
}
