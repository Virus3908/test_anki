import Foundation

nonisolated struct KanjiCard: Codable, Identifiable, Sendable {
    var id: String { kanji }

    let kanji: String
    let meanings: [String]
    let onyomi: [String]
    let kunyomi: [String]
    let examples: [KanjiExample]
    let sourceMeanings: [String]?
    let sourceExamples: [KanjiExample]?
    let russianMeanings: [String]?
    let russianExamples: [KanjiExample]?
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
        russianMeanings: [String]? = nil,
        russianExamples: [KanjiExample]? = nil,
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
        self.russianMeanings = russianMeanings
        self.russianExamples = russianExamples
        self.source = source
        self.strokes = strokes
        self.grade = grade
        self.jlpt = jlpt
        self.translationState = translationState
    }

}

nonisolated struct KanjiExample: Codable, Identifiable, Sendable {
    var id: String { "\(word)-\(reading)" }

    let word: String
    let reading: String
    let meaning: String
    let attribution: TatoebaAttribution?
    let translationAttribution: TatoebaAttribution?

    init(word: String, reading: String, meaning: String, attribution: TatoebaAttribution? = nil,
         translationAttribution: TatoebaAttribution? = nil) {
        self.word = word
        self.reading = reading
        self.meaning = meaning
        self.attribution = attribution
        self.translationAttribution = translationAttribution
    }
}
