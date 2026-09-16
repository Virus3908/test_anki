import Foundation

extension KanjiCard {
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
