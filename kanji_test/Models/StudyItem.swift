import Foundation

protocol StudyItem {
    var id: String { get }
    var reviewKey: String { get }
    var displayTitle: String { get }
    var displaySubtitle: String { get }
    var strokes: [KanjiStroke] { get }
}

extension KanjiCard: StudyItem {
    var reviewKey: String {
        kanji
    }

    var displayTitle: String {
        kanji
    }

    var displaySubtitle: String {
        meanings.joined(separator: ", ")
    }
}

extension WordStudyCard: StudyItem {
    var reviewKey: String {
        "word:\(id)"
    }

    var displayTitle: String {
        word
    }

    var displaySubtitle: String {
        [reading, meaning]
            .filter { !$0.isEmpty }
            .joined(separator: " - ")
    }

    var strokes: [KanjiStroke] {
        kanjiCards.flatMap(\.strokes)
    }
}

extension KanaStudyCard: StudyItem {
    var reviewKey: String {
        "kana:\(character)"
    }

    var displayTitle: String {
        character
    }

    var displaySubtitle: String {
        reading
    }
}
