import XCTest
@testable import kanji_test

@MainActor
final class GrammarSentenceBankTests: XCTestCase {
    func testAllRulesResolveNormalizedExamplesAndExistingExercisesOffline() async throws {
        let loader = GrammarDataLoader()
        let bank = try await loader.loadSentenceBank()
        try bank.validate()
        let rules = try await loader.allRules()
        XCTAssertEqual(rules.count, 526)
        XCTAssertEqual(rules.reduce(0) { $0 + $1.examples.count }, 1526)
        XCTAssertEqual(Set(bank.sentences.map(\.id)).count, bank.sentences.count)
        for rule in rules {
            XCTAssertEqual(rule.exampleReferences?.count, rule.examples.count)
            XCTAssertEqual(rule.exerciseTemplateIDs?.count, rule.exercises?.count ?? 0)
            for exercise in rule.exercises ?? [] {
                XCTAssertFalse(exercise.promptRU.hasPrefix("@gtext:"))
                XCTAssertTrue(exercise.isUsable(for: rule.id))
                if let id = exercise.sentenceID { XCTAssertTrue(bank.sentences.contains { $0.id == id }) }
            }
        }
        for sentence in bank.sentences where sentence.sources.contains(where: { $0.name == "Tatoeba" }) {
            XCTAssertEqual(sentence.status, "linguisticallyReviewed")
        }
    }
    func testMissingTemplateOrTextAndWrongRuleAreRejected() async throws {
        let bank = try await GrammarDataLoader.shared.loadSentenceBank()
        XCTAssertThrowsError(try bank.exercises(["missing"], ruleID: "tai"))
        XCTAssertThrowsError(try bank.exercises(["tai:go"], ruleID: "wa"))
        let missing = GrammarSentenceBank(schemaVersion: bank.schemaVersion, texts: [:], sentences: bank.sentences,
            usages: bank.usages, templates: bank.templates)
        XCTAssertThrowsError(try missing.exercises(["tai:go"], ruleID: "tai"))
    }
    func testSemanticSegmentsReconstructOriginalAndRemainDistinctFromMorphology() async throws {
        let bank = try await GrammarDataLoader.shared.loadSentenceBank()
        let usage = try XCTUnwrap(bank.usages.first { $0.id == "te-hoshii:buy" })
        let sentence = try XCTUnwrap(bank.sentences.first { $0.id == usage.sentenceID })
        let chunks = try usage.segments.map { segment in
            try XCTUnwrap(String(bytes: sentence.japanese.utf8.dropFirst(segment.startUTF8)
                .prefix(segment.endUTF8 - segment.startUTF8), encoding: .utf8))
        }
        XCTAssertEqual(chunks.joined(), sentence.japanese)
        XCTAssertTrue(chunks.contains { $0.count > 1 })
    }
    func testFreshSentenceHasPriorityOverRepeatingOneInAdjacentQuestions() {
        let active = [GrammarSessionPlanner.ActiveRule(id: "a", priority: 0, lastStep: 0, retryAfter: nil, hasErrors: false, sentenceID: "s"),
            .init(id: "b", priority: 1, lastStep: 0, retryAfter: nil, hasErrors: false, sentenceID: "t")]
        XCTAssertEqual(GrammarSessionPlanner.nextRule(active, previousID: "x", step: 1, seed: "fixed", previousSentenceID: "s"), "b")
    }
    func testPerRulePlanDoesNotDuplicateTheSameSentenceAcrossDifferentTasks() async throws {
        let loaded = try await GrammarDataLoader.shared.rule("tai")
        let rule = try XCTUnwrap(loaded)
        let plan = GrammarExerciseEngine.plan(rule: rule, seed: "context", isReview: false, attempt: 0, previousRating: nil)
        let ids = plan.exercises.compactMap(\.sentenceID)
        XCTAssertEqual(Set(ids).count, ids.count)
    }
}
