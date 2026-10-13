import XCTest
@testable import kanji_test

@MainActor
final class GrammarDataTests: XCTestCase {
    func testAllFiveBundledLevelsOfflineWithStableSourceIDs() async throws {
        let loader = GrammarDataLoader()
        let all = try await loader.allRules()
        XCTAssertEqual(all.count, 526)
        XCTAssertEqual(Set(all.map(\.id)).count, 526)
        XCTAssertEqual(all.first?.id, "wa")
        for level in GrammarLevel.allCases {
            let resource = try await loader.resource(level)
            XCTAssertEqual(resource.rules.count, level.expectedCount)
            XCTAssertTrue(resource.rules.allSatisfy { $0.level == level })
            XCTAssertEqual(resource.metadata.commit, "0d1d3410bec90bd4098a7c72de820543cb4f707c")
            XCTAssertEqual(resource.metadata.license, "CC-BY-SA-4.0")
            let cached = try await loader.rules(level)
            XCTAssertEqual(cached.map(\.id), resource.rules.map(\.id))
        }
        XCTAssertEqual(all.reduce(0) { $0 + $1.examples.count }, 1526)
        XCTAssertTrue(all.allSatisfy { !$0.meaning.isEmpty && !$0.formation.isEmpty && !$0.examples.isEmpty })
        for rule in all {
            XCTAssertEqual(rule.reviewKey, "grammar:\(rule.id)")
            XCTAssertTrue(rule.tags.allSatisfy { GrammarCategory(rawValue: $0) != nil })
            for example in rule.examples {
                XCTAssertFalse(example.ja.isEmpty); XCTAssertFalse(example.en.isEmpty)
                if let ruby = example.ruby {
                    XCTAssertEqual(Array(ruby.segments(for: example.ja).map(\.text).joined().utf8), Array(example.ja.utf8))
                }
            }
        }
    }

    func testSourceOnlyContentIsNeverMisrepresentedAsRussianOrReviewedExercises() async throws {
        let all = try await GrammarDataLoader.shared.allRules()
        for rule in all where rule.localization == nil {
            XCTAssertEqual(rule.displayedMeaning, rule.meaning)
            XCTAssertEqual(rule.displayedFormation, rule.formation)
            XCTAssertTrue(rule.examples.allSatisfy { $0.ru == nil })
            let practice = GrammarPracticeViewModel(rule: rule, seed: "source-only")
            XCTAssertFalse(practice.isSelfAssessment)
            if rule.teaching == nil { XCTAssertEqual(rule.exercises?.count ?? 0, 0) }
            else { XCTAssertGreaterThanOrEqual(rule.exercises?.count ?? 0, 8) }
            if rule.teaching != nil { XCTAssertGreaterThanOrEqual(Set((rule.exercises ?? []).map(\.kind)).count, 2) }
            XCTAssertTrue((rule.exercises ?? []).allSatisfy { exercise in
                (exercise.provenance?.status == .automaticallyChecked || exercise.provenance?.status == .algorithmicallyChecked) && exercise.reviewer == nil
            })
        }
    }

    func testLookupCategoriesAndExplicitSourceMentions() async throws {
        let loader = GrammarDataLoader()
        let source = try await loader.allRules()
        let found = try await loader.rule("te-hoshii")
        XCTAssertNotNil(found)
        let unknown = try await loader.rule("nonexistent-rule")
        XCTAssertNil(unknown)
        let particles = try await loader.rules(category: .particle)
        XCTAssertFalse(particles.isEmpty)
        XCTAssertTrue(particles.allSatisfy { $0.tags.contains("particle") })
        XCTAssertFalse(source.flatMap { $0.relations ?? [] }.isEmpty)
        for rule in source {
            let related = try await loader.related(to: rule)
            XCTAssertEqual(related.map(\.id), (rule.relations ?? []).map(\.ruleID))
            XCTAssertFalse(related.contains { $0.id == rule.id })
        }
    }

    func testMissingResourceThrowsInsteadOfReturningEmpty() async {
        do {
            _ = try await GrammarDataLoader(resourceURLs: [:]).rules(.n1)
            XCTFail("Missing content must not become a successful empty level")
        } catch { XCTAssertTrue(error is GrammarDataLoader.Error) }
    }

    func testInvalidSchemaDuplicateIDsAndIncompleteLevelAreRejected() async throws {
        let resource = try await GrammarDataLoader.shared.resource(.n5)
        XCTAssertThrowsError(try GrammarDataLoader.validate(GrammarResource(schemaVersion: 999,
            metadata: resource.metadata, rules: resource.rules), level: .n5))
        XCTAssertThrowsError(try GrammarDataLoader.validate(GrammarResource(schemaVersion: 1,
            metadata: resource.metadata, rules: Array(resource.rules.dropLast())), level: .n5))
        var rules = resource.rules
        rules[1] = rules[0]
        XCTAssertThrowsError(try GrammarDataLoader.validate(GrammarResource(schemaVersion: 1,
            metadata: resource.metadata, rules: rules), level: .n5))
    }

    func testMalformedRubyFallsBackToUntouchedJapanese() {
        let example = GrammarExample(ja: "私は学生です。", en: "I am a student.",
            furigana: "{彼|かれ}は{学生|がくせい}です。", ru: nil)
        XCTAssertNil(example.ruby)
        XCTAssertEqual(example.ja, "私は学生です。")
    }

    func testSearchTermsJapaneseRomajiEnglishRussianCategoriesAndLevel() async throws {
        let all = try await GrammarDataLoader.shared.allRules()
        let index = CardSearchIndex(records: all.map(GrammarSearchRecord.init))
        XCTAssertTrue(index.search("つもり").contains { $0.rule.id == "tsumori" })
        XCTAssertFalse(index.search("hoshii").isEmpty)
        XCTAssertFalse(index.search("condition").isEmpty)
        XCTAssertFalse(index.search("Условия").isEmpty)
        XCTAssertEqual(index.search("N1").count, 123)
        XCTAssertEqual(index.search("N1").map { $0.rule.id }, all.filter { $0.level == .n1 }.map(\.id))
    }
}
