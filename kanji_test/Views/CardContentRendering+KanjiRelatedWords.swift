import SwiftUI

extension CardContentRendering {
    func kanjiRelatedWordsBlock(for card: KanjiCard) -> some View {
        let words = coordinator.relatedWords(for: card)
        let isLoading = coordinator.loadingRelatedWords.contains(card.id)
        let hasError = coordinator.relatedWordLoadErrors.contains(card.id)

        return detailBlock("Слова с этим кандзи") {
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
        }
        .task(id: "related-words-\(card.id)") {
            await coordinator.loadRelatedWords(for: card)
        }
    }

    func relatedWordLink(_ card: WordStudyCard) -> some View {
        Button {
            coordinator.openLinkedWordPreview(card)
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
}
