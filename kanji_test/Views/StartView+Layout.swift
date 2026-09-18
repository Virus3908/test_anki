import SwiftUI

extension StartView {
    func startView() -> some View {
        ZStack {
            AppPalette.background
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 18) {
                Text("Выбери набор")
                    .font(.largeTitle.weight(.bold))

                Picker("Раздел", selection: $selectedSection) {
                    ForEach(StartMenuSection.allCases) { section in
                        Text(section.title).tag(section)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: selectedSection) { _, section in
                    if let mode = section.practiceMode {
                        practiceMode = mode
                    }
                }
                .onAppear {
                    selectedSection = StartMenuSection(rawValue: practiceMode.rawValue) ?? .kanji
                }

                Text(startSubtitle)
                    .foregroundStyle(AppPalette.secondaryText)

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        if selectedSection == .anki {
                            ankiDecksPlaceholder
                        } else if practiceMode == .kana {
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
                .mask {
                    BottomScrollMask()
                }
                .frame(maxHeight: .infinity)

                if isLoading {
                    CenteredLoadingIndicator(title: "Загружаю карточки")
                        .padding(.vertical, 10)
                }

            }
            .padding(.horizontal, 10)
            .padding(.top, 20)
            .padding(.bottom, 4)
            .foregroundStyle(AppPalette.text)
        }
    }

    var ankiDecksPlaceholder: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Колоды Anki")
                .font(.headline)
            Text("Импорт колод будет доступен здесь.")
                .font(.subheadline)
                .foregroundStyle(AppPalette.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .appSurfaceCard()
    }

}
