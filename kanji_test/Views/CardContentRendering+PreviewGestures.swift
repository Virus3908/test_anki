import SwiftUI

extension CardContentRendering {
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

                guard let index = previewWordCards.firstIndex(where: { $0.id == card.id }) else {
                    return
                }

                if width < 0, let nextCard = previewWordCards[safe: index + 1] {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        coordinator.showWordPreview(nextCard, swipeDirection: -1)
                    }
                } else if width > 0, let previousCard = previewWordCards[safe: index - 1] {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        coordinator.showWordPreview(previousCard, swipeDirection: 1)
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

                guard let index = previewKanaCards.firstIndex(where: { $0.character == card.character }) else {
                    return
                }

                if width < 0, let nextCard = previewKanaCards[safe: index + 1] {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        coordinator.showKanaPreview(nextCard, swipeDirection: -1)
                    }
                } else if width > 0, let previousCard = previewKanaCards[safe: index - 1] {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        coordinator.showKanaPreview(previousCard, swipeDirection: 1)
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

                guard let index = previewKanjiCards.firstIndex(where: { $0.kanji == card.kanji }) else {
                    return
                }

                if width < 0, let nextCard = previewKanjiCards[safe: index + 1] {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        coordinator.showKanjiPreview(nextCard, swipeDirection: -1)
                    }
                } else if width > 0, let previousCard = previewKanjiCards[safe: index - 1] {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        coordinator.showKanjiPreview(previousCard, swipeDirection: 1)
                    }
                }
            }
    }

}
