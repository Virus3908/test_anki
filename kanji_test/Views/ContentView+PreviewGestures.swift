import SwiftUI

extension ContentView {
    var previewDetailTransition: AnyTransition {
        if coordinator.previewSwipeDirection < 0 {
            return .asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading))
        }

        if coordinator.previewSwipeDirection > 0 {
            return .asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .trailing))
        }

        return .opacity
    }

    func wordPreviewCardSwipeGesture(for card: WordStudyCard, in deck: WordFrequencyDeck) -> some Gesture {
        DragGesture(minimumDistance: 35)
            .onEnded { value in
                let width = value.translation.width
                let height = value.translation.height
                guard abs(width) > abs(height) * 1.25, abs(width) > 55 else {
                    return
                }

                guard let index = deckState.previewWordCards.firstIndex(where: { $0.id == card.id }) else {
                    return
                }

                if width < 0, let nextCard = deckState.previewWordCards[safe: index + 1] {
                    coordinator.previewSwipeDirection = -1
                    withAnimation(.easeInOut(duration: 0.22)) {
                        coordinator.selectedWordPreviewCard = nextCard
                        coordinator.presentedWordPreview = PresentedWordPreview(card: nextCard)
                    }
                } else if width > 0, let previousCard = deckState.previewWordCards[safe: index - 1] {
                    coordinator.previewSwipeDirection = 1
                    withAnimation(.easeInOut(duration: 0.22)) {
                        coordinator.selectedWordPreviewCard = previousCard
                        coordinator.presentedWordPreview = PresentedWordPreview(card: previousCard)
                    }
                }
            }
    }

    func kanaPreviewCardSwipeGesture(for card: KanaStudyCard, in deck: KanaDeck) -> some Gesture {
        DragGesture(minimumDistance: 35)
            .onEnded { value in
                let width = value.translation.width
                let height = value.translation.height
                guard abs(width) > abs(height) * 1.25, abs(width) > 55 else {
                    return
                }

                guard let index = deckState.previewKanaCards.firstIndex(where: { $0.character == card.character }) else {
                    return
                }

                if width < 0, let nextCard = deckState.previewKanaCards[safe: index + 1] {
                    coordinator.previewSwipeDirection = -1
                    withAnimation(.easeInOut(duration: 0.22)) {
                        coordinator.selectedKanaPreviewCard = nextCard
                        coordinator.presentedKanaPreview = PresentedKanaPreview(card: nextCard)
                    }
                } else if width > 0, let previousCard = deckState.previewKanaCards[safe: index - 1] {
                    coordinator.previewSwipeDirection = 1
                    withAnimation(.easeInOut(duration: 0.22)) {
                        coordinator.selectedKanaPreviewCard = previousCard
                        coordinator.presentedKanaPreview = PresentedKanaPreview(card: previousCard)
                    }
                }
            }
    }

    func previewCardSwipeGesture(for card: KanjiCard) -> some Gesture {
        DragGesture(minimumDistance: 35)
            .onEnded { value in
                let width = value.translation.width
                let height = value.translation.height
                guard abs(width) > abs(height) * 1.25, abs(width) > 55 else {
                    return
                }

                guard let index = deckState.previewCards.firstIndex(where: { $0.kanji == card.kanji }) else {
                    return
                }

                if width < 0, let nextCard = deckState.previewCards[safe: index + 1] {
                    coordinator.previewSwipeDirection = -1
                    withAnimation(.easeInOut(duration: 0.22)) {
                        coordinator.selectedPreviewCard = nextCard
                        coordinator.presentedKanjiPreview = PresentedKanjiPreview(card: nextCard)
                    }
                } else if width > 0, let previousCard = deckState.previewCards[safe: index - 1] {
                    coordinator.previewSwipeDirection = 1
                    withAnimation(.easeInOut(duration: 0.22)) {
                        coordinator.selectedPreviewCard = previousCard
                        coordinator.presentedKanjiPreview = PresentedKanjiPreview(card: previousCard)
                    }
                }
            }
    }

}
