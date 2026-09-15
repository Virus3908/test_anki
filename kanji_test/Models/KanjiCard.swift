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

    var englishMeanings: [String] {
        sourceMeanings ?? meanings
    }

    var englishExamples: [KanjiExample] {
        sourceExamples ?? examples
    }

    var cachedRussianMeanings: [String]? {
        russianMeanings ?? (translationState == "ru-system" ? meanings : nil)
    }

    var cachedRussianExamples: [KanjiExample]? {
        russianExamples ?? (translationState == "ru-system" ? examples : nil)
    }

    var hasRussianMeanings: Bool {
        guard let cachedRussianMeanings, !cachedRussianMeanings.isEmpty else {
            return false
        }

        return !hasSameMeanings(cachedRussianMeanings, englishMeanings)
    }

    var hasRussianExamples: Bool {
        guard !englishExamples.isEmpty else {
            return true
        }

        guard let cachedRussianExamples else {
            return false
        }

        return !hasSameExampleMeanings(cachedRussianExamples, englishExamples)
    }

    func withRussianMeanings(_ meanings: [String]) -> KanjiCard {
        KanjiCard(
            kanji: kanji,
            meanings: englishMeanings,
            onyomi: onyomi,
            kunyomi: kunyomi,
            examples: englishExamples,
            sourceMeanings: nil,
            sourceExamples: nil,
            russianMeanings: meanings,
            russianExamples: cachedRussianExamples,
            source: source,
            strokes: strokes,
            grade: grade,
            jlpt: jlpt,
            translationState: nil
        )
    }

    func withRussianExamples(_ examples: [KanjiExample]) -> KanjiCard {
        KanjiCard(
            kanji: kanji,
            meanings: englishMeanings,
            onyomi: onyomi,
            kunyomi: kunyomi,
            examples: englishExamples,
            sourceMeanings: nil,
            sourceExamples: nil,
            russianMeanings: cachedRussianMeanings,
            russianExamples: examples,
            source: source,
            strokes: strokes,
            grade: grade,
            jlpt: jlpt,
            translationState: nil
        )
    }

    func mergedForDisplay(with updatedCard: KanjiCard) -> KanjiCard {
        KanjiCard(
            kanji: updatedCard.kanji,
            meanings: updatedCard.englishMeanings,
            onyomi: updatedCard.onyomi,
            kunyomi: updatedCard.kunyomi,
            examples: updatedCard.englishExamples,
            sourceMeanings: nil,
            sourceExamples: nil,
            russianMeanings: updatedCard.cachedRussianMeanings ?? cachedRussianMeanings,
            russianExamples: updatedCard.cachedRussianExamples ?? cachedRussianExamples,
            source: updatedCard.source,
            strokes: updatedCard.strokes,
            grade: updatedCard.grade,
            jlpt: updatedCard.jlpt,
            translationState: nil
        )
    }

    var withoutTranslations: KanjiCard {
        KanjiCard(
            kanji: kanji,
            meanings: englishMeanings,
            onyomi: onyomi,
            kunyomi: kunyomi,
            examples: englishExamples,
            sourceMeanings: nil,
            sourceExamples: nil,
            russianMeanings: nil,
            russianExamples: nil,
            source: source,
            strokes: strokes,
            grade: grade,
            jlpt: jlpt,
            translationState: nil
        )
    }

    private func hasSameExampleMeanings(_ left: [KanjiExample], _ right: [KanjiExample]) -> Bool {
        guard left.count == right.count else {
            return false
        }

        return zip(left, right).allSatisfy { leftExample, rightExample in
            leftExample.meaning.trimmingCharacters(in: .whitespacesAndNewlines)
                .caseInsensitiveCompare(rightExample.meaning.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame
        }
    }

    private func hasSameMeanings(_ left: [String], _ right: [String]) -> Bool {
        guard left.count == right.count else {
            return false
        }

        return zip(left, right).allSatisfy { leftMeaning, rightMeaning in
            leftMeaning.trimmingCharacters(in: .whitespacesAndNewlines)
                .caseInsensitiveCompare(rightMeaning.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame
        }
    }
}

struct KanjiExample: Codable, Identifiable, Sendable {
    var id: String { "\(word)-\(reading)" }

    let word: String
    let reading: String
    let meaning: String
}
