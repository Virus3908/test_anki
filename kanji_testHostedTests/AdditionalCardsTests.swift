import XCTest
@testable import kanji_test

@MainActor
final class AdditionalCardsTests: XCTestCase {
    func testGrantsSurviveRelaunchAreIndependentAndDoNotModifyOptions() throws {
        let suite = "AdditionalCards-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = StudyPreferences(defaults: defaults, errors: StorageStatus())
        let day = Date()
        let limit = settings.options(for: "one").dailyNewCardLimit
        settings.addAdditionalCards(3, for: "one", studyDay: day)
        settings.addAdditionalCards(4, for: "two", studyDay: day)
        settings.addAdditionalCards(2, for: "one", studyDay: day)
        let restored = StudyPreferences(defaults: defaults, errors: StorageStatus())
        XCTAssertEqual(restored.additionalCardCount(for: "one", studyDay: day), 5)
        XCTAssertEqual(restored.additionalCardCount(for: "two", studyDay: day), 4)
        XCTAssertEqual(restored.additionalCardCount(for: "three", studyDay: day), 0)
        XCTAssertEqual(restored.options(for: "one").dailyNewCardLimit, limit)
        // Viewing the grant repeatedly must never consume or duplicate it.
        XCTAssertEqual(restored.additionalCardCount(for: "one", studyDay: day), 5)
    }

    func testMidnightManualDayAndTimeZoneUseCalendar() throws {
        let suite = "AdditionalCards-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = StudyPreferences(defaults: defaults, errors: StorageStatus())
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let before = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 10, day: 1, hour: 23, minute: 59)))
        let after = before.addingTimeInterval(120)
        settings.addAdditionalCards(3, for: "deck", studyDay: before, calendar: calendar)
        XCTAssertEqual(settings.additionalCardCount(for: "deck", studyDay: before, calendar: calendar), 3)
        XCTAssertEqual(settings.additionalCardCount(for: "deck", studyDay: after, calendar: calendar), 0)
        settings.expireAdditionalCards(studyDay: after, calendar: calendar)
        let restored = StudyPreferences(defaults: defaults, errors: StorageStatus())
        XCTAssertEqual(restored.additionalCardCount(for: "deck", studyDay: before, calendar: calendar), 0)
        settings.addAdditionalCards(2, for: "deck", studyDay: after, calendar: calendar)
        let next = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: after))
        settings.expireAdditionalCards(studyDay: next, calendar: calendar)
        XCTAssertEqual(settings.additionalCardCount(for: "deck", studyDay: next, calendar: calendar), 0)
    }

    func testRestoredSessionUsesExtraLimitAndUndoKeepsGrant() async throws {
        let suite = "AdditionalCards-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let errors = StorageStatus()
        let settings = StudyPreferences(defaults: defaults, errors: errors)
        settings.updateOptions(for: "deck") { $0.dailyNewCardLimit = 1 }
        let repository = GrantTestReviews()
        let session = TrainingSessionViewModel(repository: repository, catalog: StudyCardCatalog(), settings: settings, errors: errors)
        try await session.loadProgress()
        session.addNewCardsToToday(2, for: "deck")
        let restoredSettings = StudyPreferences(defaults: defaults, errors: errors)
        let restored = TrainingSessionViewModel(repository: repository, catalog: StudyCardCatalog(), settings: restoredSettings, errors: errors)
        try await restored.loadProgress()
        let deck = StudyDeck(id: "deck", title: "Test", mode: .kanji)
        let started = await restored.start(deck: deck, sourceIDs: ["one", "two", "three", "four"])
        XCTAssertTrue(started)
        XCTAssertEqual(restored.sessionTotalCards, 3)
        XCTAssertEqual(restored.options.dailyNewCardLimit, 3)
        await restored.submitReview(.good, expectedKey: nil)
        await restored.moveToPreviousCard()
        XCTAssertEqual(restoredSettings.additionalCardCount(for: "deck", studyDay: restored.reviewStore.studyDate()), 2)
        XCTAssertEqual(restoredSettings.options(for: "deck").dailyNewCardLimit, 1)
        try await restored.advanceStudyDay()
        XCTAssertEqual(restoredSettings.additionalCardCount(for: "deck", studyDay: restored.reviewStore.studyDate()), 0)
    }

    func testUnreadableGrantDataIsPreserved() throws {
        let suite = "AdditionalCards-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let bytes = Data("broken".utf8)
        defaults.set(bytes, forKey: "additionalStudyCards")
        let settings = StudyPreferences(defaults: defaults, errors: StorageStatus())
        settings.addAdditionalCards(3, for: "deck", studyDay: Date())
        XCTAssertEqual(defaults.data(forKey: "additionalStudyCards"), bytes)
    }
}

@MainActor private final class GrantTestReviews: ReviewPersisting {
    private var progress = StudyProgressStore(records: [:])
    func load() async throws -> StudyProgressStore { progress }
    func save(_ progress: StudyProgressStore) async throws { self.progress = progress }
    func hasRecoverableBackup() async -> Bool { false }
    func restoreBackup() async throws -> StudyProgressStore { progress }
}
