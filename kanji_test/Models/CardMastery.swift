import Foundation
import FSRS

/// Насколько хорошо карточка знается прямо сейчас — свёртка состояния
/// основного обучения колоды в одно число для подсветки на экране выбора.
/// 1 — уверенно знает, 0 — проваливается; `untrained` — карточку ещё не тренировали.
nonisolated enum CardMastery: Equatable, Sendable {
    case untrained
    case score(Double)
    case excluded

    init(record: StudyReviewRecord?, isExcluded: Bool, now: Date = .now) {
        if isExcluded {
            self = .excluded
        } else if let record, record.attempts > 0 {
            self = .score(Self.recallProbability(of: record, now: now))
        } else {
            self = .untrained
        }
    }

    /// Кривая забывания FSRS-6 R(t, S) = (1 + factor·t/S)^decay — вероятность
    /// вспомнить сейчас, — взвешенная сложностью карточки. У обучающих шагов
    /// стабильность ещё не осмысленна: им фиксированные середина и дно.
    private static func recallProbability(of record: StudyReviewRecord, now: Date) -> Double {
        switch record.state {
        case .learning:
            return 0.45
        case .relearning:
            return 0.2
        case .review:
            let elapsedDays = elapsedDays(since: record.lastReviewedAt, now: now)
            let recall = pow(1 + factor * elapsedDays / max(record.stability, 0.1), decay)
            let difficultyPenalty = 1 - 0.55 * (record.difficulty - 1) / 9
            return min(max(recall * difficultyPenalty, 0), 1)
        }
    }

    /// Константы кривой — из тех же стандартных весов FSRS-6, что использует планировщик.
    private static let decay = -FSRSDefaults.defaultWv6[20]
    private static let factor = exp(log(0.9) / decay) - 1

    private static func elapsedDays(since date: Date, now: Date) -> Double {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day],
                                           from: calendar.startOfDay(for: date),
                                           to: calendar.startOfDay(for: now)).day ?? 0
        return max(0, Double(days))
    }
}
