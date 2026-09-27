import XCTest

/// Base class for contract tests: the app is addressed only through `AccessibilityID`,
/// and every user action is a timed `step` checked against `UserStep.budget`.
class UITestCase: XCTestCase {
    private(set) var app: XCUIApplication!
    private var timings: [(step: UserStep, seconds: TimeInterval)] = []

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    override func tearDown() {
        attachTimings()
        app = nil
        super.tearDown()
    }

    // MARK: Elements

    func element(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    func elements(_ id: String) -> XCUIElementQuery {
        app.descendants(matching: .any).matching(identifier: id)
    }

    // MARK: Launch

    func launch(importingAnkiFixture: Bool = false) {
        app = AppLauncher.makeApp(importingAnkiFixture: importingAnkiFixture)
        step(.launch, until: element(AccessibilityID.Start.search)) { app.launch() }
    }

    func relaunchKeepingState() {
        app.terminate()
        app = AppLauncher.makeApp(keepingState: true)
        step(.relaunch, until: element(AccessibilityID.Start.search)) { app.launch() }
    }

    // MARK: Timed steps

    /// Runs `action`, then waits (at most the step budget) until `element` exists.
    func step(
        _ step: UserStep,
        until element: XCUIElement,
        file: StaticString = #filePath,
        line: UInt = #line,
        action: () -> Void
    ) {
        self.step(step, file: file, line: line, until: { element.exists }, action: action)
    }

    /// Runs `action`, then waits (at most the step budget) until `condition` holds.
    func step(
        _ step: UserStep,
        file: StaticString = #filePath,
        line: UInt = #line,
        until condition: @escaping () -> Bool,
        action: () -> Void
    ) {
        let started = Date()
        action()
        let predicate = NSPredicate { _, _ in condition() }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: nil)
        let result = XCTWaiter().wait(for: [expectation], timeout: step.budget)
        let seconds = Date().timeIntervalSince(started)
        timings.append((step, seconds))

        XCTAssertEqual(result, .completed, "\(step.rawValue): expected state not reached in \(step.budget)s", file: file, line: line)
        XCTAssertLessThanOrEqual(seconds, step.budget, "\(step.rawValue) took \(Int(seconds * 1000)) ms", file: file, line: line)
    }

    /// Taps the element with `id` and waits for `next` to appear.
    func tap(_ id: String, _ step: UserStep, expecting next: String, file: StaticString = #filePath, line: UInt = #line) {
        let target = element(id)
        XCTAssertTrue(target.waitForExistence(timeout: step.budget), "\(id) not found", file: file, line: line)
        self.step(step, until: element(next), file: file, line: line) { target.tap() }
    }

    // MARK: Contract values

    /// Parses a "key=value;key=value" accessibility value into integers.
    func counters(of id: String) -> [String: Int] {
        let raw = element(id).value as? String ?? ""
        return raw.split(separator: ";").reduce(into: [:]) { result, pair in
            let parts = pair.split(separator: "=", maxSplits: 1)
            guard parts.count == 2, let number = Int(parts[1]) else { return }
            result[String(parts[0])] = number
        }
    }

    // MARK: Report

    private func attachTimings() {
        guard !timings.isEmpty else { return }
        let rows = timings.map { entry in
            let ms = Int(entry.seconds * 1000)
            let budgetMs = Int(entry.step.budget * 1000)
            return "\(entry.step.rawValue.padding(toLength: 22, withPad: " ", startingAt: 0)) \(ms) ms / \(budgetMs) ms"
        }
        let report = "[timings] \(name)\n" + rows.joined(separator: "\n")
        print(report)
        let attachment = XCTAttachment(string: report)
        attachment.name = "Step timings"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
