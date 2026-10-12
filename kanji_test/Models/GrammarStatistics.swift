import Foundation

nonisolated struct GrammarStatistics: Sendable {
    let total: Int
    let new: Int
    let learning: Int
    let relearning: Int
    let review: Int
    let due: Int
    let excluded: Int
    var introduced: Int { total - new - excluded }

    init(rules: [GrammarRule], progress: StudyProgressStore, now: Date = Date()) {
        total = rules.count
        var new = 0, learning = 0, relearning = 0, review = 0, due = 0, excluded = 0
        for rule in rules {
            if progress.isExcluded(rule.reviewKey) { excluded += 1; continue }
            guard let record = progress.record(for: rule.reviewKey) else {
                if progress.firstShownAt[rule.reviewKey] != nil { learning += 1 } else { new += 1 }
                continue
            }
            switch record.state {
            case .learning: learning += 1
            case .relearning: relearning += 1
            case .review: review += 1
            }
            if progress.isDue(record, now: now) { due += 1 }
        }
        self.new = new; self.learning = learning; self.relearning = relearning
        self.review = review; self.due = due; self.excluded = excluded
    }

    static func status(_ rule: GrammarRule, progress: StudyProgressStore) -> String {
        if progress.isExcluded(rule.reviewKey) { return "Исключено" }
        guard let record = progress.record(for: rule.reviewKey) else {
            return progress.firstShownAt[rule.reviewKey] == nil ? "Не изучено" : "В процессе изучения"
        }
        switch record.state {
        case .learning: return "В процессе изучения"
        case .relearning: return "Повторное обучение"
        case .review: return "На повторении"
        }
    }
}
