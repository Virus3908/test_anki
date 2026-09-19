import XCTest
import SQLite3
import ZIPFoundation
import libzstd
import CryptoKit
@testable import AnkiImport

final class AnkiImportTests: XCTestCase {
    func testLegacyPackagePreservesFieldsCardsAndMedia() throws {
        try withFixture { directory in
            let source = try package(in: directory)
            let output = directory.appendingPathComponent("output")
            let result = try AnkiPackageParser.extract(from: source, to: output)
            XCTAssertEqual(result.notes[0].fields, ["猫<img src=\"猫.png\">", "cat[sound:voice.mp3]", ""])
            XCTAssertEqual(result.notes[0].tags, ["animal", "日本語"])
            XCTAssertEqual(result.cards.count, 2)
            XCTAssertEqual(result.cards[1].ordinal, 1)
            XCTAssertEqual(result.cards[0].scheduling["reps"], 7)
            XCTAssertEqual(result.decks[0].name, "Japanese::Animals")
            XCTAssertEqual(result.media.count, 2)
            XCTAssertEqual(try Data(contentsOf: output.appendingPathComponent("media/voice.mp3")), Data("audio".utf8))
            XCTAssertTrue(FileManager.default.fileExists(atPath: output.appendingPathComponent("collection.sqlite").path))
            let loaded = try JSONDecoder().decode(AnkiCollection.self, from: Data(contentsOf: output.appendingPathComponent("collection.json")))
            XCTAssertEqual(loaded.noteTypes[0].fields, ["Front", "Back", "Extra"])
        }
    }

    func testModernPackageAndNormalizedDatabase() throws {
        try withFixture { directory in
            // An exact output-buffer boundary must not be mistaken for a truncated next frame.
            let source = try package(in: directory, modern: true, image: Data(repeating: 42, count: 128 * 1024))
            let result = try AnkiPackageParser.extract(from: source, to: directory.appendingPathComponent("output"))
            XCTAssertEqual(result.noteTypes[0].css, ".card { color: red; }")
            XCTAssertEqual(result.noteTypes[0].templates[1].question, "{{Back}}")
            XCTAssertEqual(result.decks[0].name, "Japanese::Animals")
            XCTAssertEqual(result.media.map(\.name), ["voice.mp3", "猫.png"])
            XCTAssertEqual(result.media.last?.size, 128 * 1024)
        }
    }

    func testModernWALDatabaseHeaderIsNormalizedBeforeOpen() throws {
        try withFixture { directory in
            // Modern Anki exports leave the SQLite header in WAL mode after the
            // final checkpoint (write/read version 2, no -wal sidecar); a
            // SQLITE_OPEN_READONLY connection cannot open such a database.
            let source = try package(in: directory, modern: true, wal: true)
            let output = directory.appendingPathComponent("output")
            let result = try AnkiPackageParser.extract(from: source, to: output)
            XCTAssertEqual(result.cards.count, 2)
            XCTAssertEqual(result.cards[0].scheduling["reps"], 7)
            let handle = try FileHandle(forReadingFrom: output.appendingPathComponent("collection.sqlite"))
            defer { try? handle.close() }
            let header = try handle.read(upToCount: 20) ?? Data()
            XCTAssertEqual(header.count, 20)
            XCTAssertEqual([header[18], header[19]], [1, 1])
        }
    }

    func testLegacy21PreferredOverCompatibilityDatabase() throws {
        try withFixture { directory in
            let source = try package(in: directory, databaseName: "collection.anki21")
            let archive = try Archive(url: source, accessMode: .update)
            try add("collection.anki2", data: Data("placeholder".utf8), to: archive)
            XCTAssertEqual(try AnkiPackageParser.extract(from: source, to: directory.appendingPathComponent("output")).cards.count, 2)
        }
    }

