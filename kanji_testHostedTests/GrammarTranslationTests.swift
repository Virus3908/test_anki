import XCTest
@testable import kanji_test

@MainActor
final class GrammarTranslationTests: XCTestCase {
    func testAllSourceFieldsAreAvailableForPhoneTranslation() async throws {
        for rule in try await GrammarDataLoader.shared.allRules() {
            let source = TranslationViewModel.grammarEnglishTexts(rule)
            XCTAssertTrue(source.contains(rule.meaning))
            XCTAssertTrue(source.contains(rule.formation))
            XCTAssertTrue(source.contains(try XCTUnwrap(rule.displayedExplanation)))
            XCTAssertTrue(rule.examples.allSatisfy { source.contains($0.en) })
        }
    }

    func testPhoneTranslationCachesAndPreservesJapaneseWithoutChangingExistingEntries() async throws {
        let repository = GrammarTranslationMemory()
        let old = StoredTextTranslation(source: ["sun"], sourceLanguage: "en", targetLanguage: "ru", texts: ["солнце"])
        try await repository.save(old, for: .kanjiMeaning("日"))
        let model = makeModel(repository, unavailable: false)
        await model.loadSavedTranslations()
        let rules = try await GrammarDataLoader.shared.rules(.n5)
        let rule = try XCTUnwrap(rules.first)
        await model.translateGrammarIfNeeded(rule, language: .russian)
        let translated = model.displayedGrammarText(rule.formation, rule: rule, language: .russian)
        XCTAssertTrue(translated.hasPrefix("Перевод: "))
        XCTAssertTrue(translated.contains("は"))
        XCTAssertFalse(translated.contains("TOKEN"))
        XCTAssertEqual(model.displayedGrammarText(rule.formation, rule: rule, language: .english), rule.formation)
        let restarted = makeModel(repository, unavailable: true)
        await restarted.loadSavedTranslations()
        await restarted.translateGrammarIfNeeded(rule, language: .russian)
        XCTAssertEqual(restarted.displayedGrammarText(rule.formation, rule: rule, language: .russian), translated)
        let stored = try await repository.load()
        XCTAssertEqual(stored.entries[TranslationBlockKey.kanjiMeaning("日").storageKey]?.texts, ["солнце"])
    }

    func testUnavailableTranslationKeepsEnglishAndRemainsRetryable() async throws {
        let repository = GrammarTranslationMemory()
        let model = makeModel(repository, unavailable: true)
        let rules = try await GrammarDataLoader.shared.rules(.n5)
        let rule = try XCTUnwrap(rules.first)
        await model.translateGrammarIfNeeded(rule, language: .russian)
        XCTAssertEqual(model.displayedGrammarText(rule.meaning, rule: rule, language: .russian), rule.meaning)
        let stored = try await repository.load()
        XCTAssertNil(stored.entries[TranslationBlockKey.grammarContent(rule.id).storageKey])
    }

    private func makeModel(_ repository: GrammarTranslationMemory, unavailable: Bool) -> TranslationViewModel {
        TranslationViewModel(repository: repository, translator: GrammarTranslationStub(unavailable: unavailable),
            kanjiProvider: GrammarNoKanji(), wordProvider: GrammarNoWords(), errors: StorageStatus())
    }
}

private actor GrammarTranslationMemory: TranslationPersisting {
    var value = TranslationStore()
    func load() -> TranslationStore { value }
    func save(_ translation: StoredTextTranslation, for key: TranslationBlockKey) { value.entries[key.storageKey] = translation }
    func hasRecoverableBackup() -> Bool { false }
    func restoreBackup() -> TranslationStore { value }
}
private struct GrammarTranslationStub: MeaningTranslating {
    let unavailable: Bool
    func translateLocally(_ texts: [String]) -> [String] { texts }
    func translate(_ texts: [String]) async -> [String] { await translatePreservingOrder(texts) }
    func translatePreservingOrder(_ texts: [String]) async -> [String] { unavailable ? texts : texts.map { "Перевод: " + $0 } }
    func translatePreservingOrderManual(_ texts: [String]) async -> [String] { await translatePreservingOrder(texts) }
}
private struct GrammarNoKanji: KanjiProviding {
    func loadExamples(for kanji: String) async -> [KanjiExample] { [] }
}
private struct GrammarNoWords: WordExampleProviding {
    func loadExamples(for card: WordStudyCard, limit: Int) async -> [WordUsageExample] { [] }
    func reloadRemoteExamples(for card: WordStudyCard, limit: Int) async -> [WordUsageExample] { [] }
}
