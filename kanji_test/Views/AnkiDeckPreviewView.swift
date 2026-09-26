import SwiftUI
import AnkiImport

@MainActor
struct AnkiDeckPreviewView: View, StudyViewStyling {
    let deck: AnkiDeckReference
    let model: AnkiLibraryViewModel
    let settings: StudyPreferences
    let translationState: TranslationViewModel
    let trainingSession: TrainingSessionViewModel
    let reviewStore: StudyProgressStore
    let session: CustomTrainingSession
    let onBack: () -> Void
    let onPractice: (PracticeSelection) -> Void
    var onCustomTraining: () -> Void = {}
    var onStartCustomTraining: () -> Void = {}
    @State private var selectedCard: AnkiStudyCard?
    @State private var showSchedule = false
    @State private var deckPendingDeletion: AnkiDeckReference?

    private var cards: [AnkiStudyCard] { model.previewDeck == deck ? model.previewCards : [] }
    private var plan: StudyQueuePlan {
        TrainingSessionEngine.plan(
            sourceIDs: cards.map(\.id),
            mode: .anki,
            deckID: deck.id,
            progress: reviewStore,
            options: settings.options(for: deck.id)
        )
    }

    /// Насколько хорошо карточка знается — по прогрессу основного обучения колоды;
    /// подсвечивает проблемные и освоенные карточки в сетке превью.
    private func cardMastery(for card: AnkiStudyCard) -> CardMastery {
        CardMastery(record: reviewStore.record(for: card.reviewKey),
                    isExcluded: reviewStore.isExcluded(card.reviewKey))
    }
    private let fieldPreferences = AnkiFieldDisplayPreferences.shared

    /// В режиме выбора карточек кнопка «назад» сначала выходит из выбора,
    /// а закрывает колоду только при повторном нажатии.
    private func exitSelectionOrClose() {
        if session.isSelecting { session.cancelSelection() } else { onBack() }
    }