    func testUnsafeMediaAndMissingMediaRollBack() throws {
        for name in ["../outside", "/absolute", "a\\b", "a:b", ".."] {
            try withFixture { directory in
                let source = try package(in: directory, mediaName: name)
                let output = directory.appendingPathComponent("output")
                XCTAssertThrowsError(try AnkiPackageParser.extract(from: source, to: output))
                XCTAssertFalse(FileManager.default.fileExists(atPath: output.path))
            }
        }
        try withFixture { directory in
            let source = try package(in: directory, omitMedia: true)
            XCTAssertThrowsError(try AnkiPackageParser.extract(from: source, to: directory.appendingPathComponent("output")))
        }
    }

    func testMediaNameCollisionRejected() throws {
        try withFixture { directory in
            let source = try package(in: directory, mediaName: "VOICE.mp3")
            XCTAssertThrowsError(try AnkiPackageParser.extract(from: source, to: directory.appendingPathComponent("output")))
        }
    }

    func testModernCorruptMediaRejected() throws {
        try withFixture { directory in
            let source = try package(in: directory, modern: true, badChecksum: true)
            XCTAssertThrowsError(try AnkiPackageParser.extract(from: source, to: directory.appendingPathComponent("output")))
        }
    }

    func testUnknownVersionAndTruncatedProtobuf() throws {
        XCTAssertThrowsError(try AnkiProtobuf(Data([10, 255])))
        XCTAssertThrowsError(try AnkiProtobuf(Data(repeating: 255, count: 12)))
        try withFixture { directory in
            let url = directory.appendingPathComponent("future.apkg")
            let archive = try Archive(url: url, accessMode: .create)
            try add("meta", data: Data([8, 99]), to: archive)
            XCTAssertThrowsError(try AnkiPackageParser.extract(from: url, to: directory.appendingPathComponent("output")))
        }
    }

    func testBrokenCardReferencesRejected() throws {
        try withFixture { directory in
            let source = try package(in: directory, invalidNote: true)
            XCTAssertThrowsError(try AnkiPackageParser.extract(from: source, to: directory.appendingPathComponent("output")))
        }
    }

    func testRenderingFrontBackSoundAndConditionalSections() {
        let type = AnkiNoteType(id: 1, name: "Basic", isCloze: false, fields: ["Front", "Back", "Empty"], templates: [
            .init(ordinal: 0, name: "Card", question: "{{#Front}}{{Front}}{{/Front}}{{^Empty}}yes{{/Empty}}{{#Empty}}no{{/Empty}}", answer: "{{FrontSide}}<hr>{{Back}}")
        ], css: ".card{font-size:20px}")
        let note = AnkiNote(id: 2, guid: "g", noteTypeID: 1, fields: ["<img src='猫.png'>{{Back}}", "cat[sound:a & b.mp3]", ""], tags: [])
        let card = AnkiCard(id: 3, noteID: 2, deckID: 4, ordinal: 0, scheduling: [:])
        let front = AnkiTemplateRenderer.render(card: card, note: note, type: type, deckName: "test", answer: false)
        XCTAssertTrue(front.html.contains("<img src='猫.png'>{{Back}}yes"))
        XCTAssertFalse(front.html.contains("<audio"))
        let back = AnkiTemplateRenderer.render(card: card, note: note, type: type, deckName: "test", answer: true)
        XCTAssertTrue(back.html.contains("<hr>cat<audio"))
        XCTAssertTrue(back.html.contains("a%20%26%20b.mp3"))
        XCTAssertTrue(back.html.contains("script-src 'none'"))
    }

