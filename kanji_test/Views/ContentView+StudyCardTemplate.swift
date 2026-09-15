import SwiftUI

extension ContentView {
    func trainingCardShell<Front: View, Back: View>(
        @ViewBuilder front: () -> Front,
        @ViewBuilder back: () -> Back
    ) -> some View {
        ZStack {
            front()
                .opacity(isAnswerVisible ? 0 : 1)
                .rotation3DEffect(.degrees(isAnswerVisible ? 180 : 0), axis: (x: 0, y: 1, z: 0))

            ScrollView {
                back()
            }
            .opacity(isAnswerVisible ? 1 : 0)
            .rotation3DEffect(.degrees(isAnswerVisible ? 0 : -180), axis: (x: 0, y: 1, z: 0))
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .aspectRatio(1, contentMode: .fit)
        .appSurfaceCard()
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .gesture(cardSwipeGesture())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.24)) {
                isAnswerVisible.toggle()
            }
        }
    }

    func learningStatusLabel(forReviewKey key: String) -> some View {
        Text(learningStatusText(forReviewKey: key))
            .font(.caption)
            .foregroundStyle(AppPalette.mutedText)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    func learningStatusText(forReviewKey key: String) -> String {
        guard let record = reviewStore.record(for: key) else {
            return "Не изучена"
        }

        guard record.state == .review else {
            return record.state == .relearning ? "Переучивается" : "Изучается"
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dueDay = calendar.startOfDay(for: record.dueDate)
        let daysUntilReview = calendar.dateComponents([.day], from: today, to: dueDay).day ?? 0

        if daysUntilReview > 7 {
            return "Хорошо изучена"
        }

        if daysUntilReview >= 2 {
            return "Изучается"
        }

        return "На повторении"
    }
}
