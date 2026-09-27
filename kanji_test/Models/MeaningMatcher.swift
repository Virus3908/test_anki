import Foundation

/// Result of comparing a typed answer against a card's known meanings.
nonisolated enum MeaningMatchOutcome: Equatable, Sendable {
    case exact
    case nearMiss
    case none
}

/// Free-recall answer checking: normalizes text and accepts small typos so
/// typing a meaning is graded by closeness, not byte equality.
nonisolated enum MeaningMatcher {
    /// Maximum edit distance still counted as a typo.
    private static let typoTolerance = 2

    /// Meanings shorter than this never count as a near miss — with few
    /// characters almost any input is "close".
    private static let nearMissMinimumLength = 5

    static func outcome(for input: String, meanings: [String]) -> MeaningMatchOutcome {
        let normalizedInput = normalized(input)
        guard !normalizedInput.isEmpty else { return .none }

        let normalizedMeanings = meanings.map(normalized).filter { !$0.isEmpty }
        if normalizedMeanings.contains(normalizedInput) {
            return .exact
        }
        for meaning in normalizedMeanings where meaning.count >= nearMissMinimumLength {
            if levenshtein(normalizedInput, meaning) <= typoTolerance {
                return .nearMiss
            }
        }
        return .none
    }

    /// Case-insensitive, ё/е-insensitive, punctuation-free, whitespace-collapsed.
    static func normalized(_ text: String) -> String {
        let lowered = text.lowercased().replacingOccurrences(of: "ё", with: "е")
        let withoutPunctuation = String(String.UnicodeScalarView(
            lowered.unicodeScalars.filter { !CharacterSet.punctuationCharacters.contains($0) }
        ))
        return withoutPunctuation
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    static func levenshtein(_ a: String, _ b: String) -> Int {
        let aChars = Array(a)
        let bChars = Array(b)
        guard !aChars.isEmpty else { return bChars.count }
        guard !bChars.isEmpty else { return aChars.count }

        var previousRow = Array(0...bChars.count)
        var currentRow = [Int](repeating: 0, count: bChars.count + 1)

        for (aIndex, aChar) in aChars.enumerated() {
            currentRow[0] = aIndex + 1
            for bIndex in 1...bChars.count {
                let substitutionCost = aChar == bChars[bIndex - 1] ? 0 : 1
                currentRow[bIndex] = min(
                    previousRow[bIndex] + 1,
                    currentRow[bIndex - 1] + 1,
                    previousRow[bIndex - 1] + substitutionCost
                )
            }
            swap(&previousRow, &currentRow)
        }
        return previousRow[bChars.count]
    }
}
