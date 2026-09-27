import SwiftUI

extension StartView {
    func startView() -> some View {
        ZStack {
            AppPalette.background
                .ignoresSafeArea()

            // Заголовок и подпись раздела живут в скролле и уезжают наверх.
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Выбери набор")
                        .font(.largeTitle.weight(.bold))

                    Text(startSubtitle)
                        .foregroundStyle(AppPalette.secondaryText)

                    if selectedSection == .anki {
                        AnkiLibraryView(model: ankiModel, isBusy: isLoading, onOpen: onOpen)
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
                        ForEach(visibleKanjiGroups, id: \.title) { group in
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
                .padding(.top, 8)
                // запас под закреплённый внизу переключатель и кнопку поиска
                .padding(.bottom, 150)
            }
            .mask {
                BottomScrollMask()
            }
            .padding(.horizontal, 10)
            .sheet(isPresented: $isSearchPresented) {
                cardSearchSheet()
            }

            if isLoading {
                CenteredLoadingIndicator(title: "Загружаю карточки")
                    .padding(12)
                    .appSurfaceCard()
            }

            // Нижняя плашка: единая нижняя панель — переключатель и поиск.
            VStack {
                Spacer()
                BottomActionBar {
                    sectionSwitcher

                    GlassIconButton(systemImage: "magnifyingglass",
                                    accessibilityLabel: "Поиск по всем карточкам",
                                    diameter: 52,
                                    accessibilityIdentifier: AccessibilityID.Start.search,
                                    action: openSearchIfReady)
                }
            }
        }
        .foregroundStyle(AppPalette.text)
        .toolbar(.hidden, for: .navigationBar)
        .cornerGlassControls(onOpenSettings: onOpenSettings)
    }

    /// Переключатель разделов, жёстко закреплённый внизу экрана:
    /// liquid glass капсула, по которой скользит стеклянный «бабл»
    /// (второй слой glass, без цветной заливки).
    private var sectionSwitcher: some View {
        HStack(spacing: 4) {
            ForEach(StartMenuSection.allCases) { section in
                sectionSegment(for: section)
            }
        }
        .padding(5)
        .frame(maxWidth: .infinity)
        .glassEffect(in: Capsule())
        .glassEffectTransition(.identity)
        .onChange(of: selectedSection) { _, section in
            if let mode = section.practiceMode {
                practiceMode = mode
            }
        }
        .onAppear {
            if !hasSelectedInitialSection {
                selectedSection = StartMenuSection(rawValue: practiceMode.rawValue) ?? .kanji
                hasSelectedInitialSection = true
            }
        }
    }

    private func sectionSegment(for section: StartMenuSection) -> some View {
        let isSelected = selectedSection == section

        return Button {
            guard !isSelected else { return }
            withAnimation(.snappy(duration: 0.25)) {
                selectedSection = section
            }
        } label: {
            Text(section.title)
                .font(.subheadline.weight(isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? AppPalette.text : AppPalette.secondaryText)
                .frame(maxWidth: .infinity, minHeight: 42)
                .contentShape(Rectangle())
                .background {
                    if isSelected {
                        selectionBubble
                            .matchedGeometryEffect(id: "sectionSelection", in: sectionSelectionNamespace)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier(section.accessibilityIdentifier)
    }

    private func openSearchIfReady() {
        guard !isLoading else { return }
        isSearchPresented = true
    }

    /// Glass поверх glass почти не виден (стекло не сэмплирует стекло),
    /// поэтому бабл — полупрозрачная светлая капсула с бликом-обводкой.
    private var selectionBubble: some View {
        Capsule()
            .fill(Color.primary.opacity(0.12))
            .overlay {
                Capsule().strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.12), radius: 6, y: 2)
    }

    private var visibleKanjiGroups: [(title: String, decks: [KanjiDeck])] {
        KanjiDeck.groups
    }

}
