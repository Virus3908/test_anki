import SwiftUI

extension ContentView {
    func wordPreviewTile(for card: WordStudyCard) -> some View {
        Button {
            selectedWordPreviewCard = card
            previewSwipeDirection = 0
            isPreviewDetailPresented = true
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(card.reading)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppPalette.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(card.word)
                    .font(.system(size: 30, weight: .regular, design: .serif))
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)

                Text(displayedWordMeaning(for: card))
                    .font(.caption)
                    .foregroundStyle(AppPalette.secondaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
            .background(AppPalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppPalette.border.opacity(0.55), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    func wordPreviewDetail(for card: WordStudyCard, deck: WordFrequencyDeck) -> some View {
        NavigationStack {
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 16) {
                    wordFullCard(for: card)

                    Button {
                        selectedWordPreviewCard = nil
                        isPreviewDetailPresented = false
                        startWordTraining(with: [card])
                    } label: {
                        HStack {
                            Image(systemName: "pencil.and.scribble")
                            Text("Практиковать слово")
                                .fontWeight(.semibold)
                        }
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppPalette.accent)
                }
                .padding(20)
            }
            .background(AppPalette.background)
            .id(card.id)
            .transition(previewDetailTransition)
            .simultaneousGesture(wordPreviewCardSwipeGesture(for: card, in: deck))
        }
        .sheet(isPresented: $isLinkedKanjiPresented) {
            selectedLinkedKanjiCard = nil
        } content: {
            if let selectedLinkedKanjiCard {
                kanjiPreviewDetail(for: selectedLinkedKanjiCard)
            }
        }
    }

    func wordFullCard(for card: WordStudyCard) -> some View {
        wordFullCardContent(for: card)
            .padding(18)
            .background(AppPalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppPalette.border.opacity(0.65), lineWidth: 1)
            )
    }

    func wordFullCardContent(for card: WordStudyCard) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(spacing: 6) {
                Text(card.word)
                    .font(.system(size: 64, weight: .regular, design: .serif))
                    .foregroundStyle(AppPalette.text)
                    .minimumScaleFactor(0.42)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)

                Text(card.reading)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppPalette.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)

            detailBlock("Перевод") {
                Text(displayedWordMeaning(for: card))
                    .foregroundStyle(AppPalette.text)
                    .fixedSize(horizontal: false, vertical: true)
            }

            detailBlock("Состав") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(card.kanjiCards.indices, id: \.self) { index in
                        wordComponentLink(for: card.kanjiCards[index])
                    }
                }
            }
        }
        .task(id: "\(card.id)-\(meaningLanguage.rawValue)") {
            await translateWordMeaningIfNeeded(for: card)
        }
    }

    func wordComponentLink(for card: KanjiCard) -> some View {
        Button {
            selectedLinkedKanjiCard = card
            isLinkedKanjiPresented = true
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(card.kanji)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(AppPalette.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(wordComponentSubtitle(for: card))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppPalette.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppPalette.background)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppPalette.border.opacity(0.55), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .task(id: "word-component-\(card.id)-\(meaningLanguage.rawValue)") {
            await translateKanjiMeaningsIfNeeded(for: card, deck: selectedDeck)
        }
    }

    func wordComponentSubtitle(for card: KanjiCard) -> String {
        if let meaning = displayedKanjiMeanings(for: card).first, !meaning.isEmpty {
            return meaning
        }

        if let reading = card.kunyomi.first ?? card.onyomi.first, !reading.isEmpty {
            return reading
        }

        return "знак"
    }

}