    func testClozeOrdinalsHintsAndNestedClozes() {
        let type = AnkiNoteType(id: 1, name: "Cloze", isCloze: true, fields: ["Text"], templates: [
            .init(ordinal: 0, name: "Cloze", question: "{{cloze:Text}}", answer: "{{cloze:Text}}")
        ], css: "")
        let note = AnkiNote(id: 2, guid: "g", noteTypeID: 1, fields: ["{{c1::猫::animal}} {{c2::犬}} {{c2::a {{c1::nested}} b}}"], tags: [])
        let card = AnkiCard(id: 3, noteID: 2, deckID: 4, ordinal: 0, scheduling: [:])
        let front = AnkiTemplateRenderer.render(card: card, note: note, type: type, deckName: "test", answer: false)
        XCTAssertTrue(front.html.contains("[animal]"))
        XCTAssertTrue(front.html.contains("犬"))
        XCTAssertFalse(front.html.contains("nested"))
        let back = AnkiTemplateRenderer.render(card: card, note: note, type: type, deckName: "test", answer: true)
        XCTAssertTrue(back.html.contains("猫"))
        XCTAssertTrue(back.html.contains("nested"))
    }

    func testUnsupportedFiltersAreReportedAndFieldsPreserved() {
        let type = AnkiNoteType(id: 1, name: "Custom", isCloze: false, fields: ["F"], templates: [
            .init(ordinal: 0, name: "Card", question: "{{custom:F}}<script>alert(1)</script>", answer: "")
        ], css: "")
        let result = AnkiTemplateRenderer.render(card: .init(id: 3, noteID: 2, deckID: 4, ordinal: 0, scheduling: [:]),
            note: .init(id: 2, guid: "g", noteTypeID: 1, fields: ["value"], tags: []), type: type, deckName: "test", answer: false)
        XCTAssertEqual(result.warnings.count, 2)
        XCTAssertTrue(result.html.contains("value"))
    }

