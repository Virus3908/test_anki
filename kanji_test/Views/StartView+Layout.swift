import SwiftUI

extension StartView {
    func startView() -> some View {
        ZStack {
            AppPalette.background
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 18) {
                Text("Выбери набор")
                    .font(.largeTitle.weight(.bold))

                Picker("Режим", selection: practiceModeBinding) {
                    ForEach(PracticeMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Text(startSubtitle)
                    .foregroundStyle(AppPalette.secondaryText)

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        if practiceMode == .kana {
                            ForEach(KanaDeck.allCases) { deck in
                                kanaDeckButton(for: deck)
                            }
                        } else if practiceMode == .words {
                            ForEach(WordFrequencyDeck.groups, id: \.title) { group in
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(group.title)
                                        .font(.headline)
                                        .foregroundStyle(AppPalette.secondaryText)

                                    VStack(spacing: 10) {
                                        ForEach(group.decks) { deck in
                                            wordDeckButton(for: deck)
                                        }
                                    }
                                }
                            }
                        } else {
                            ForEach(KanjiDeck.groups, id: \.title) { group in
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(group.title)
                                        .font(.headline)
                                        .foregroundStyle(AppPalette.secondaryText)

                                    VStack(spacing: 10) {
                                        ForEach(group.decks) { deck in
                                            deckButton(for: deck)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.bottom, 44)
                }
                .overlay(alignment: .bottom) {
                    DeckListBottomFade()
                }
                .frame(maxHeight: .infinity)

                if isLoading {
                    ProgressView("Загружаю карточки")
                        .foregroundStyle(AppPalette.secondaryText)
                        .tint(AppPalette.accent)
                }

            }
            .padding(.horizontal, 10Теп)
            .padding(.top, 20)
            .padding(.bottom, 4)
            .foregroundStyle(AppPalette.text)
        }
    }

}

private struct DeckListBottomFade: View {
    var body: some View {
        LinearGradient(
            colors: [.clear, AppPalette.background],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 44)
        .allowsHitTesting(false)
    }
}
