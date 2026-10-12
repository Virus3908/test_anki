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
