import XCTest

/// Configures the app for its isolated UI-testing mode (see `UITestingLaunch` in the app target).
enum AppLauncher {
    private final class BundleToken {}

    static func makeApp(importingAnkiFixture: Bool = false, keepingState: Bool = false,
                        largeText: Bool = false, darkMode: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        // Auto-speak off: speech may only come from an explicit tap in tests.
        // Argument-domain values are parsed as plist, so a real Bool needs `<false/>`.
        app.launchArguments = ["-ui-testing", "-speechEnabled", "<false/>"]
        if darkMode { app.launchEnvironment["UITEST_GRAMMAR_DARK_MODE"] = "1" }
        app.launchEnvironment["UITEST_DISABLE_ANIMATIONS"] = "1"
        if largeText { app.launchEnvironment["UITEST_GRAMMAR_LARGE_TEXT"] = "1" }
        if keepingState {
            app.launchEnvironment["UITEST_KEEP_STATE"] = "1"
        }
        if importingAnkiFixture {
            app.launchEnvironment["UITEST_ANKI_PACKAGE"] = ankiFixturePath
        }
        return app
    }

    private static var ankiFixturePath: String {
        guard let path = Bundle(for: BundleToken.self).path(forResource: "ui-test-deck", ofType: "apkg") else {
            fatalError("ui-test-deck.apkg is missing from the UI test bundle resources")
        }
        return path
    }
}
