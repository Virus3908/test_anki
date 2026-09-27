import XCTest
@testable import kanji_test

final class TrainingCardTypeTests: XCTestCase {
    private let date = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 27))!
    private let nextDay = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 28))!

    private let allFive = TrainingCardType.allCases

    private func resolvedTypes(allowed: [TrainingCardType], date: Date) -> [TrainingCardType] {
        (0..<200).map { TrainingCardType.resolve(cardID: "card\($0)", deckID: "kanji:test", date: date, allowed: allowed) }
    }

    func testResolveIsDeterministic() {
        let first = TrainingCardType.resolve(cardID: "card1", deckID: "kanji:test", date: date, allowed: allFive)
        let second = TrainingCardType.resolve(cardID: "card1", deckID: "kanji:test", date: date, allowed: allFive)
        XCTAssertEqual(first, second)
    }

    func testResolveOnlyUsesAllowedTypes() {
        let allowed = Array(TrainingCardType.allowed(for: .kana))
        let resolved = resolvedTypes(allowed: allowed, date: date)
        XCTAssertTrue(resolved.allSatisfy { allowed.contains($0) })
    }

    func testResolveDistributesAcrossAllowedTypes() {
        for allowed in [allFive, Array(TrainingCardType.allowed(for: .words))] {
            let hits = Set(resolvedTypes(allowed: allowed, date: date))
            XCTAssertEqual(hits, Set(allowed))
        }
    }

    func testResolveChangesAcrossDays() {
        let today = resolvedTypes(allowed: allFive, date: date)
        let tomorrow = resolvedTypes(allowed: allFive, date: nextDay)
        XCTAssertNotEqual(today, tomorrow)
    }

    func testResolveWithEmptyAllowedTypesFallsBackToDrawing() {
        let resolved = TrainingCardType.resolve(cardID: "card1", deckID: "kanji:test", date: date, allowed: [])
        XCTAssertEqual(resolved, .drawing)
    }

    func testAllowedTypesPerMode() {
        XCTAssertEqual(TrainingCardType.allowed(for: .kanji), allFive)
        XCTAssertEqual(TrainingCardType.allowed(for: .words), [.flip, .choice, .typed, .audio])
        XCTAssertEqual(TrainingCardType.allowed(for: .kana), [.drawing, .flip, .choice, .audio])
        XCTAssertTrue(TrainingCardType.allowed(for: .anki).isEmpty)
    }

    func testDefaultTypesPerMode() {
        XCTAssertEqual(TrainingCardType.defaults(for: .kanji), [.drawing])
        XCTAssertEqual(TrainingCardType.defaults(for: .kana), [.drawing])
        XCTAssertEqual(TrainingCardType.defaults(for: .words), [.flip])
        XCTAssertTrue(TrainingCardType.defaults(for: .anki).isEmpty)
    }

    func testEffectiveTypesFallBackToDefaults() {
        XCTAssertEqual(TrainingCardType.effectiveTypes(configured: nil, mode: .kanji), [.drawing])
        XCTAssertEqual(TrainingCardType.effectiveTypes(configured: [], mode: .words), [.flip])
    }

    func testEffectiveTypesFilterByMode() {
        XCTAssertEqual(TrainingCardType.effectiveTypes(configured: [.typed], mode: .kana), [.drawing])
        XCTAssertEqual(TrainingCardType.effectiveTypes(configured: [.typed, .flip], mode: .kana), [.flip])
        XCTAssertEqual(
            TrainingCardType.effectiveTypes(configured: [.choice, .audio, .typed, .drawing], mode: .words),
            [.choice, .typed, .audio]
        )
    }

    func testCanonicalOrderFollowsAllCases() {
        XCTAssertEqual(TrainingCardType.canonicalOrder([.audio, .drawing]), [.drawing, .audio])
    }

    func testDeckOptionsDecodesLegacyJSONWithoutCardTypes() throws {
        let legacyJSON = """
        {"dailyNewCardLimit":10,"desiredRetention":0.9,"maximumInterval":36500,
        "learningSteps":[1,10],"relearningSteps":[10],"meaningLanguage":"russian",
        "showsPromptCharacters":false,"showsPromptReading":true,"showsPromptMeaning":false,
        "frontFieldOrder":["readings","meanings","character"]}
        """
        let decoded = try JSONDecoder().decode(DeckOptions.self, from: Data(legacyJSON.utf8))
        XCTAssertNil(decoded.cardTypes)
    }

    func testDeckOptionsRoundTripsCardTypes() throws {
        let options = DeckOptions(cardTypes: [.flip, .choice])
        let decoded = try JSONDecoder().decode(DeckOptions.self, from: JSONEncoder().encode(options))
        XCTAssertEqual(decoded, options)
        XCTAssertEqual(decoded.cardTypes, [.flip, .choice])
    }

    func testDeckOptionsValidatedNormalizesCardTypes() {
        var duplicated = DeckOptions()
        duplicated.cardTypes = [.choice, .flip, .choice]
        XCTAssertEqual(duplicated.validated.cardTypes, [.flip, .choice])

        var empty = DeckOptions()
        empty.cardTypes = []
        XCTAssertNil(empty.validated.cardTypes)
    }
}
