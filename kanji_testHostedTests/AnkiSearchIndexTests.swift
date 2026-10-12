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
        for data in [Data("broken".utf8), Data(#"{"version":999,"importID":"fixture","records":[]}"#.utf8)] {
            try data.write(to: indexFile)
            let rebuilt = try await cache.records(for: summary, sourceURL: source)
            XCTAssertEqual(rebuilt.map(\.id), first.map(\.id))
        }
        try await cache.remove(summary)
        XCTAssertFalse(FileManager.default.fileExists(atPath: indexFile.path))
        XCTAssertEqual(try Data(contentsOf: source), original)
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
