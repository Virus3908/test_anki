import Foundation

enum WordFrequencyDeck: String, CaseIterable, Identifiable, Sendable {
    case top1000
    case top2000
    case top5000
    case top10000

    var id: String { rawValue }

    var title: String {
        switch self {
        case .top1000:
            return "Common 1"
        case .top2000:
            return "Common 2"
        case .top5000:
            return "Common 3"
        case .top10000:
            return "Common 4"
        }
    }

    var subtitle: String {
        "Локальный JMdict common-набор"
    }

    var bounds: Range<Int> {
        switch self {
        case .top1000:
            return 0..<1000
        case .top2000:
            return 1000..<2000
        case .top5000:
            return 2000..<5000
        case .top10000:
            return 5000..<10000
        }
    }

    static var groups: [(title: String, decks: [WordFrequencyDeck])] {
        [
            ("JMdict common", [.top1000, .top2000, .top5000, .top10000])
        ]
    }

    func cards(from words: [WordStudyCard]) -> [WordStudyCard] {
        Array(words[bounds.clamped(to: words.indices)])
    }
}
