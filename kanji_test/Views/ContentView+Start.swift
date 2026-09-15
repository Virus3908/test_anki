import SwiftUI

extension ContentView {
    func startView() -> some View {
        ZStack {
            AppPalette.background
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 18) {
                Text("Выбери набор")
                    .font(.largeTitle.weight(.bold))

                Picker("Режим", selection: $practiceMode) {
                    ForEach(PracticeMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                HStack(alignment: .top, spacing: 12) {
                    Text(startSubtitle)
                        .foregroundStyle(AppPalette.secondaryText)

                    Spacer()

                    Button {
                        clearDeckCache()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.bordered)
                    .tint(AppPalette.correction)
                    .disabled(isLoadingDeck)
                }

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
                }

                if isLoadingDeck {
                    ProgressView("Скачиваю и кэширую \(selectedDeck.title)")
                        .foregroundStyle(AppPalette.secondaryText)
                        .tint(AppPalette.accent)
                }

                Spacer()
            }
            .padding(20)
            .foregroundStyle(AppPalette.text)
        }
    }

}
