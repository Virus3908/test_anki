enum StudyProgressStatus {
    case new
    case learning
    case review
    case relearning
    case excluded

    var title: String {
        switch self {
        case .new:
            return "Не изучена"
        case .learning:
            return "Изучается"
        case .review:
            return "Изучена"
        case .relearning:
            return "Переучивается"
        case .excluded:
            return "Исключена"
        }
    }

    init(record: StudyReviewRecord?, isExcluded: Bool) {
        if isExcluded {
            self = .excluded
            return
        }

        guard let record else {
            self = .new
            return
        }

        switch record.state {
        case .learning:
            self = .learning
        case .review:
            self = .review
        case .relearning:
            self = .relearning
        }
    }
}
