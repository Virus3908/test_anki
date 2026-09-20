import SwiftUI

extension TrainingView {
    func activeTrainingView() -> some View {
        @Bindable var coordinator = coordinator

        return Group {
            switch practiceMode {
            case .kanji:
                if let card = cards[safe: trainingSession.currentIndex] {
                    trainingView(for: card)
                } else {
                    sessionWaitingView()
                }
            case .words:
                if let wordCard = wordCards[safe: trainingSession.currentIndex] {
                    wordTrainingView(for: wordCard)
                } else {
                    sessionWaitingView()
                }
            case .kana:
                if let kanaCard = kanaCards[safe: trainingSession.currentIndex] {
                    kanaTrainingView(for: kanaCard)
                } else {
                    sessionWaitingView()
                }
            case .anki:
                if let card = trainingSession.currentAnkiCard {
                    ankiTrainingView(for: card)
                } else { sessionWaitingView() }
            }
        }
        .sheet(item: $coordinator.selectedLinkedKanjiCard, onDismiss: {
            coordinator.closeLinkedKanjiPreview()
        }) { card in
            kanjiPreviewDetail(for: card)
        }
        .sheet(item: $coordinator.selectedLinkedWordCard, onDismiss: {
            coordinator.closeLinkedWordPreview()
        }) { card in
            linkedWordPreviewDetail(for: card)
        }
    }

    func trainingView(for card: KanjiCard) -> some View {
        GeometryReader { proxy in
            let panelHeight = drawingPanelHeight(for: proxy.size)

            ZStack {
            AppPalette.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 16) {
                        headerControls()
                        studyCard(for: card)
                    }
                    .padding(20)
                    .padding(.bottom, 12)
                    .foregroundStyle(AppPalette.text)
                }
                .background(AppPalette.background)
                .simultaneousGesture(cardSwipeGesture())
                // Replacing the scroll view resets it to the top without racing
                // ScrollViewReader preferences against the changing card tree.
                .id(trainingSession.scrollToTopToken)

                drawingPanel(for: card, panelHeight: panelHeight)
            }
        }
        }
    }

    func wordTrainingView(for wordCard: WordStudyCard) -> some View {
        let currentKanji = currentWordKanjiCard(for: wordCard)

        return GeometryReader { proxy in
            let panelHeight = drawingPanelHeight(for: proxy.size)

            ZStack(alignment: .bottom) {
            AppPalette.background
                .ignoresSafeArea()

                VStack(spacing: 0) {
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 16) {
                    headerControls()
                    wordStudyCard(for: wordCard)
                }
                .padding(20)
                .padding(.bottom, 12)
                .foregroundStyle(AppPalette.text)
            }
            .simultaneousGesture(cardSwipeGesture())

                    if let currentKanji {
                        wordDrawingPanel(for: wordCard, currentKanji: currentKanji, panelHeight: panelHeight)
                    } else {
                        VStack(spacing: 12) {
                            if !drawingSession.isAnswerVisible {
                                Button("Показать ответ") { revealDrawingAnswer() }
                                    .buttonStyle(.borderedProminent)
                            }
                            reviewControls()
                        }
                        .padding(16)
                        .background(AppPalette.surface)
                    }
                }

                if currentKanji != nil {
                    completedWordStrip(for: wordCard)
                        .padding(.horizontal, 20)
                        .padding(.bottom, panelHeight + 10)
                        .zIndex(2)
                }
        }
        }
    }

    func kanaTrainingView(for kanaCard: KanaStudyCard) -> some View {
        GeometryReader { proxy in
            let panelHeight = drawingPanelHeight(for: proxy.size)

            ZStack {
            AppPalette.background
                .ignoresSafeArea()

                VStack(spacing: 0) {
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 16) {
                    headerControls()
                    kanaStudyCard(for: kanaCard)
                }
                .padding(20)
                .padding(.bottom, 12)
                .foregroundStyle(AppPalette.text)
            }
            .simultaneousGesture(cardSwipeGesture())

                    kanaDrawingPanel(for: kanaCard, panelHeight: panelHeight)
                }
        }
        }
    }

}
