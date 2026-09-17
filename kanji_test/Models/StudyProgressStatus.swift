import Foundation

enum StudyProgressStatus {
    case notStarted
    case learning
    case relearning
    case due
    case studying
    case wellLearned

    var title: String {
        switch self {
        case .notStarted:
            return "Не изучена"
        case .learning:
            return "Изучается"
        case .relearning:
            return "Переучивается"
        case .due:
            return "На повторении"
        case .studying:
            return "Изучается"
        case .wellLearned:
            return "Хорошо изучена"
        }
    }

    init(record: KanjiReviewRecord?, now: Date = Date()) {
        guard let record else {
            self = .notStarted
            return
        }

        guard record.state == .review else {
            self = record.state == .relearning ? .relearning : .learning
            return
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let dueDay = calendar.startOfDay(for: record.dueDate)
        let daysUntilReview = calendar.dateComponents([.day], from: today, to: dueDay).day ?? 0

        if daysUntilReview > 7 {
            self = .wellLearned
        } else if daysUntilReview > 0 {
            self = .studying
        } else {
            self = .due
        }
    }
}
