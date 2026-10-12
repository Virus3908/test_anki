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

nonisolated struct KanjiExample: Codable, Identifiable, Sendable, Equatable {
    var id: String { attribution.map { "tatoeba-\($0.sentenceID)" } ?? "\(word)-\(reading)" }

    let word: String
    let reading: String
    let meaning: String
    let attribution: TatoebaAttribution?
    let translationAttribution: TatoebaAttribution?
    var furigana: ExampleFurigana?

    init(word: String, reading: String, meaning: String, attribution: TatoebaAttribution? = nil,
         translationAttribution: TatoebaAttribution? = nil, furigana: ExampleFurigana? = nil) {
        self.word = word
        self.reading = reading
        self.meaning = meaning
        self.attribution = attribution
        self.translationAttribution = translationAttribution
        self.furigana = furigana
    }
}

extension KanjiExample {
    nonisolated private enum CodingKeys: String, CodingKey {
        case word, reading, meaning, attribution, translationAttribution, furigana
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        word = try container.decode(String.self, forKey: .word)
        reading = try container.decode(String.self, forKey: .reading)
        meaning = try container.decode(String.self, forKey: .meaning)
        attribution = try container.decodeIfPresent(TatoebaAttribution.self, forKey: .attribution)
        translationAttribution = try container.decodeIfPresent(TatoebaAttribution.self, forKey: .translationAttribution)
        furigana = try? container.decodeIfPresent(ExampleFurigana.self, forKey: .furigana)
    }
}
