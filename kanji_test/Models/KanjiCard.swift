import Foundation

struct KanjiCard: Codable, Identifiable, Sendable {
    var id: String { kanji }

    let kanji: String
    let meanings: [String]
    let onyomi: [String]
    let kunyomi: [String]
    let examples: [KanjiExample]
    let sourceMeanings: [String]?
    let sourceExamples: [KanjiExample]?
    let source: KanjiSource
    let strokes: [KanjiStroke]
    let grade: Int?
    let jlpt: Int?
    let translationState: String?

    init(
        kanji: String,
        meanings: [String],
        onyomi: [String],
        kunyomi: [String],
        examples: [KanjiExample],
        sourceMeanings: [String]? = nil,
        sourceExamples: [KanjiExample]? = nil,
        source: KanjiSource,
        strokes: [KanjiStroke],
        grade: Int? = nil,
        jlpt: Int? = nil,
        translationState: String? = nil
    ) {
        self.kanji = kanji
        self.meanings = meanings
        self.onyomi = onyomi
        self.kunyomi = kunyomi
        self.examples = examples
        self.sourceMeanings = sourceMeanings
        self.sourceExamples = sourceExamples
        self.source = source
        self.strokes = strokes
        self.grade = grade
        self.jlpt = jlpt
        self.translationState = translationState
    }

    func translated(meanings: [String], examples: [KanjiExample]) -> KanjiCard {
        KanjiCard(
            kanji: kanji,
            meanings: meanings,
            onyomi: onyomi,
            kunyomi: kunyomi,
            examples: examples,
            sourceMeanings: sourceMeanings ?? self.meanings,
            sourceExamples: sourceExamples ?? self.examples,
            source: source,
            strokes: strokes,
            grade: grade,
            jlpt: jlpt,
            translationState: "ru-system"
        )
    }
}

struct KanjiExample: Codable, Identifiable, Sendable {
    var id: String { "\(word)-\(reading)" }

    let word: String
    let reading: String
    let meaning: String
}
