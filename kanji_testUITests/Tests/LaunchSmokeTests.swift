import XCTest

final class LaunchSmokeTests: UITestCase {
    func testCleanLaunchShowsStartScreen() {
        launch()

        for section in Self.sections {
            XCTAssertTrue(element(section).exists, "Missing \(section)")
        }
        XCTAssertTrue(element(ID.Start.search).exists)
    }
}