    private func withFixture(_ body: (URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("anki-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try body(directory)
    }

    private func package(in directory: URL, modern: Bool = false, mediaName: String = "猫.png", omitMedia: Bool = false,
                         badChecksum: Bool = false, databaseName: String = "collection.anki2", invalidNote: Bool = false,
                         wal: Bool = false, image: Data = Data("image".utf8)) throws -> URL {
        let databaseURL = directory.appendingPathComponent("source.sqlite")
        var database: OpaquePointer?
        XCTAssertEqual(sqlite3_open(databaseURL.path, &database), SQLITE_OK)
        defer { sqlite3_close(database) }
        func sql(_ value: String) throws {
            guard sqlite3_exec(database, value, nil, nil, nil) == SQLITE_OK else {
                throw AnkiImportError.invalid(String(cString: sqlite3_errmsg(database)))
            }
        }
        func quote(_ value: String) -> String { "'" + value.replacingOccurrences(of: "'", with: "''") + "'" }
        func blob(_ data: Data) -> String { "X'" + data.map { String(format: "%02x", $0) }.joined() + "'" }
        try sql("CREATE TABLE notes(id INTEGER PRIMARY KEY, guid TEXT, mid INTEGER, flds TEXT, tags TEXT)")
        try sql("CREATE TABLE cards(id INTEGER PRIMARY KEY, nid INTEGER, did INTEGER, ord INTEGER, type INTEGER, queue INTEGER, due INTEGER, ivl INTEGER, factor INTEGER, reps INTEGER, lapses INTEGER, left INTEGER, odue INTEGER, odid INTEGER, flags INTEGER)")
        try sql("INSERT INTO notes VALUES(10,'guid',20,\(quote("猫<img src=\"猫.png\">\u{1f}cat[sound:voice.mp3]\u{1f}")),' animal 日本語 ')")
        try sql("INSERT INTO cards VALUES(30,\(invalidNote ? 999 : 10),40,0,2,2,50,10,2500,7,1,0,0,0,0),(31,10,40,1,0,0,1,0,0,0,0,0,0,0,0)")
        if modern {
            try sql("CREATE TABLE decks(id INTEGER PRIMARY KEY, name TEXT)")
            try sql("CREATE TABLE notetypes(id INTEGER PRIMARY KEY, name TEXT, config BLOB)")
            try sql("CREATE TABLE fields(ntid INTEGER, ord INTEGER, name TEXT)")
            try sql("CREATE TABLE templates(ntid INTEGER, ord INTEGER, name TEXT, config BLOB)")
            try sql("INSERT INTO decks VALUES(40,\(quote("Japanese\u{1f}Animals")))")
            try sql("INSERT INTO notetypes VALUES(20,'Basic',\(blob(pb(3, Data(".card { color: red; }".utf8)))))")
            for (index, name) in ["Front", "Back", "Extra"].enumerated() {
                try sql("INSERT INTO fields VALUES(20,\(index),\(quote(name)))")
            }
            for ordinal in 0...1 {
                let config = pb(1, Data((ordinal == 0 ? "{{Front}}" : "{{Back}}").utf8)) + pb(2, Data("{{FrontSide}}<hr>{{Back}}".utf8))
                try sql("INSERT INTO templates VALUES(20,\(ordinal),'Card',\(blob(config)))")
            }
        } else {
            try sql("CREATE TABLE col(models TEXT, decks TEXT)")
            let model = #"{"20":{"id":20,"name":"Basic","type":0,"css":".card { color: red; }","flds":[{"name":"Front","ord":0},{"name":"Back","ord":1},{"name":"Extra","ord":2}],"tmpls":[{"name":"Card","ord":0,"qfmt":"{{Front}}","afmt":"{{FrontSide}}<hr>{{Back}}"},{"name":"Reverse","ord":1,"qfmt":"{{Back}}","afmt":"{{Front}}"}]}}"#
            try sql("INSERT INTO col VALUES(\(quote(model)),\(quote(#"{"40":{"id":40,"name":"Japanese::Animals"}}"#)))")
        }
        if wal {
            // Leave the header in WAL mode with all data checkpointed into the
            // main file — the exact state of a modern Anki export.
            try sql("PRAGMA journal_mode=WAL")
            sqlite3_close(database)
            database = nil
        }
        let url = directory.appendingPathComponent("test.apkg")
        let archive = try Archive(url: url, accessMode: .create)
        let dbData = try Data(contentsOf: databaseURL)
        try add(modern ? "collection.anki21b" : databaseName, data: modern ? compress(dbData) : dbData, to: archive)
        let media = [(mediaName, image), ("voice.mp3", Data("audio".utf8))]
        if modern {
            try add("meta", data: Data([8, 3]), to: archive)
            var map = Data()
            for (name, data) in media {
                let sha = badChecksum ? Data(repeating: 0, count: 20) : Data(Insecure.SHA1.hash(data: data))
                map += pb(1, pb(1, Data(name.utf8)) + Data([16]) + varint(data.count) + pb(3, sha))
            }
            try add("media", data: compress(map), to: archive)
        } else {
            try add("media", data: JSONEncoder().encode(["0": mediaName, "1": "voice.mp3"]), to: archive)
        }
        if !omitMedia {
            for (index, item) in media.enumerated() { try add(String(index), data: modern ? compress(item.1) : item.1, to: archive) }
        }
        return url
    }

    private func add(_ name: String, data: Data, to archive: Archive) throws {
        try archive.addEntry(with: name, type: .file, uncompressedSize: Int64(data.count), compressionMethod: .deflate) { position, count in
            data.subdata(in: Int(position)..<(Int(position) + count))
        }
    }

    private func compress(_ data: Data) throws -> Data {
        var output = Data(count: ZSTD_compressBound(data.count))
        let count = output.withUnsafeMutableBytes { out in
            data.withUnsafeBytes { input in ZSTD_compress(out.baseAddress, out.count, input.baseAddress, input.count, 1) }
        }
        guard ZSTD_isError(count) == 0 else { throw AnkiImportError.invalid("test compression") }
        output.count = count
        return output
    }

    private func pb(_ field: UInt8, _ bytes: Data) -> Data {
        Data([field * 8 + 2]) + varint(bytes.count) + bytes
    }

    private func varint(_ value: Int) -> Data {
        var result = Data()
        var size = value
        while size >= 128 { result.append(UInt8(size & 127) | 128); size >>= 7 }
        result.append(UInt8(size))
        return result
    }
}
