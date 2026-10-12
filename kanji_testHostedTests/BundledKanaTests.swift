import XCTest
@testable import kanji_test

@MainActor
final class BundledKanaTests: XCTestCase {
    private func expected(_ deck: KanaDeck) -> [(character: String, reading: String)] {
        let snapshot = deck == .hiragana ? LegacyKanaFixture.hiragana : LegacyKanaFixture.katakana
        return snapshot.split(separator: "\n").map {
            let pair = $0.split(separator: "|", omittingEmptySubsequences: false)
            return (String(pair[0]), String(pair[1]))
        }
    }

    func testBundledDecksPreserveEveryCharacterReadingOrderAndProgressKey() async throws {
        let metadata = try await BundledStudyData.shared.bundledKanaMetadata()
        XCTAssertEqual(metadata.count, 229)
        XCTAssertEqual(Set(metadata.map(\.character)).count, 229)
        for deck in KanaDeck.allCases {
            let cards = try await KanaDataLoader.loadCards(deck: deck)
            let legacy = expected(deck)
            XCTAssertEqual(cards.map(\.character), legacy.map(\.character))
            XCTAssertEqual(cards.map(\.reading), legacy.map(\.reading))
            XCTAssertEqual(cards.map(\.id), legacy.map(\.character))
            XCTAssertEqual(cards.map(\.reviewKey), legacy.map { "kana:\($0.character)" })
            XCTAssertTrue(cards.allSatisfy { $0.script == deck })
            XCTAssertEqual(StudyDeck.kana(deck).id, "kana:\(deck.rawValue)")
            let ordered = metadata.filter { $0.script == deck }.sorted { $0.order < $1.order }
            XCTAssertEqual(ordered.map(\.order), Array(1...legacy.count))
        }
    }

    func testEveryCharacterUsesActualBundledKanjiVGStrokes() async throws {
        let cards = try await KanaDataLoader.loadAllCards()
        XCTAssertEqual(cards.filter { $0.character.count == 1 }.count, 163)
        XCTAssertEqual(cards.filter { $0.character.count > 1 }.count, 66)
        for card in cards {
            XCTAssertEqual(card.drawingCards.map(\.kanji), card.character.map(String.init))
            for part in card.drawingCards {
                let strokes = try BundledKanjiVG.strokes(for: part.kanji)
                XCTAssertFalse(strokes.isEmpty, part.kanji)
                XCTAssertEqual(part.strokes.map(\.pathData), strokes.map(\.pathData))
                XCTAssertEqual(part.strokes.map(\.order), strokes.map(\.order))
            }
        }
        let vu = try XCTUnwrap(cards.first { $0.character == "ヴ" })
        XCTAssertEqual(vu.reading, "vu")
    }

    func testSearchAndCatalogIncludeCombinationsAndReadings() async throws {
        let cards = try await KanaDataLoader.loadAllCards()
        let catalog = StudyCardCatalog()
        catalog.register(cards)
        let index = CardSearchIndex(records: cards.map(KanaSearchRecord.init))
        XCTAssertEqual(Set(index.search("kya").map { $0.card.character }), ["きゃ", "キャ"])
        XCTAssertTrue(index.search("きゃ").contains { $0.card.character == "きゃ" })
        for card in cards {
            XCTAssertEqual(catalog.kana(card.id)?.reviewKey, card.reviewKey)
        }
    }

    func testCombinationDrawingTransitionsAndChecksOnlyAfterLastCharacter() async throws {
        let cards = try await KanaDataLoader.loadCards(deck: .hiragana)
        let kana = try XCTUnwrap(cards.first { $0.character == "きゃ" })
        let word = kana.drawingWordCard
        let drawing = DrawingSessionViewModel()
        drawing.drawnStrokes = [[CGPoint(x: 10, y: 20), CGPoint(x: 30, y: 40)]]
        let first = drawing.drawnStrokes
        XCTAssertFalse(drawing.advanceWordKanjiOrCheck(word))
        XCTAssertEqual(drawing.currentWordKanjiIndex, 1)
        XCTAssertTrue(drawing.drawnStrokes.isEmpty)
        XCTAssertEqual(drawing.completedWordDrawings[0], first)
        drawing.drawnStrokes = [[CGPoint(x: 40, y: 50), CGPoint(x: 60, y: 70)]]
        XCTAssertTrue(drawing.advanceWordKanjiOrCheck(word))
        XCTAssertEqual(drawing.wordFeedbackByKanji.count, 2)
        drawing.selectWordKanji(at: 0, in: word)
        XCTAssertEqual(drawing.drawnStrokes, first)
        XCTAssertEqual(kana.reviewKey, "kana:きゃ")
        drawing.resetWordDrawingState()
        drawing.resetCurrentAnswer()
        XCTAssertEqual(drawing.currentWordKanjiIndex, 0)
        XCTAssertTrue(drawing.completedWordDrawings.isEmpty)
    }

