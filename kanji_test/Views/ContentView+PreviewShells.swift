import SwiftUI

extension ContentView {
    func deckPreviewView(for deck: KanjiDeck) -> some View {
        ZStack {
            AppPalette.background
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 14) {
                previewHeader(title: deck.title, subtitle: deckPreviewStatus, onBack: closeDeckPreview) {
                    Button {
                        isDeckSchedulePresented = true
                    } label: {
                        Image(systemName: "info.circle")
                    }
                    .buttonStyle(.bordered)
                    .tint(AppPalette.accent)
                }

                previewStartButton(count: previewCards.count, isDisabled: previewCards.isEmpty) {
                    startRandomTrainingFromPreview()
                }

                ScrollView(.vertical) {
                    LazyVGrid(columns: kanjiPreviewColumns, spacing: 10) {
                        ForEach(previewCards) { card in
                            kanjiPreviewTile(for: card)
                        }
                    }
                    .padding(.bottom, 20)
                }

                if isLoadingDeck {
                    ProgressView("Загружаю карточки")
                        .foregroundStyle(AppPalette.secondaryText)
                        .tint(AppPalette.accent)
                }
            }
            .padding(20)
            .foregroundStyle(AppPalette.text)
        }
        .sheet(item: $selectedPreviewCard, onDismiss: {
            selectedPreviewCard = nil
            previewSwipeDirection = 0
        }) { card in
            kanjiPreviewDetail(for: card)
        }
        .sheet(isPresented: $isDeckSchedulePresented) {
            deckScheduleInfoView(for: deck)
        }
    }

    func kanaPreviewView(for deck: KanaDeck) -> some View {
        ZStack {
            AppPalette.background
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 14) {
                previewHeader(title: deck.title, subtitle: kanaPreviewStatus(for: deck), onBack: closeKanaPreview)

                previewStartButton(count: previewKanaCards.count, isDisabled: previewKanaCards.isEmpty) {
                    startKanaTraining(deck: deck, cards: previewKanaCards.shuffled())
                }

                ScrollView(.vertical) {
                    LazyVGrid(columns: kanaPreviewColumns, spacing: 10) {
                        ForEach(previewKanaCards) { card in
                            kanaPreviewTile(for: card)
                        }
                    }
                    .padding(.bottom, 20)
                }

                if isLoadingDeck {
                    ProgressView("Загружаю штрихи")
                        .foregroundStyle(AppPalette.secondaryText)
                        .tint(AppPalette.accent)
                }
            }
            .padding(20)
            .foregroundStyle(AppPalette.text)
        }
        .sheet(item: $selectedKanaPreviewCard, onDismiss: {
            selectedKanaPreviewCard = nil
            previewSwipeDirection = 0
        }) { card in
            kanaPreviewDetail(for: card, deck: deck)
        }
    }

    func wordPreviewView(for deck: WordFrequencyDeck) -> some View {
        ZStack {
            AppPalette.background
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 14) {
                previewHeader(title: deck.title, subtitle: wordPreviewStatus, onBack: closeWordPreview)

                previewStartButton(count: previewWordCards.count, isDisabled: previewWordCards.isEmpty) {
                    startWordTraining(with: previewWordCards.shuffled())
                }

                ScrollView(.vertical) {
                    LazyVGrid(columns: wordPreviewColumns, spacing: 10) {
                        ForEach(previewWordCards) { card in
                            wordPreviewTile(for: card)
                        }
                    }
                    .padding(.bottom, 20)
                }

                if isLoadingDeck {
                    ProgressView("Загружаю слова")
                        .foregroundStyle(AppPalette.secondaryText)
                        .tint(AppPalette.accent)
                }
            }
            .padding(20)
            .foregroundStyle(AppPalette.text)
        }
        .sheet(item: $selectedWordPreviewCard, onDismiss: {
            selectedWordPreviewCard = nil
            selectedLinkedKanjiCard = nil
            isLinkedKanjiPresented = false
            previewSwipeDirection = 0
        }) { card in
            wordPreviewDetail(for: card, deck: deck)
        }
    }

    var kanjiPreviewColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)
    }

    var kanaPreviewColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)
    }

    var wordPreviewColumns: [GridItem] {
        [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
    }

    var wordPreviewStatus: String {
        isLoadingDeck ? "Загружаю словарь" : "\(previewWordCards.count) слов"
    }

    func kanaPreviewStatus(for deck: KanaDeck) -> String {
        isLoadingDeck ? "Загружаю штрихи из KanjiVG" : "\(previewKanaCards.count) карточек из KanjiVG"
    }

    var deckPreviewStatus: String {
        if let previewExpectedCount {
            return "\(previewCards.count) / \(previewExpectedCount) загружено"
        }

        return "\(previewCards.count) загружено"
    }

    func deckScheduleInfoView(for deck: KanjiDeck) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(deck.title)
                        .font(.title2.weight(.bold))

                    VStack(spacing: 8) {
                        ForEach(reviewStore.scheduleBuckets(for: previewCards)) { bucket in
                            HStack {
                                Text(bucket.title)
                                    .foregroundStyle(AppPalette.text)

                                Spacer()

                                Text("\(bucket.count)")
                                    .fontWeight(.semibold)
                                    .foregroundStyle(AppPalette.text)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(AppPalette.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(AppPalette.border.opacity(0.55), lineWidth: 1)
                            )
                        }
                    }
                }
                .padding(20)
            }
            .background(AppPalette.background)
            .foregroundStyle(AppPalette.text)
            .navigationTitle("Повторения")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") {
                        isDeckSchedulePresented = false
                    }
                }
            }
        }
    }

}
