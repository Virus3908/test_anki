import XCTest
@testable import kanji_test

@MainActor
final class GrammarSentenceBankTests: XCTestCase {
    func testEveryN5RuleHasFiveDistinctContextsWithOfflinePreparedRussianAndRuby() async throws {
        let rules = try await GrammarDataLoader().rules(.n5)
        let bank = try await GrammarDataLoader.shared.loadSentenceBank()
        XCTAssertEqual(rules.count, 81)
        XCTAssertEqual(rules.reduce(0) { $0 + $1.studyExamples.count }, 163)
        for rule in rules {
            XCTAssertGreaterThanOrEqual(Set((rule.examples + rule.studyExamples).map(\.ja)).count, 5, rule.id)
            for example in rule.studyExamples {
                XCTAssertFalse(try XCTUnwrap(example.ru).isEmpty)
                XCTAssertNotNil(example.ruby)
                XCTAssertEqual(example.preparationStatus, "assistantPrepared")
                XCTAssertTrue(example.ja.contains(try XCTUnwrap(example.targetConstruction)))
                XCTAssertFalse(try XCTUnwrap(example.skillRU).isEmpty)
                XCTAssertTrue(example.sources?.allSatisfy { !$0.sentenceID.isEmpty && !$0.license.isEmpty && !$0.url.isEmpty } == true)
                XCTAssertEqual(example.translationSources?.first?.status, "assistantPrepared")
            }
            for reference in rule.studyExampleReferences ?? [] {
                let usage = try XCTUnwrap(bank.usages.first { $0.id == reference.usageID })
                XCTAssertEqual(usage.ruleID, rule.id); XCTAssertFalse(usage.eligibleForScoring)
                let sentence = try XCTUnwrap(bank.sentences.first { $0.id == usage.sentenceID })
                let span = try XCTUnwrap(usage.targetSpan)
                let target = String(bytes: sentence.japanese.utf8.dropFirst(span.startUTF8)
                    .prefix(span.endUTF8 - span.startUTF8), encoding: .utf8)
                XCTAssertEqual(target, reference.targetConstruction)
            }
        }
    }
    func testNewN5FormLessonsHaveProvenKeysAndRotateContextsWithoutDuplicates() async throws {
        for id in ["masu", "nai", "ta", "te"] {
            let loaded = try await GrammarDataLoader.shared.rule(id)
            let rule = try XCTUnwrap(loaded)
            let exercises = try XCTUnwrap(rule.exercises)
            XCTAssertEqual(exercises.count, 8)
            XCTAssertEqual(Set(exercises.map(\.kind)), [.formProduction, .fillBlank])
            for exercise in exercises {
                XCTAssertTrue(exercise.validConjugation)
                XCTAssertEqual(exercise.provenance?.status, .algorithmicallyChecked)
                XCTAssertNil(exercise.reviewer)
                for option in exercise.options where !exercise.accepts(option.id) { XCTAssertNotNil(option.feedbackRU) }
            }
            let first = GrammarExerciseEngine.plan(rule: rule, seed: "stable", isReview: true, attempt: 0, previousRating: .good)
            let next = GrammarExerciseEngine.plan(rule: rule, seed: "stable", isReview: true, attempt: 1, previousRating: .good)
            for kind in [GrammarExerciseKind.formProduction, .fillBlank] {
                XCTAssertNotEqual(first.exercises.first { $0.kind == kind }?.id, next.exercises.first { $0.kind == kind }?.id)
            }
            let sentenceIDs = (first.exercises + first.reserve).compactMap(\.sentenceID)
            XCTAssertEqual(Set(sentenceIDs).count, sentenceIDs.count)
        }
    }
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
