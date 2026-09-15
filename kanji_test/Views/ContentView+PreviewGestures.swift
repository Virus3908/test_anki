import SwiftUI

extension ContentView {
    var previewDetailTransition: AnyTransition {
        if previewSwipeDirection < 0 {
            return .asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading))
        }

        if previewSwipeDirection > 0 {
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
                    previewSwipeDirection = -1
                    withAnimation(.easeInOut(duration: 0.22)) {
                        selectedWordPreviewCard = nextCard
                    }
                } else if width > 0, let previousCard = previewWordCards[safe: index - 1] {
                    previewSwipeDirection = 1
                    withAnimation(.easeInOut(duration: 0.22)) {
                        selectedWordPreviewCard = previousCard
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
                    previewSwipeDirection = -1
                    withAnimation(.easeInOut(duration: 0.22)) {
                        selectedKanaPreviewCard = nextCard
                    }
                } else if width > 0, let previousCard = previewKanaCards[safe: index - 1] {
                    previewSwipeDirection = 1
                    withAnimation(.easeInOut(duration: 0.22)) {
                        selectedKanaPreviewCard = previousCard
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

                guard let index = previewCards.firstIndex(where: { $0.kanji == card.kanji }) else {
                    return
                }

                if width < 0, let nextCard = previewCards[safe: index + 1] {
                    previewSwipeDirection = -1
                    withAnimation(.easeInOut(duration: 0.22)) {
                        selectedPreviewCard = nextCard
                    }
                } else if width > 0, let previousCard = previewCards[safe: index - 1] {
                    previewSwipeDirection = 1
                    withAnimation(.easeInOut(duration: 0.22)) {
                        selectedPreviewCard = previousCard
                    }
                }
            }
    }

}
