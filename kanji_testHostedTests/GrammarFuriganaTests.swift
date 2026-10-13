import XCTest
@testable import kanji_test

@MainActor
final class GrammarFuriganaTests: XCTestCase {
    func testExactExerciseAndOptionReadingsReconstructUntouchedText() async throws {
        let rules = try await GrammarDataLoader.shared.allRules()
        var sentences = 0, options = 0
        for rule in rules {
            for exercise in rule.exercises ?? [] {
                for (text, markup) in exercise.furigana ?? [:] {
                    let segments = try XCTUnwrap(FuriganaParser.parse(markup, original: text), exercise.id)
                    XCTAssertEqual(Array(segments.map(\.text).joined().utf8), Array(text.utf8))
                }
                if let japanese = exercise.japanese, exercise.ruby(for: japanese) != nil { sentences += 1 }
                options += exercise.options.filter { exercise.ruby(for: $0.text) != nil }.count
            }
        }
        XCTAssertGreaterThan(sentences, 0); XCTAssertGreaterThan(options, 0)
    }
    func testNoReadingInferenceAndCorruptMarkupFallsBack() async throws {
        let loaded = try await GrammarDataLoader.shared.rule("tai")
        var exercise = try XCTUnwrap(loaded?.exercises?.first)
        XCTAssertNil(exercise.ruby(for: "未知の文章"))
        let text = try XCTUnwrap(exercise.japanese)
        exercise.furigana = [text: "[違う|ちがう]文章"]
        XCTAssertNil(exercise.ruby(for: text))
    }
    func testReadingTasksNeverExposeRubyAndFormCueDoesNotContainAnswer() async throws {
        let loaded = try await GrammarDataLoader.shared.rule("tai")
        var exercise = try XCTUnwrap(loaded?.exercises?.first { $0.id == "tai:form-eat" })
        XCTAssertNotNil(exercise.ruby(for: "食べる"))
        XCTAssertFalse(exercise.furigana?["食べる"]?.contains("たべたい") ?? true)
        exercise.testsReading = true
        XCTAssertNil(exercise.ruby(for: "食べる"))
        XCTAssertNil(exercise.ruby(for: ["0"]))
    }
    func testAssemblyUsesOnlyExplicitElementReadings() async throws {
        let loaded = try await GrammarDataLoader.shared.rule("tai")
        let exercise = try XCTUnwrap(loaded?.exercises?.first { $0.kind == .assembleSentence })
        let order = try XCTUnwrap(exercise.acceptedOrders?.first)
        let text = order.compactMap { id in exercise.options.first { $0.id == id }?.text }.joined()
        let ruby = try XCTUnwrap(exercise.ruby(for: order))
        XCTAssertEqual(ruby.segments(for: text).map(\.text).joined(), text)
        XCTAssertTrue(ruby.segments(for: text).contains { $0.reading != nil })
    }
}
