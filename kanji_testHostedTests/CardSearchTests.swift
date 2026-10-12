import XCTest
@testable import kanji_test

/// Тесты поиска карточек: ромадзи-транслитерация, индекс, записи.
final class CardSearchTests: XCTestCase {
    // MARK: KanaRomaji

    func testKanaRomajiConvertBasics() {
        XCTAssertEqual(KanaRomaji.convert("くち"), "kuchi")
        XCTAssertEqual(KanaRomaji.convert("ゴ"), "go")
        XCTAssertEqual(KanaRomaji.convert("カ"), "ka")
    }

    func testKanaRomajiConvertLongVowels() {
        XCTAssertEqual(KanaRomaji.convert("こう"), "kou")
        XCTAssertEqual(KanaRomaji.convert("コーヒー"), "koohii")
    }

    func testKanaRomajiConvertDigraphs() {
        XCTAssertEqual(KanaRomaji.convert("きょう"), "kyou")
        XCTAssertEqual(KanaRomaji.convert("しゃ"), "sha")
        XCTAssertEqual(KanaRomaji.convert("ジュース"), "juusu")
    }

    func testKanaRomajiConvertDoubledConsonant() {
        XCTAssertEqual(KanaRomaji.convert("いっぱい"), "ippai")
        XCTAssertEqual(KanaRomaji.convert("かった"), "katta")
    }

    func testKanaRomajiCompact() {
        XCTAssertEqual(KanaRomaji.compact("kou"), "ko")
        XCTAssertEqual(KanaRomaji.compact("koohii"), "kohi")
        XCTAssertEqual(KanaRomaji.compact("kyou"), "kyo")
    }

    // MARK: CardSearchIndex

    private struct ToyRecord: CardSearchRecord {
        let id: String
        var searchTerms: [String] { [id] }
    }

    func testSearchFindsBySingleWord() {
        let index = CardSearchIndex(records: [ToyRecord(id: "kuchi mouth"), ToyRecord(id: "yama mountain")])

        XCTAssertEqual(index.search("kuchi").map(\.id), ["kuchi mouth"])
    }

    func testSearchRequiresAllWords() {
        let index = CardSearchIndex(records: [ToyRecord(id: "kuchi mouth"), ToyRecord(id: "kuchi")])

        XCTAssertEqual(index.search("kuchi mouth").map(\.id), ["kuchi mouth"])
    }

    func testSearchIsCaseInsensitive() {
        let index = CardSearchIndex(records: [ToyRecord(id: "Kuchi")])

        XCTAssertEqual(index.search("KUCHI").count, 1)
    }

    func testSearchEmptyQueryReturnsNothing() {
        let index = CardSearchIndex(records: [ToyRecord(id: "kuchi")])

        XCTAssertTrue(index.search("").isEmpty)
        XCTAssertTrue(index.search("   ").isEmpty)
    }

    func testBoundedSearchCountsAllMatchesAndPreservesOrder() throws {
        let records = (0..<1000).map { ToyRecord(id: "match \($0)") }
        let found = try CardSearchIndex(records: records).search("match", limit: 60)
        XCTAssertEqual(found.totalFound, 1000)
        XCTAssertEqual(found.records.map(\.id), records.prefix(60).map(\.id))
        XCTAssertEqual(try CardSearchIndex(records: records).search("match", limit: 0).totalFound, 1000)
    }

    func testCancelledScanDoesNotReturnPartialResults() async {
        let index = CardSearchIndex(records: (0..<10000).map { ToyRecord(id: "match \($0)") })
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try index.search("match", limit: 60)
        }
        do { _ = try await task.value; XCTFail("Expected cancellation") }
        catch { XCTAssertTrue(error is CancellationError) }
    }

    func testLargeSearchPerformance() {
        let index = CardSearchIndex(records: (0..<50000).map { ToyRecord(id: "日本 nihon japan \($0)") })
        measure {
            let found = try? index.search("nihon japan", limit: 60)
            XCTAssertEqual(found?.totalFound, 50000)
            XCTAssertEqual(found?.records.count, 60)
        }
    }

    // MARK: KanjiSearchRecord

    private func makeKanjiCard(
        kanji: String = "口",
        meanings: [String] = ["mouth"],
        onyomi: [String] = ["コウ"],
        kunyomi: [String] = ["くち"],
        russianMeanings: [String]? = nil
    ) -> KanjiCard {
        KanjiCard(
            kanji: kanji,
            meanings: meanings,
            onyomi: onyomi,
            kunyomi: kunyomi,
            examples: [],
            russianMeanings: russianMeanings,
            source: KanjiSource(name: "test", file: "test", license: "test"),
            strokes: []
        )
    }

    func testKanjiSearchRecordTerms() {
        let record = KanjiSearchRecord(card: makeKanjiCard(), russianMeanings: ["рот"])

        let terms = record.searchTerms

        XCTAssertTrue(terms.contains("口"))
        XCTAssertTrue(terms.contains("mouth"))
        XCTAssertTrue(terms.contains("рот"))
        XCTAssertTrue(terms.contains("くち"))
        XCTAssertTrue(terms.contains("kuchi"))
        XCTAssertTrue(terms.contains("コウ"))
        XCTAssertTrue(terms.contains("kou"))
        XCTAssertTrue(terms.contains("ko"))
    }

    func testKanjiSearchRecordFindsByRussianMeaning() {
        let record = KanjiSearchRecord(card: makeKanjiCard(), russianMeanings: ["рот"])
        let index = CardSearchIndex(records: [record])

        XCTAssertEqual(index.search("рот").count, 1)
    }

    // MARK: WordSearchRecord

    func testWordSearchRecordTerms() {
        let entry = WordDictionaryEntry(word: "口", reading: "くち", meaning: "mouth")
        let record = WordSearchRecord(entry: entry)

        let terms = record.searchTerms

        XCTAssertTrue(terms.contains("口"))
        XCTAssertTrue(terms.contains("くち"))
        XCTAssertTrue(terms.contains("kuchi"))
        XCTAssertTrue(terms.contains("mouth"))
    }
}
