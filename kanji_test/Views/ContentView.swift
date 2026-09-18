import SwiftUI

struct ContentView: View {
    @State private var appModel = StudyAppViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var model = appModel
        NavigationStack {
            screen
                .navigationTitle(appModel.navigationTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(AppPalette.background, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarColorScheme(.light, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { appModel.isSettingsPresented = true } label: { Image(systemName: "gearshape") }
                            .disabled(appModel.deckState.isLoadingDeck)
                    }
                }
                .sheet(isPresented: $model.isSettingsPresented) {
                    SettingsView(settings: appModel.settings,
                        isBusy: appModel.isSavingReview || appModel.deckState.isLoadingDeck,
                        canRestoreTranslations: appModel.translationState.canRestoreBackup,
                        onNextDay: { Task { await appModel.advanceReviewDay() } },
                        onClearCache: { Task { await appModel.clearDeckCache() } },
                        onRestoreTranslations: { Task { await appModel.translationState.restoreBackup() } },
                        initialDeck: appModel.trainingSession.deck ?? appModel.navigation.route.deck,
                        importedDecks: appModel.ankiLibrary.decks.map(\.studyDeck))
                }
                .sheet(isPresented: $model.isTodayCompletionPresented) {
                    StudyDayCompleteSheet(defaultCount: appModel.additionalCardsDefaultCount,
                                          onAddCards: appModel.addNewCardsToToday)
                        .presentationDetents([.fraction(0.5)])
                        .presentationDragIndicator(.visible)
                        .presentationBackground(AppPalette.background)
                }
                .disabled(!appModel.hasLoadedSavedState || appModel.isSavingReview || appModel.isLoadingSavedState)
                .overlay { loadingOverlay }
                .alert("Сообщение", isPresented: Binding(
                    get: { appModel.errors.message != nil },
                    set: { if !$0 { appModel.errors.message = nil } }
                )) {
                    Button("Понятно") { appModel.errors.message = nil }
                } message: { Text(appModel.errors.message ?? "") }
                .task { await appModel.loadSavedState() }
                .onChange(of: appModel.trainingSession.isActive) { appModel.synchronizeTrainingRoute() }
                .onChange(of: scenePhase) { if scenePhase == .active { Task { await appModel.resume() } } }
                .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
                    Task { await appModel.resume() }
                }
        }
    }

    @ViewBuilder private var screen: some View {
        switch appModel.navigation.route {
        case .start:
            StartView(practiceMode: Binding(get: { appModel.practiceMode }, set: { appModel.practiceMode = $0 }),
                      isLoading: appModel.deckState.isLoadingDeck, onOpen: appModel.openDeck, ankiModel: appModel.ankiLibrary)
        case .ankiDeck(let deck):
            AnkiDeckPreviewView(deck: deck, model: appModel.ankiLibrary, settings: appModel.settings,
                reviewStore: appModel.trainingSession.reviewStore,
                onBack: { appModel.ankiLibrary.closeDeck(); appModel.navigation.route = .start },
                onPractice: appModel.practice)
        case .training:
            TrainingView(trainingSession: appModel.trainingSession, settings: appModel.settings,
                         translationState: appModel.translationState, coordinator: appModel.coordinator, onPractice: appModel.practice)
        default:
            DeckPreviewView(deckState: appModel.deckState, coordinator: appModel.coordinator, settings: appModel.settings,
                            translationState: appModel.translationState, reviewStore: appModel.trainingSession.reviewStore,
                            onPractice: appModel.practice)
        }
    }

    @ViewBuilder private var loadingOverlay: some View {
        if appModel.isLoadingSavedState {
            ProgressView("Загружаю прогресс")
        } else if !appModel.hasLoadedSavedState {
            VStack(spacing: 12) {
                Text("Не удалось загрузить прогресс. Повтори загрузку, чтобы продолжить обучение.")
                    .multilineTextAlignment(.center)
                Button("Повторить") { Task { await appModel.loadSavedState() } }
                if appModel.trainingSession.canRestoreBackup {
                    Button("Восстановить последнюю резервную копию") { Task { await appModel.restoreProgressBackup() } }
                    Text("Последнее сохранённое действие может быть отменено. Исходный файл останется доступен для восстановления.")
                        .font(.caption).multilineTextAlignment(.center)
                }
            }
            .padding()
            .background(.regularMaterial)
        }
    }
}
