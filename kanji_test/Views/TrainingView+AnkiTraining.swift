import SwiftUI
import AnkiImport

extension TrainingView {
    func ankiTrainingView(for card: AnkiStudyCard) -> some View {
        let speechText = ankiSpeechText(for: card)
        return ZStack {
            AppPalette.background.ignoresSafeArea()
            VStack(spacing: 16) {
                headerControls()
                AnkiCardContentView(card: card, answer: drawingSession.isAnswerVisible,
                                    translationState: translationState, language: trainingSession.options.meaningLanguage)
                    .id("\(card.id)-\(trainingSession.scrollToTopToken)")
                    .overlay(alignment: .topTrailing) {
                        if !drawingSession.isAnswerVisible, !speechText.isEmpty {
                            speakButton(for: speechText)
                                .padding(.top, 32)
                                .padding(.trailing, 6)
                        }
                    }
                learningStatusLabel(forReviewKey: card.reviewKey)
                VStack(spacing: 12) {
                    Button(drawingSession.isAnswerVisible ? "Показать вопрос" : "Показать ответ") {
                        drawingSession.isAnswerVisible.toggle()
                    }.buttonStyle(.borderedProminent).tint(AppPalette.accent)
                    reviewControls()
                }.padding(16).appSurfaceCard()
            }.padding(20).foregroundStyle(AppPalette.text)
        }
        .task(id: card.id) {
            guard !drawingSession.isAnswerVisible, !speechText.isEmpty, settings.speechEnabled else { return }
            speech.speak(speechText)
        }
    }

    private func ankiSpeechText(for card: AnkiStudyCard) -> String {
        let options = AnkiFieldDisplayPreferences.shared.options(for: card.fieldPreferencesKey,
                                                                 fieldCount: card.noteType.fields.count)
        let fields = card.note.parsedFields ?? card.note.fields.map { AnkiContentParser.parsePreservingSource($0) }
        return options.frontOrder.filter { options.frontVisible.contains($0) }
            .compactMap { fields[safe: $0]?.plainText }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
