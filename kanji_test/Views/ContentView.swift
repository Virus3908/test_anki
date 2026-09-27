import SwiftUI

struct ContentView: View {
    @State private var appModel = Self.makeAppModel()
    @Environment(\.scenePhase) private var scenePhase

    private static func makeAppModel() -> StudyAppViewModel {
        #if DEBUG
        if UITestingLaunch.isActive { return .makeForUITesting() }
        #endif
        return StudyAppViewModel()
    }

    var body: some View {
        @Bindable var model = appModel
        @Bindable var navigation = appModel.navigation
        ZStack {
            NavigationStack(path: $navigation.path) {
                startScreen
                    .navigationDestination(for: StudyRoute.self, destination: deckScreen)
                    .interactivePopGesture(isEnabled: isSwipeBackAllowed)
            }
            trainingScreen
        }
        .animation(.easeInOut(duration: 0.3), value: appModel.navigation.presentedTraining)
        .sheet(isPresented: $model.isSettingsPresented) {
            SettingsView(settings: appModel.settings,
                isBusy: appModel.isSavingReview || appModel.deckState.isLoadingDeck,
                canRestoreTranslations: appModel.translationState.canRestoreBackup,
                onNextDay: { Task { await appModel.advanceReviewDay() } },
                onClearCache: { Task { await appModel.clearDeckCache() } },
                onRestoreTranslations: { Task { await appModel.translationState.restoreBackup() } },
                onResetDeckProgress: { deck in Task { await appModel.resetDeckProgress(deck) } },
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
        .allowsHitTesting(appModel.hasLoadedSavedState && !appModel.isSavingReview && !appModel.isLoadingSavedState)
        .overlay { loadingOverlay }
        .alert("Сообщение", isPresented: Binding(
            get: { appModel.errors.message != nil },
            set: { if !$0 { appModel.errors.message = nil } }
        )) {
            Button("Понятно", role: .cancel) {}
        } message: { Text(appModel.errors.message ?? "") }
        .task {
            await appModel.loadSavedState()
            #if DEBUG
            await appModel.importUITestingFixtureIfNeeded()
            #endif
        }
        .onChange(of: appModel.trainingSession.isActive) { appModel.synchronizeTrainingRoute() }
        .onChange(of: scenePhase) { if scenePhase == .active { Task { await appModel.resume() } } }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            Task { await appModel.resume() }
        }
    }

    private var startScreen: some View {
        StartView(practiceMode: Binding(get: { appModel.practiceMode }, set: { appModel.practiceMode = $0 }),
                  isLoading: appModel.deckState.isLoadingDeck, onOpen: appModel.openDeck,
                  settings: appModel.settings, ankiModel: appModel.ankiLibrary,
                  coordinator: appModel.coordinator, translationState: appModel.translationState,
                  reviewStore: appModel.trainingSession.reviewStore, onPractice: appModel.practice,
                  onOpenSettings: openSettings)
    }

    /// Колода получает маршрут параметром, а её состояние чистится только
    /// по onDisappear — уже после анимации pop (кнопкой или свайпом), поэтому
    /// уезжающая страница не пустеет на ходу.
    private func deckScreen(for route: StudyRoute) -> some View {
        deckPreview(for: route)
            .onDisappear { appModel.cleanUpAfterClosing(route) }
    }

    @ViewBuilder private func deckPreview(for route: StudyRoute) -> some View {
        switch route {
        case .ankiDeck(let deck):
            AnkiDeckPreviewView(deck: deck, model: appModel.ankiLibrary, settings: appModel.settings,
                translationState: appModel.translationState,
                trainingSession: appModel.trainingSession,
                reviewStore: appModel.trainingSession.reviewStore,
                session: appModel.customTraining,
                onBack: appModel.navigation.pop,
                onPractice: appModel.practice,
                onCustomTraining: appModel.beginCustomSelection,
                onStartCustomTraining: appModel.startCustomTraining,
                onOpenSettings: openSettings)
        case .kanjiDeck, .wordDeck, .kanaDeck:
            DeckPreviewView(route: route, deckState: appModel.deckState, coordinator: appModel.coordinator,
                            settings: appModel.settings,
                            translationState: appModel.translationState, reviewStore: appModel.trainingSession.reviewStore,
                            session: appModel.customTraining,
                            onPractice: appModel.practice,
                            onBack: appModel.navigation.pop,
                            onCustomTraining: appModel.beginCustomSelection,
                            onStartCustomTraining: appModel.startCustomTraining,
                            onOpenSettings: openSettings)
        case .start, .training, .customTraining:
            EmptyView()
        }
    }

    /// Тренировка показывается поверх стека, а не в нём: системный
    /// свайп-назад не должен случайно её прерывать.
    @ViewBuilder private var trainingScreen: some View {
        switch appModel.navigation.presentedTraining {
        case .training:
            TrainingView(trainingSession: appModel.trainingSession, settings: appModel.settings,
                         translationState: appModel.translationState, coordinator: appModel.coordinator, onPractice: appModel.practice,
                         onOpenSettings: openSettings)
                .background(AppPalette.background.ignoresSafeArea())
                .transition(.move(edge: .trailing))
                .zIndex(1)
        case .customTraining:
            CustomTrainingView(session: appModel.customTraining, settings: appModel.settings,
                               translationState: appModel.translationState, coordinator: appModel.coordinator,
                               reviewStore: appModel.trainingSession.reviewStore,
                               onExit: appModel.finishCustomTraining,
                               onOpenSettings: openSettings)
                .onDisappear(perform: appModel.cleanUpAfterCustomTraining)
                .background(AppPalette.background.ignoresSafeArea())
                .transition(.move(edge: .trailing))
                .zIndex(1)
        default:
            EmptyView()
        }
    }

    /// В режиме выбора свайп не закрывает колоду молча — выход из выбора
    /// остаётся за кнопкой «назад»; поверх тренировки стек не трогаем.
    private var isSwipeBackAllowed: Bool {
        appModel.navigation.presentedTraining == nil && !appModel.customTraining.isSelecting
    }

    private func openSettings() { appModel.isSettingsPresented = true }

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
