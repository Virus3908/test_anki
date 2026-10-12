import XCTest
@testable import kanji_test

@MainActor
final class WordLoadingTests: XCTestCase {
    func testSubsetContainsOnlyRequiredKanjiAndNoDuplicates() async {
        let entries = [WordDictionaryEntry(word: "食べる", reading: "たべる", meaning: "eat"),
                       WordDictionaryEntry(word: "学校", reading: "がっこう", meaning: "school"),
                       WordDictionaryEntry(word: "食", reading: "しょく", meaning: "food")]
        XCTAssertEqual(WordDataLoader.requiredKanjiCharacters(in: entries), ["食", "学", "校"])
        let cards = await WordDataLoader.loadKanjiCards(for: entries, provider: KanjiAPIProvider())
        XCTAssertEqual(Set(cards.map(\.kanji)), ["食", "学", "校"])
        XCTAssertEqual(cards.count, 3)
        let words = WordDataLoader.buildWords(from: entries, cardsByCharacter: Dictionary(uniqueKeysWithValues: cards.map { ($0.kanji, $0) }))
        XCTAssertEqual(words.map(\.word), entries.map(\.word))
        XCTAssertEqual(words.map(\.reviewKey), entries.map { "word:\($0.id)" })
        XCTAssertTrue(words[0].kanjiCards.allSatisfy { !$0.strokes.isEmpty })
    }

    func testKanaMixedTextAndUnavailableGeometryRemainOffline() async {
        let entries = [WordDictionaryEntry(word: "カナあ🦄", reading: "かな", meaning: "test")]
        let cards = await WordDataLoader.loadKanjiCards(for: entries, provider: KanjiAPIProvider())
        XCTAssertTrue(cards.isEmpty)
        let word = WordDataLoader.buildWords(from: entries + entries, cardsByCharacter: [:])
        XCTAssertEqual(word.count, 1)
        XCTAssertEqual(word[0].kanjiCards.map(\.kanji), ["カ", "ナ", "あ", "🦄"])
        XCTAssertTrue(word[0].kanjiCards.prefix(3).allSatisfy { !$0.strokes.isEmpty })
        XCTAssertTrue(word[0].kanjiCards.last?.strokes.isEmpty == true)
    }

    func testLargeDeckAndRelatedWordsPreserveDictionaryOrder() async throws {
        let entries = try await WordDataLoader.loadDictionaryEntries()
        let selected = Array(entries.prefix(1000))
        let cards = await WordDataLoader.loadKanjiCards(for: selected, provider: KanjiAPIProvider())
        let words = WordDataLoader.buildWords(from: selected, cardsByCharacter: Dictionary(uniqueKeysWithValues: cards.map { ($0.kanji, $0) }))
        var seen: Set<String> = []
        XCTAssertEqual(words.map(\.reviewKey), selected.filter { seen.insert($0.id).inserted }.map { "word:\($0.id)" })
        let related = try await WordDataLoader.loadWords(containing: "学", limit: 3)
        XCTAssertEqual(related.map(\.word), Array(entries.lazy.filter { $0.word.contains("学") }.prefix(3).map(\.word)))
        XCTAssertEqual(Set(cards.map(\.id)).count, cards.count)
    }
}
