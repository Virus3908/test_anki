#if DEBUG
import Foundation
import UIKit

/// Launch contract for XCUITest runs. Only compiled into Debug builds.
///
/// - `-ui-testing` argument: start from a clean slate and use offline stubs
///   instead of network-backed translators/providers.
/// - `UITEST_KEEP_STATE=1`: skip the clean-slate reset (relaunch persistence checks).
/// - `UITEST_DISABLE_ANIMATIONS=1`: turn off UIKit animations.
/// - `UITEST_ANKI_PACKAGE=<absolute path to .apkg/.colpkg>`: import that
///   package through the regular library import path after startup.
enum UITestingLaunch {
    static let argument = "-ui-testing"
    static let disableAnimationsKey = "UITEST_DISABLE_ANIMATIONS"
    static let ankiPackageKey = "UITEST_ANKI_PACKAGE"
    static let keepStateKey = "UITEST_KEEP_STATE"

    static var isActive: Bool {
        ProcessInfo.processInfo.arguments.contains(argument)
    }

    static var ankiPackageURL: URL? {
        guard isActive,
              let path = ProcessInfo.processInfo.environment[ankiPackageKey],
              !path.isEmpty else { return nil }
        return URL(fileURLWithPath: path)
    }

    /// Must run before any repository or `StudyAppViewModel` is created.
    static func prepareIfNeeded() {
        guard isActive else { return }
        let environment = ProcessInfo.processInfo.environment
        if environment[keepStateKey] != "1" {
            resetPersistentState()
        }
        if environment[disableAnimationsKey] == "1" {
            UIView.setAnimationsEnabled(false)
        }
    }

    private static func resetPersistentState() {
        let fileManager = FileManager.default
        let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        let appOwnedDirectories = applicationSupport.map { $0.appendingPathComponent("KanjiTrainer", isDirectory: true) }
            + caches.flatMap { cachesURL in
                ["KanjiTrainer", "KanjiDeckCacheV2", "KanaVGCache", "WordExampleCache", "KanjiTatoebaExampleCache"].map {
                    cachesURL.appendingPathComponent($0, isDirectory: true)
                }
            }
        for directory in appOwnedDirectories where fileManager.fileExists(atPath: directory.path) {
            try? fileManager.removeItem(at: directory)
        }
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
    }
}

// MARK: - Offline stubs

private struct OfflineMeaningTranslator: MeaningTranslating {
    func translateLocally(_ meanings: [String]) -> [String] { meanings }
    func translate(_ meanings: [String]) async -> [String] { meanings }
    func translatePreservingOrder(_ meanings: [String]) async -> [String] { meanings }
    func translatePreservingOrderManual(_ meanings: [String]) async -> [String] { meanings }
}

private struct OfflineKanjiProvider: KanjiProviding {
    func loadExamples(for kanji: String) async -> [KanjiExample] { [] }
}

private struct OfflineWordExampleProvider: WordExampleProviding {
    func loadExamples(for card: WordStudyCard, limit: Int) async -> [WordUsageExample] { [] }
    func reloadRemoteExamples(for card: WordStudyCard, limit: Int) async -> [WordUsageExample] { [] }
}

extension StudyAppViewModel {
    static func makeForUITesting() -> StudyAppViewModel {
        StudyAppViewModel(
            translator: OfflineMeaningTranslator(),
            kanjiProvider: OfflineKanjiProvider(),
            wordProvider: OfflineWordExampleProvider()
        )
    }

    func importUITestingFixtureIfNeeded() async {
        guard let packageURL = UITestingLaunch.ankiPackageURL else { return }
        await ankiLibrary.load()
        await ankiLibrary.importPackage(packageURL)
    }
}
#endif
