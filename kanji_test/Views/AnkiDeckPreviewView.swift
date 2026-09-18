import SwiftUI

struct AnkiDeckPreviewView: View, StudyViewStyling {
    let deck: AnkiDeckReference
    let model: AnkiLibraryViewModel
    let settings: StudyPreferences
    let reviewStore: StudyProgressStore
    let onBack: () -> Void
    let onPractice: (PracticeSelection) -> Void
    @State private var selectedCard: AnkiStudyCard?
    @State private var showSchedule = false

    private var cards: [AnkiStudyCard] { model.previewDeck == deck ? model.previewCards : [] }

    var body: some View {
        ZStack {
            AppPalette.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 14) {
                previewHeader(title: deck.title, subtitle: "\(cards.count) карточек", onBack: onBack) {
                    Button { showSchedule = true } label: { Image(systemName: "calendar") }
                        .buttonStyle(.bordered).tint(AppPalette.accent).accessibilityLabel("Расписание повторений")
                }
                previewStartButton(count: cards.count, isDisabled: cards.isEmpty || model.isOpeningDeck) {
                    onPractice(.anki(deck, cards, guided: false))
                }
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        ForEach(cards) { card in
                            Button { selectedCard = card } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(card.displayTitle).font(.headline).lineLimit(3)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Text(card.templateName).font(.caption).foregroundStyle(AppPalette.secondaryText).lineLimit(1)
                                    Text(StudyProgressStatus(record: reviewStore.record(for: card.reviewKey), now: reviewStore.studyDate()).title)
                                        .font(.caption2).foregroundStyle(AppPalette.secondaryText)
                                }.padding(12).frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading).appSurfaceCard()
                            }.buttonStyle(.plain)
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
        .sheet(item: $selectedCard) { card in
            AnkiCardPreviewView(cards: cards, initialCard: card) { selected in
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
    }
}

private struct AnkiCardPreviewView: View, StudyViewStyling {
    let cards: [AnkiStudyCard]
    let onPractice: (AnkiStudyCard) -> Void
    @State private var index: Int
    @State private var answer = false
    @Environment(\.dismiss) private var dismiss

    init(cards: [AnkiStudyCard], initialCard: AnkiStudyCard, onPractice: @escaping (AnkiStudyCard) -> Void) {
        self.cards = cards
        self.onPractice = onPractice
        _index = State(initialValue: cards.firstIndex(where: { $0.id == initialCard.id }) ?? 0)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                if let card = cards[safe: index] {
                    AnkiCardContentView(card: card, answer: answer)
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
