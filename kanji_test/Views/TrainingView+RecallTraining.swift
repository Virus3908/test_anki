import SwiftUI

/// Диспетчеризация «обратной тренировки»: карточка, чей тип отличен от
/// рисования (для слов — отличен от карточки), рендерится как recall-карточка.
/// Прогресс идёт через те же `apply*Review`, что и в обычном режиме.
extension TrainingView {
    func recallTrainingView(for card: KanjiCard) -> some View {
        let content = recallContent(for: card)
        return recallTrainingScreen(content: content) {
            cardBackContent(
                for: card,
                onShowAllFields: { presentCardFieldSettings(side: .back) },
                onSpeak: { speech.speak(card.kanji) }
            )
        }
    }

    func recallTrainingView(for wordCard: WordStudyCard) -> some View {
        let content = recallContent(for: wordCard)
        return recallTrainingScreen(content: content) {
            studyCardBackShell(
                reviewKey: wordCard.reviewKey,
                onShowAllFields: { presentCardFieldSettings(side: .back) },
                onSpeak: { speech.speak(wordCard.word) }
            ) {
                wordFullCardContent(for: wordCard)
            }
        }
    }

    func recallTrainingView(for kanaCard: KanaStudyCard) -> some View {
        let content = recallContent(for: kanaCard)
        return recallTrainingScreen(content: content) {
            kanaCardBackContent(
                for: kanaCard,
                onShowAllFields: { presentCardFieldSettings(side: .back) },
                onSpeak: { speech.speak(kanaCard.character) }
            )
        }
    }

    // MARK: - Контент карточки

    private func recallContent(for card: KanjiCard) -> RecallCardContent {
        let readings = (card.onyomi + card.kunyomi).filter { !$0.isEmpty }
        return RecallCardContent(
            cardID: card.id,
            type: trainingSession.currentCardType,
            promptText: card.kanji,
            reading: readings.isEmpty ? nil : readings.joined(separator: ", "),
            targetMeanings: card.meanings
        )
    }

    private func recallContent(for wordCard: WordStudyCard) -> RecallCardContent {
        RecallCardContent(
            cardID: wordCard.id,
            type: trainingSession.currentCardType,
            promptText: wordCard.word,
            reading: wordCard.reading.isEmpty ? nil : wordCard.reading,
            targetMeanings: [wordCard.meaning]
        )
    }

    private func recallContent(for kanaCard: KanaStudyCard) -> RecallCardContent {
        // Для каны чтение — это и есть ответ, поэтому на фронт не подсказываем.
        RecallCardContent(
            cardID: kanaCard.id,
            type: trainingSession.currentCardType,
            promptText: kanaCard.character,
            reading: nil,
            targetMeanings: [kanaCard.reading]
        )
    }

    // MARK: - Экран

    private func recallTrainingScreen<Back: View>(
        content: RecallCardContent,
        @ViewBuilder back: () -> Back
    ) -> some View {
        ZStack {
            AppPalette.background.ignoresSafeArea()
            VStack(spacing: 0) {
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 16) {
                        headerControls()
                        recallCardBody(content: content, back: back)
                            .id(content.cardID)
                    }
                    .padding(20)
                    .padding(.bottom, 12)
                    .foregroundStyle(AppPalette.text)
                }
                .simultaneousGesture(cardSwipeGesture())
                .id(trainingSession.scrollToTopToken)

                if content.type == .flip || content.type == .audio {
                    recallRevealPanel()
                }
            }
        }
        .task(id: "speech-\(content.cardID)") {
            speakCardFrontIfNeeded(content.speechText)
        }
    }

    @ViewBuilder
    private func recallCardBody<Back: View>(
        content: RecallCardContent,
        @ViewBuilder back: () -> Back
    ) -> some View {
        switch content.type {
        case .flip, .drawing:
            trainingCardShell {
                RecallCardFront(content: content) { speech.speak(content.speechText) }
            } back: {
                back()
            }
        case .audio:
            trainingCardShell {
                RecallAudioFront(
                    content: content,
                    isSpeechAvailable: settings.speechEnabled
                ) { speech.speak(content.speechText) }
            } back: {
                back()
            }
        case .choice:
            recallChoiceCard(content: content)
        case .typed:
            recallTypedCard(content: content)
        }
    }

    /// Панель самопроверки: показать ответ (переворачивает шейлл) и оценка.
    private func recallRevealPanel() -> some View {
        VStack(spacing: 12) {
            if !drawingSession.isAnswerVisible {
                Button("Показать ответ") { revealDrawingAnswer() }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier(AccessibilityID.Training.reveal)
            }
            reviewControls()
        }
        .padding(16)
        .background(AppPalette.surface)
    }

    private func recallChoiceCard(content: RecallCardContent) -> some View {
        let correctOption = content.targetMeanings.first ?? ""
        let options = ChoiceDistractorProvider.orderedOptions(
            correct: correctOption,
            distractors: choiceDistractors(for: content),
            cardID: content.cardID,
            date: trainingSession.state.studyDay ?? Date()
        )
        return VStack(alignment: .leading, spacing: 14) {
            RecallCardFront(content: content) { speech.speak(content.speechText) }
            RecallChoicePanel(
                options: options,
                correctOption: correctOption
            ) { rating in submitRecallReview(rating) }
        }
        .padding(18)
        .appSurfaceCard()
    }

    private func recallTypedCard(content: RecallCardContent) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            RecallCardFront(content: content) { speech.speak(content.speechText) }
            RecallTypedPanel(content: content) { rating in submitRecallReview(rating) }
        }
        .padding(18)
        .appSurfaceCard()
    }

    private func choiceDistractors(for content: RecallCardContent) -> [String] {
        ChoiceDistractorProvider.options(
            for: content.cardID,
            targetMeanings: content.targetMeanings,
            pool: trainingSession.recallMeaningPool(excluding: content.cardID),
            date: trainingSession.state.studyDay ?? Date()
        )
    }

    /// Рейтинги идут теми же обёртками, что и в рисовании — сессия не знает,
    /// каким типом карточки получен ответ.
    private func submitRecallReview(_ rating: ReviewRating) {
        switch practiceMode {
        case .kanji:
            if let card = cards[safe: trainingSession.currentIndex] {
                applyReview(rating, to: card)
            }
        case .words:
            applyWordReview(rating)
        case .kana:
            applyKanaReview(rating)
        case .anki:
            break
        }
    }
}
