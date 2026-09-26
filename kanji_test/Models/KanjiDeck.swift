import Foundation

enum KanjiDeck: String, CaseIterable, Identifiable {
    case jlpt5
    case jlpt4
    case jlpt3
    case jlpt2
    case jlpt1
    case grade1
    case grade2
    case grade3
    case grade4
    case grade5
    case grade6
    case grade8
    case joyo
    case jinmeiyo
    case all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .jlpt5:
            return "JLPT N5"
        case .jlpt4:
            return "JLPT N4"
        case .jlpt3:
            return "JLPT N3"
        case .jlpt2:
            return "JLPT N2"
        case .jlpt1:
            return "JLPT N1"
        case .grade1:
            return "Grade 1"
        case .grade2:
            return "Grade 2"
        case .grade3:
            return "Grade 3"
        case .grade4:
            return "Grade 4"
        case .grade5:
            return "Grade 5"
        case .grade6:
            return "Grade 6"
        case .grade8:
            return "Secondary School"
        case .joyo:
            return "Joyo"
        case .jinmeiyo:
            return "Jinmeiyo"
        case .all:
            return "All kanji"
        }
    }

    var subtitle: String { "Локальные данные" }

    static var groups: [(title: String, decks: [KanjiDeck])] {
        [
            ("JLPT", [.jlpt5, .jlpt4, .jlpt3, .jlpt2, .jlpt1]),
            ("School grades", [.grade1, .grade2, .grade3, .grade4, .grade5, .grade6, .grade8]),
            ("Other kanji sets", [.joyo, .jinmeiyo, .all])
        ]
    }
}
