import Foundation

protocol StudyItem {
    var id: String { get }
    nonisolated var reviewKey: String { get }
}

extension KanjiCard: StudyItem {
    nonisolated var reviewKey: String {
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
    nonisolated var reviewKey: String {
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
    nonisolated var reviewKey: String {
        "kana:\(character)"
    }

    var displayTitle: String {
        character
    }

    var displaySubtitle: String {
        reading
    }
}