    func testManualCharacterSelectionPreservesBothDrawingsBeforeAnswer() async throws {
        let cards = try await KanaDataLoader.loadCards(deck: .hiragana)
        let kana = try XCTUnwrap(cards.first { $0.character == "きゃ" })
        let word = kana.drawingWordCard
        let drawing = DrawingSessionViewModel()
        let first = [[CGPoint(x: 10, y: 20), CGPoint(x: 30, y: 40)]]
        let second = [[CGPoint(x: 50, y: 60), CGPoint(x: 70, y: 80)]]
        drawing.drawnStrokes = first
        drawing.selectWordKanji(at: 1, in: word)
        XCTAssertEqual(drawing.currentWordKanjiIndex, 1)
        XCTAssertTrue(drawing.drawnStrokes.isEmpty)
        drawing.drawnStrokes = second
        drawing.selectWordKanji(at: 0, in: word)
        XCTAssertEqual(drawing.currentWordKanjiIndex, 0)
        XCTAssertEqual(drawing.drawnStrokes, first)
        drawing.selectWordKanji(at: 1, in: word)
        XCTAssertEqual(drawing.drawnStrokes, second)
        XCTAssertFalse(drawing.isAnswerVisible)
    }

    func testGuidedCombinationStartsNextCharacterWithFirstStroke() async throws {
        let cards = try await KanaDataLoader.loadCards(deck: .katakana)
        let kana = try XCTUnwrap(cards.first { $0.character == "キャ" })
        let drawing = DrawingSessionViewModel()
        let word = kana.drawingWordCard
        // Finish the first character through the same explicit transition used by words.
        XCTAssertFalse(drawing.advanceWordKanjiOrCheck(word))
        XCTAssertEqual(word.kanjiCards[drawing.currentWordKanjiIndex].kanji, "ャ")
        XCTAssertEqual(drawing.guidedExpectedStrokes(for: word.kanjiCards[1]).count, 1)
        XCTAssertTrue(drawing.advanceWordKanjiOrCheck(word))
    }

    func testMetadataCacheDoesNotRereadResource() async throws {
        let original = try Data(contentsOf: XCTUnwrap(Bundle.main.url(forResource: "kana-metadata", withExtension: "json")))
        let (bundle, directory) = try resourceBundle(metadata: original)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = BundledStudyData(bundle: bundle)
        let first = try await store.bundledKanaMetadata()
        try Data("broken".utf8).write(to: directory.appendingPathComponent("kana-metadata.json"))
        let cached = try await store.bundledKanaMetadata()
        XCTAssertEqual(cached.map(\.character), first.map(\.character))
    }

    func testMissingAndMalformedResourcesThrow() async throws {
        for data in [nil, Data("broken".utf8), Data("[]".utf8)] as [Data?] {
            let (bundle, directory) = try resourceBundle(metadata: data)
            defer { try? FileManager.default.removeItem(at: directory) }
            do {
                _ = try await BundledStudyData(bundle: bundle).bundledKanaMetadata()
                XCTFail("Invalid resource must fail explicitly")
            } catch {
                XCTAssertTrue(error is CocoaError || error is DecodingError)
            }
        }
    }

    func testMissingKanjiVGCharacterThrowsWithoutGeometricFallback() {
        let unsupported = BundledKanaMetadata(character: "🦄", reading: "test", script: .hiragana, order: 1)
        XCTAssertThrowsError(try unsupported.makeCard())
    }

    func testDuplicatesAndInvalidOrderAreRejected() throws {
        let metadata: [BundledKanaMetadata] = try BundledStudyData.decodeResource("kana-metadata")
        XCTAssertThrowsError(try BundledKanaMetadata.validate(metadata + [metadata[0]]))
        let brokenOrder = BundledKanaMetadata(character: "あ", reading: "a", script: .hiragana, order: 2)
        XCTAssertThrowsError(try BundledKanaMetadata.validate([brokenOrder] + metadata.dropFirst()))
        let brokenReading = BundledKanaMetadata(character: "あ", reading: "", script: .hiragana, order: 1)
        XCTAssertThrowsError(try BundledKanaMetadata.validate([brokenReading] + metadata.dropFirst()))
    }

    private func resourceBundle(metadata: Data?) throws -> (Bundle, URL) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("kana-\(UUID().uuidString).bundle")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let info: [String: Any] = ["CFBundleIdentifier": "tests.kana.\(UUID().uuidString)", "CFBundlePackageType": "BNDL"]
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
            .write(to: directory.appendingPathComponent("Info.plist"))
        if let metadata { try metadata.write(to: directory.appendingPathComponent("kana-metadata.json")) }
        return (try XCTUnwrap(Bundle(url: directory)), directory)
    }
}
