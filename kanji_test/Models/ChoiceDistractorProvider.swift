import Foundation

/// Builds the wrong options for a multiple-choice card: unique meanings from
/// the same deck, never a hidden alternate meaning of the target card, picked
/// deterministically so the options survive re-renders within a day.
nonisolated enum ChoiceDistractorProvider {
    static func options(
        for cardID: String,
        targetMeanings: [String],
        pool: [String],
        date: Date,
        count: Int = 3
    ) -> [String] {
        guard count > 0 else { return [] }

        let excludedMeanings = Set(targetMeanings.map(MeaningMatcher.normalized))
        var seenMeanings = Set<String>()
        var candidates: [String] = []
        for meaning in pool {
            let key = MeaningMatcher.normalized(meaning)
            guard !key.isEmpty, !excludedMeanings.contains(key), !seenMeanings.contains(key) else { continue }
            seenMeanings.insert(key)
            candidates.append(meaning)
        }
        guard !candidates.isEmpty else { return [] }

        let dayOrdinal = Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0
        var seed = stableHash("\(cardID)|\(dayOrdinal)")

        var selected: [String] = []
        var remaining = candidates
        while !remaining.isEmpty && selected.count < count {
            seed = nextSeed(seed)
            let index = Int(seed % UInt64(remaining.count))
            selected.append(remaining.remove(at: index))
        }
        return selected
    }

    /// Детерминированно перемешивает правильный вариант с дистракторами,
    /// чтобы порядок кнопок не «прыгал» при перерисовках в течение дня.
    static func orderedOptions(correct: String, distractors: [String], cardID: String, date: Date) -> [String] {
        var options = distractors
        options.append(correct)
        guard options.count > 1 else { return options }

        let dayOrdinal = Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0
        var seed = stableHash("order|\(cardID)|\(dayOrdinal)")
        for index in (1..<options.count).reversed() {
            seed = nextSeed(seed)
            options.swapAt(index, Int(seed % UInt64(index + 1)))
        }
        return options
    }

    /// FNV-1a: stable across launches, unlike `String.hashValue`.
    private static func stableHash(_ text: String) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in text.utf8 {
            hash = (hash ^ UInt64(byte)) &* 0x100000001b3
        }
        return hash
    }

    /// Linear congruential step to advance the seed between picks.
    private static func nextSeed(_ seed: UInt64) -> UInt64 {
        seed &* 6364136223846793005 &+ 1442695040888963407
    }
}
