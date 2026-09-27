import Foundation

/// Stable accessibility identifiers shared by the app and its UI tests.
/// Keep this file free of app types: it is compiled into the UI test target too.
nonisolated enum AccessibilityID {
    enum Start {
        static let sectionKanji = "start.section.kanji"
        static let sectionWords = "start.section.words"
        static let sectionKana = "start.section.kana"
        static let sectionAnki = "start.section.anki"
        static let search = "start.search"
        static let settings = "start.settings"
    }

    enum Deck {
        static let row = "deck.row"
    }

    enum Preview {
        static let back = "preview.back"
        static let start = "preview.start"
        static let custom = "preview.custom"
        static let search = "preview.search"
        static let tile = "preview.tile"
        /// Primary action of a card detail sheet («тренировать эту карточку»).
        static let practiceCard = "preview.practiceCard"
    }

    /// Machine-readable `accessibilityValue` formats (key=value pairs joined by ";"):
    /// - `Preview.start`: "new=N;learning=N;review=N"
    /// - `Training.progress`: "answered=N;remaining=N"
    /// - `Custom.start`: "selected=N"
    /// - `Training.speak`: last text sent to speech synthesis
    enum Custom {
        static let start = "custom.start"
        static let selectAll = "custom.selectAll"
        static let clear = "custom.clear"
    }

    enum Search {
        static let field = "search.field"
        static let summary = "search.summary"
        static let result = "search.result"
    }

    enum Training {
        static let exit = "training.exit"
        static let reveal = "training.reveal"
        static let speak = "training.speak"
        static let progress = "training.progress"
        static let rateAgain = "training.rate.again"
        static let rateHard = "training.rate.hard"
        static let rateGood = "training.rate.good"
        static let rateEasy = "training.rate.easy"
    }

    enum Drawing {
        static let canvas = "drawing.canvas"
        static let clear = "drawing.clear"
        static let undo = "drawing.undo"
    }

    enum Anki {
        static let importPackage = "anki.import"
        static let empty = "anki.empty"
    }
}
