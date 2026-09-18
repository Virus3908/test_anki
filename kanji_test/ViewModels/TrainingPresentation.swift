import Foundation
import Observation

@MainActor @Observable
final class TrainingPresentation {
    let drawing = DrawingSessionViewModel()
    private(set) var revision = 0

    func reset() {
        drawing.resetWordDrawingState()
        drawing.resetCurrentAnswer()
        revision += 1
    }

    static func intervalLabel(_ record: StudyReviewRecord?, now: Date) -> String {
        guard let record else { return "—" }
        if record.intervalDays >= 1 { return "\(Int(record.intervalDays)) дн." }
        let minutes = max(1, Int(ceil(record.dueDate.timeIntervalSince(now) / 60)))
        return minutes < 60 ? "\(minutes) мин." : "\(minutes / 60) ч."
    }
}
