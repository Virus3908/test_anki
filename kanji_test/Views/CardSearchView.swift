import SwiftUI

/// Экран поиска карточек — sheet из шапки превью колоды.
///
/// Тайлы и превью те же, что в превью колод. Нажатия по тайлам открывают
/// linked-превью: оно не зависит от выбранной колоды, поэтому подходит
/// для карточек, найденных по всему приложению.
struct CardSearchView: View, CardContentRendering {
    let deckID: String? = nil
    let coordinator: StudyCoordinator
    let settings: StudyPreferences
    let translationState: TranslationViewModel
    let reviewStore: StudyProgressStore
    let onPractice: (PracticeSelection) -> Void

    @State private var model: CardSearchViewModel
    @State private var query = ""
    @Environment(\.dismiss) private var dismiss

    init(
        scope: CardSearchViewModel.Scope,
        coordinator: StudyCoordinator,
        settings: StudyPreferences,
        translationState: TranslationViewModel,
        reviewStore: StudyProgressStore,
        onPractice: @escaping (PracticeSelection) -> Void
    ) {
        self.coordinator = coordinator
        self.settings = settings
        self.translationState = translationState
        self.reviewStore = reviewStore
        self.onPractice = onPractice
        _model = State(initialValue: CardSearchViewModel(scope: scope, translationState: translationState))
    }

    var body: some View {
        @Bindable var coordinator = coordinator

        return ZStack {
            AppPalette.background
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 14) {
                previewHeader(title: "Поиск", subtitle: subtitle, onBack: { dismiss() })

                searchField

                if model.isPreparing {
                    CenteredLoadingIndicator(title: "Готовлю поиск")
                        .padding(.vertical, 10)
                } else if let error = model.loadError {
                    Text(error).font(.caption).foregroundStyle(AppPalette.correction)
                    Button("Повторить") { Task { await model.prepare() } }
                } else {
                    resultSummary

                    ScrollView(.vertical) {
                        LazyVGrid(columns: resultColumns, spacing: 10) {
                            ForEach(model.kanjiResults) { card in
                                kanjiPreviewTile(for: card) {
                                    coordinator.openLinkedKanjiPreview(card)
                                }
                            }
                            ForEach(model.wordResults) { card in
                                wordPreviewTile(for: card) {
                                    coordinator.openLinkedWordPreview(card)
                                }
                            }
                        }
                        .padding(.horizontal, 4)
                        .padding(.bottom, 44)
                    }
                    .mask { BottomScrollMask() }
                    .frame(maxHeight: .infinity)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 20)
            .padding(.bottom, 4)
            .foregroundStyle(AppPalette.text)
        }
        .task {
            await model.prepare()
            // Пользователь мог начать печатать, пока готовился индекс.
            model.updateResults(for: query)
        }
        .task(id: query) {
            guard !query.isEmpty else {
                model.updateResults(for: query)
                return
            }
            // Небольшая пауза склеивает быстрые нажатия в один поиск.
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            model.updateResults(for: query)
        }
        .sheet(item: $coordinator.selectedLinkedKanjiCard, onDismiss: {
            coordinator.closeLinkedKanjiPreview()
        }) { card in
            kanjiPreviewDetail(for: card)
        }
        .sheet(item: $coordinator.selectedLinkedWordCard, onDismiss: {
            coordinator.closeLinkedWordPreview()
        }) { word in
            linkedWordPreviewDetail(for: word)
        }
    }

    // MARK: Шапка и поле

    private var subtitle: String {
        model.scope == .kanji ? "Все кандзи, все колоды" : "Все слова, все уровни частотности"
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AppPalette.secondaryText)

            TextField(model.scope == .kanji ? "Кандзи, значение или чтение" : "Слово, чтение или значение", text: $query)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.search)

            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .foregroundStyle(AppPalette.mutedText)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .appSurfaceCard()
    }

    private var resultSummary: some View {
        Text(query.isEmpty ? "Начните вводить запрос" : resultSummaryText)
            .font(.caption)
            .foregroundStyle(AppPalette.secondaryText)
    }

    private var resultSummaryText: String {
        var text = "Найдено: \(model.totalFound)"
        if model.totalFound > CardSearchViewModel.resultLimit {
            text += " (показаны первые \(CardSearchViewModel.resultLimit))"
        }
        return text
    }

    // MARK: Сетка

    private var resultColumns: [GridItem] {
        let column = GridItem(.flexible(), spacing: 10)
        return model.scope == .kanji ? Array(repeating: column, count: 4) : Array(repeating: column, count: 2)
    }
}
