import SwiftUI

extension CardContentRendering {
    func kanjiRelatedWordsBlock(for card: KanjiCard) -> some View {
        let words = coordinator.relatedWords(for: card)
        let isLoading = coordinator.loadingRelatedWords.contains(card.id)
        let hasError = coordinator.relatedWordLoadErrors.contains(card.id)

        return VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("Слова с этим кандзи")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppPalette.secondaryText)

                Spacer()

                Button("Все", systemImage: "list.bullet") {
                    coordinator.openRelatedWordsList(for: card)
                }
                .font(.caption.weight(.semibold))
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(words) { word in
                    relatedWordLink(word)
                }

                if isLoading && words.isEmpty {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Загружаю слова")
                    }
                    .font(.caption)
                    .foregroundStyle(AppPalette.secondaryText)
                } else if hasError && words.isEmpty {
                    HStack {
                        Text("Не удалось загрузить слова")
                            .font(.caption)
                            .foregroundStyle(AppPalette.secondaryText)
                        Spacer()
                        Button("Повторить") {
                            Task { await coordinator.loadRelatedWords(for: card, force: true) }
                        }
                        .font(.caption.weight(.semibold))
                    }
                } else if coordinator.loadedRelatedWords.contains(card.id) && words.isEmpty {
                    Text("Подходящих слов в словаре нет")
                        .font(.caption)
                    .foregroundStyle(AppPalette.secondaryText)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .task(id: "related-words-\(card.id)") {
            await coordinator.loadRelatedWords(for: card)
        }
    }

    func relatedWordLink(
        _ card: WordStudyCard,
        action: (() -> Void)? = nil
    ) -> some View {
        Button {
            if let action {
                action()
            } else {
                coordinator.openLinkedWordPreview(card)
            }
        } label: {
            HStack(spacing: 8) {
                Text(card.word)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppPalette.text)

                Text(card.reading)
                    .font(.caption)
                    .foregroundStyle(AppPalette.secondaryText)
                    .lineLimit(1)

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppPalette.mutedText)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppPalette.background)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(AppPalette.border.opacity(0.55), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    func allRelatedWordsList(for card: KanjiCard) -> some View {
        @Bindable var coordinator = coordinator
        let words = coordinator.allRelatedWords(for: card)
        let isLoading = coordinator.loadingAllRelatedWords.contains(card.id)
        let hasError = coordinator.allRelatedWordLoadErrors.contains(card.id)

        return NavigationStack {
            ZStack {
                AppPalette.background
                    .ignoresSafeArea()

                if isLoading && words.isEmpty {
                    ProgressView("Загружаю все слова")
                } else if hasError && words.isEmpty {
                    VStack(spacing: 12) {
                        Text("Не удалось загрузить список слов")
                            .foregroundStyle(AppPalette.secondaryText)
                        Button("Повторить") {
                            Task { await coordinator.loadAllRelatedWords(for: card, force: true) }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(24)
                } else {
                    ScrollView(.vertical) {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            Text("Найдено: \(words.count)")
                                .font(.caption)
                                .foregroundStyle(AppPalette.secondaryText)

                            ForEach(words) { word in
                                relatedWordLink(word) {
                                    coordinator.openRelatedWordsListWord(word)
                                }
                            }
                        }
                        .padding(20)
                    }
                }
            }
            .background(AppPalette.background)
            .foregroundStyle(AppPalette.text)
            .navigationTitle("\(card.kanji): все слова")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button("Готово") { coordinator.closeRelatedWordsList() }
            }
        }
        .task(id: "all-related-words-\(card.id)") {
            await coordinator.loadAllRelatedWords(for: card)
        }
        .sheet(item: $coordinator.selectedRelatedWordsListWordCard, onDismiss: {
            coordinator.closeRelatedWordsListWord()
        }) { word in
            linkedWordPreviewDetail(for: word)
        }
    }
}
