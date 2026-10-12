import XCTest
@testable import kanji_test

@MainActor
final class GrammarPracticeTests: XCTestCase {
    func testAnswerIDsNeverDependOnOptionPositionAndUnknownOptionIsWrong() {
        let exercise = fixture()
        XCTAssertTrue(exercise.accepts("te-hoshii"))
        XCTAssertFalse(exercise.accepts("tai"))
        XCTAssertFalse(exercise.accepts("unknown"))
        let original = Set(exercise.options.map(\.id))
        for seed in ["a", "b", "c", "d"] {
            let ordered = GrammarExerciseSelection.ordered(exercise.options, seed: seed)
            XCTAssertEqual(Set(ordered.map(\.id)), original)
            XCTAssertEqual(ordered.filter { exercise.accepts($0.id) }.map(\.id), ["te-hoshii"])
        }
    }

    func testDeterministicRotationAndDifferentSeedsPreserveEveryExercise() {
        let values = Array(0..<20)
        let first = GrammarExerciseSelection.ordered(values, seed: "first")
        XCTAssertEqual(first, GrammarExerciseSelection.ordered(values, seed: "first"))
        XCTAssertNotEqual(first, GrammarExerciseSelection.ordered(values, seed: "second"))
        XCTAssertEqual(Set(first), Set(values))
    }

    func testEveryRuleHasRealSourceRecallPromptsAndCannotFinishBeforeReveal() async throws {
        let rules = try await GrammarDataLoader.shared.allRules()
        for rule in rules {
            let practice = GrammarPracticeViewModel(rule: rule, seed: "fixture")
            XCTAssertTrue(practice.isSelfAssessment)
            XCTAssertEqual(practice.count, 3)
            XCTAssertEqual(Set(practice.recallPrompts.map(\.id)).count, 3)
            XCTAssertTrue(practice.recallPrompts.allSatisfy { !$0.cue.isEmpty && !$0.sourceAnswer.isEmpty })
            practice.next()
            XCTAssertEqual(practice.position, 0)
            for _ in 0..<3 { practice.reveal(); practice.next() }
            XCTAssertTrue(practice.isComplete)
            XCTAssertTrue(practice.results.isEmpty, "Self-assessment must not fabricate a correct answer")
        }
    }

    func testEveryTypedKindDecodesWithAnIdentityBasedKey() throws {
        for kind in GrammarExerciseKind.allCases {
            let exercise = fixture(kind: kind)
            let decoded = try JSONDecoder().decode(GrammarExercise.self, from: JSONEncoder().encode(exercise))
            XCTAssertEqual(decoded.kind, kind)
            XCTAssertEqual(decoded.acceptedOptionIDs, ["te-hoshii"])
        }
    }

    private func fixture(kind: GrammarExerciseKind = .chooseConstruction) -> GrammarExercise {
        // Test-only answer-key fixture. It is not bundled learning content and makes no review claim.
        GrammarExercise(id: "test-only", ruleID: "te-hoshii", kind: kind,
            promptRU: "Как выразить желание, чтобы другой человек совершил действие?",
            options: [.init(id: "tai", text: "〜たい", feedbackRU: "Выражает желание самого действующего лица."),
                      .init(id: "te-hoshii", text: "〜てほしい", feedbackRU: nil)],
            acceptedOptionIDs: ["te-hoshii"], explanationRU: "〜てほしい выражает желание относительно действия другого лица.",
            difficulty: 1, reviewer: "test fixture; not published")
    }
}
