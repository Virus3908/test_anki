import Foundation

enum KanjiAPIEndpoint {
    static func kanjiList(deck: KanjiDeck) -> URL {
        URL(string: "https://kanjiapi.dev/v1/kanji/\(deck.endpointPath)")!
    }

    static func kanjiDetail(_ kanji: String) -> URL {
        URL(string: "https://kanjiapi.dev/v1/kanji/\(kanji)")!
    }

    static func words(_ kanji: String) -> URL {
        URL(string: "https://kanjiapi.dev/v1/words/\(kanji)")!
    }

    static func kanjiVGSVG(_ kanji: String) -> URL {
        URL(string: "https://raw.githubusercontent.com/KanjiVG/kanjivg/master/kanji/\(svgFileName(for: kanji))")!
    }

    static func svgFileName(for kanji: String) -> String {
        guard let scalar = kanji.unicodeScalars.first else {
            return "00000.svg"
        }

        return String(format: "%05x.svg", scalar.value)
    }
}
