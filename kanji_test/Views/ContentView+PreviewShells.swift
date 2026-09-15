import SwiftUI

extension ContentView {
    func deckPreviewView(for deck: KanjiDeck) -> some View {
        ZStack {
            AppPalette.background
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Button("", systemImage: "chevron.left") {
                        closeDeckPreview()
                    }
                    .buttonStyle(.bordered)
                    .tint(AppPalette.accent)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(deck.title)
                            .font(.title2.weight(.bold))
                        Text(deckPreviewStatus)
                            .font(.caption)
                            .foregroundStyle(AppPalette.secondaryText)
                    }

                    Spacer()
                }

                Button {
                    startRandomTrainingFromPreview()
                } label: {
                    HStack {
                        Image(systemName: "shuffle")
                        Text("Начать тренировку")
                            .fontWeight(.semibold)
                        Spacer()
                        Text("\(previewCards.count)")
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(Color.white)
                    .padding(14)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppPalette.accent)
                .disabled(previewCards.isEmpty)

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
        .sheet(isPresented: $isPreviewDetailPresented) {
            selectedPreviewCard = nil
            previewSwipeDirection = 0
        } content: {
            if let selectedPreviewCard {
                kanjiPreviewDetail(for: selectedPreviewCard)
            }
        }
    }

    func kanaPreviewView(for deck: KanaDeck) -> some View {
        ZStack {
            AppPalette.background
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Button("", systemImage: "chevron.left") {
                        closeKanaPreview()
                    }
                    .buttonStyle(.bordered)
                    .tint(AppPalette.accent)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(deck.title)
                            .font(.title2.weight(.bold))
                        Text(kanaPreviewStatus(for: deck))
                            .font(.caption)
                            .foregroundStyle(AppPalette.secondaryText)
                    }

                    Spacer()
                }

                Button {
                    startKanaTraining(deck: deck, cards: previewKanaCards.shuffled())
                } label: {
                    HStack {
                        Image(systemName: "shuffle")
                        Text("Начать тренировку")
                            .fontWeight(.semibold)
                        Spacer()
                        Text("\(previewKanaCards.count)")
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(Color.white)
                    .padding(14)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppPalette.accent)
                .disabled(previewKanaCards.isEmpty)

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
        .sheet(isPresented: $isPreviewDetailPresented) {
            selectedKanaPreviewCard = nil
            previewSwipeDirection = 0
        } content: {
            if let selectedKanaPreviewCard {
                kanaPreviewDetail(for: selectedKanaPreviewCard, deck: deck)
            }
        }
    }

    func wordPreviewView(for deck: WordFrequencyDeck) -> some View {
        ZStack {
            AppPalette.background
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Button("", systemImage: "chevron.left") {
                        closeWordPreview()
                    }
                    .buttonStyle(.bordered)
                    .tint(AppPalette.accent)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(deck.title)
                            .font(.title2.weight(.bold))
                        Text(wordPreviewStatus)
                            .font(.caption)
                            .foregroundStyle(AppPalette.secondaryText)
                    }

                    Spacer()
                }

                Button {
                    startWordTraining(with: previewWordCards.shuffled())
                } label: {
                    HStack {
                        Image(systemName: "shuffle")
                        Text("Начать тренировку")
                            .fontWeight(.semibold)
                        Spacer()
                        Text("\(previewWordCards.count)")
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(Color.white)
                    .padding(14)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppPalette.accent)
                .disabled(previewWordCards.isEmpty)

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
        .sheet(isPresented: $isPreviewDetailPresented) {
            selectedWordPreviewCard = nil
            selectedLinkedKanjiCard = nil
            isLinkedKanjiPresented = false
            previewSwipeDirection = 0
        } content: {
            if let selectedWordPreviewCard {
                wordPreviewDetail(for: selectedWordPreviewCard, deck: deck)
            }
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

}