    var body: some View {
        ZStack {
            AppPalette.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 14) {
                previewHeader(title: deck.title, subtitle: "\(cards.count) карточек", onBack: exitSelectionOrClose) {
                    if !session.isSelecting {
                        Button { showSchedule = true } label: { Image(systemName: "calendar") }
                            .buttonStyle(.bordered).tint(AppPalette.accent).accessibilityLabel("Расписание повторений")
                    }
                    Button(role: .destructive) {
                        deckPendingDeletion = deck
                    } label: {
                        Image(systemName: "trash")
                            .accessibilityLabel("Удалить импорт с колодой \(deck.title)")
                    }
                    .buttonStyle(.borderless)
                    .disabled(model.isOpeningDeck || model.isDeletingDeck)
                }

                if session.isSelecting {
                    CustomSelectionToolbar(session: session, cardIDs: cards.map(\.id))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                if !session.isSelecting {
                    previewStartButton(
                        plan: plan,
                        isDisabled: cards.isEmpty || model.isOpeningDeck,
                        action: { onPractice(.anki(deck, cards, guided: false)) },
                        onCustomTraining: onCustomTraining
                    )
                }
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        ForEach(cards) { card in
                            Button {
                                if session.isSelecting { session.toggle(card.id) } else { selectedCard = card }
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(card.displayTitle(using: fieldPreferences.options(for: card.fieldPreferencesKey, fieldCount: card.noteType.fields.count)))
                                        .font(.headline).lineLimit(3)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Text(card.templateName).font(.caption).foregroundStyle(AppPalette.secondaryText).lineLimit(1)
                                    Text(StudyProgressStatus(
                                        record: reviewStore.record(for: card.reviewKey),
                                        isExcluded: reviewStore.isExcluded(card.reviewKey)
                                    ).title)
                                        .font(.caption2).foregroundStyle(AppPalette.secondaryText)
                                }.padding(12).frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading).appSurfaceCard()
                            }.buttonStyle(.plain)
                            .cardMasteryChrome(cardMastery(for: card))
                            .customSelectionChrome(isSelecting: session.isSelecting,
                                                   isSelected: session.selectedIDs.contains(card.id))
                        }
                    }.padding(.horizontal, 4).padding(.bottom, 44)
                }.mask { BottomScrollMask() }.frame(maxHeight: .infinity)
                if model.isOpeningDeck { CenteredLoadingIndicator(title: "Загружаю карточки") }
                if let error = model.loadError {
                    Text(error).font(.caption).foregroundStyle(AppPalette.correction)
                    Button("Повторить") { Task { await model.openDeck(deck) } }
                }
            }
            .padding(.horizontal, 12).padding(.top, 20).padding(.bottom, 4).foregroundStyle(AppPalette.text)
        }
        .safeAreaInset(edge: .bottom) {
            if session.isSelecting {
                CustomSelectionBar(session: session, onStart: onStartCustomTraining)
            }
        }
        .sheet(item: $selectedCard) { card in
            AnkiCardPreviewView(cards: cards, initialCard: card, translationState: translationState,
                                language: settings.options(for: deck.id).meaningLanguage) { selected in
                selectedCard = nil
                onPractice(.anki(deck, [selected], guided: true))
            }
        }
        .sheet(isPresented: $showSchedule) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(deck.title).font(.title2.weight(.bold))
                        let plan = TrainingSessionEngine.plan(sourceIDs: cards.map(\.id), mode: .anki, deckID: deck.id,
                            progress: reviewStore, options: settings.options(for: deck.id))
                        Text("На сегодня: \(plan.todayIDs.count)").font(.headline)
                        ForEach(reviewStore.scheduleBuckets(forReviewKeys: Set(cards.map(\.reviewKey)))) { bucket in
                            HStack { Text(bucket.title); Spacer(); Text("\(bucket.count)").fontWeight(.semibold) }
                                .padding(12).appSurfaceCard()
                        }
                    }.padding(20)
                }.background(AppPalette.background).foregroundStyle(AppPalette.text)
                    .navigationTitle("Повторения").navigationBarTitleDisplayMode(.inline)
                    .toolbar { Button("Готово") { showSchedule = false } }
            }
        }
        .alert("Удалить весь импорт?", isPresented: Binding(
            get: { deckPendingDeletion != nil },
            set: { if !$0 { deckPendingDeletion = nil } }
        ), presenting: deckPendingDeletion) { deck in
            Button("Удалить", role: .destructive) {
                deckPendingDeletion = nil
                Task {
                    if await model.deleteImport(deck, trainingSession: trainingSession) {
                        onBack()
                    }
                }
            }
            Button("Отмена", role: .cancel) {
                deckPendingDeletion = nil
            }
        } message: { deck in
            let summary = model.imports.first { $0.id == deck.importID }
            Text("Файл «\(summary?.filename ?? deck.title)» и все его колоды (\(summary?.decks.count ?? 1)) будут удалены вместе с карточками, медиа и прогрессом.")
        }
    }
}

struct AnkiCardPreviewView: View, StudyViewStyling {
    let cards: [AnkiStudyCard]
    let onPractice: (AnkiStudyCard) -> Void
    let translationState: TranslationViewModel
    let language: MeaningLanguage
    @State private var index: Int
    @State private var answer = false
    @Environment(\.dismiss) private var dismiss

    init(cards: [AnkiStudyCard], initialCard: AnkiStudyCard, translationState: TranslationViewModel,
         language: MeaningLanguage, onPractice: @escaping (AnkiStudyCard) -> Void) {
        self.cards = cards
        self.onPractice = onPractice
        self.translationState = translationState
        self.language = language
        _index = State(initialValue: cards.firstIndex(where: { $0.id == initialCard.id }) ?? 0)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                if let card = cards[safe: index] {
                    AnkiCardContentView(card: card, answer: answer, translationState: translationState, language: language)
                    HStack {
                        Button { index -= 1; answer = false } label: { Image(systemName: "chevron.left") }
                            .disabled(index == 0).accessibilityLabel("Предыдущая карточка")
                        Spacer()
                        Button(answer ? "Показать вопрос" : "Показать ответ") { answer.toggle() }
                        Spacer()
                        Button { index += 1; answer = false } label: { Image(systemName: "chevron.right") }
                            .disabled(index + 1 == cards.count).accessibilityLabel("Следующая карточка")
                    }.buttonStyle(.bordered).tint(AppPalette.accent)
                    primaryActionButton(title: "Практиковать эту карточку", systemImage: "rectangle.on.rectangle") { onPractice(card) }
                }
            }.padding(20).background(AppPalette.background).foregroundStyle(AppPalette.text)
                .navigationTitle("\(index + 1) / \(cards.count)").navigationBarTitleDisplayMode(.inline)
                .toolbar { Button("Готово") { dismiss() } }
        }
    }
}
