import Foundation

nonisolated struct BundledKanjiMetadata: Decodable, Sendable {
    let kanji: String
    let meanings: [String]
    let onyomi: [String]
    let kunyomi: [String]
    let grade: Int?
    let jlpt: Int?
    let joyo: Bool
    let jinmeiyo: Bool

    func makeCard() -> KanjiCard {
        let strokes = (try? BundledKanjiVG.strokes(for: kanji)) ?? []
        let source: KanjiSource
        if strokes.isEmpty {
            source = KanjiSource(
                name: "KANJIDIC2",
                file: "kanji-metadata.json",
                license: "EDRDG / CC BY-SA 4.0"
            )
        } else {
            source = KanjiSource(
                name: "KANJIDIC2 + KanjiVG",
                file: BundledKanjiVG.fileName(for: kanji),
                license: "EDRDG / CC BY-SA 4.0; KanjiVG / CC BY-SA 3.0"
            )
        }

        return KanjiCard(
            kanji: kanji,
            meanings: meanings,
            onyomi: onyomi,
            kunyomi: kunyomi,
            examples: [],
            source: source,
            strokes: strokes,
            grade: grade,
            jlpt: jlpt
        )
    }
}
