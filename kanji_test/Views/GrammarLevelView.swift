import SwiftUI

struct GrammarLevelMenu: View {
    let reviewStore: StudyProgressStore
    let onOpen: (StudyRoute) -> Void
    @State private var model = GrammarLibraryViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if model.isLoading { ProgressView("Загружаю грамматику") }
            if let error = model.error {
                Text(error).foregroundStyle(AppPalette.correction)
                Button("Повторить") { Task { await model.load() } }
            }
            if !model.rules.isEmpty {
                let all = GrammarStatistics(rules: model.rules, progress: reviewStore)
                Text("На повторении: \(all.review) / \(all.total)")
                    .accessibilityIdentifier("grammar.total")
                ForEach(GrammarLevel.allCases) { level in
                    let stats = GrammarStatistics(rules: model.rules.filter { $0.level == level }, progress: reviewStore)
                    Button { onOpen(.grammarLevel(level)) } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("\(level.rawValue) — \(stats.total) правил").font(.headline)
                            Text("Новые: \(stats.new) · Обучение: \(stats.learning + stats.relearning) · На повторении: \(stats.review)")
                                .font(.caption).foregroundStyle(AppPalette.secondaryText)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading).padding(16).appSurfaceCard()
                    }
                    .buttonStyle(.plain).accessibilityIdentifier("grammar.level.\(level.rawValue)")
                }
            }
        }
        .task { await model.load() }
    }
}

struct GrammarLevelView: View, StudyViewStyling {
    @Environment(\.dismiss) private var dismiss
    let level: GrammarLevel
    let appModel: StudyAppViewModel
    @State private var model = GrammarLibraryViewModel()
    @State private var query = ""
    @State private var category: GrammarCategory?
    @State private var selectedLevels: Set<GrammarLevel> = []
    @State private var scope: GrammarSessionPlanner.Scope = .mixed
    private var practiceLevels: Set<GrammarLevel> { selectedLevels.isEmpty ? [level] : selectedLevels }

    private var rules: [GrammarRule] { model.rules.filter { $0.level == level } }
    private var categories: [GrammarCategory] {
        GrammarCategory.allCases.filter { category in rules.contains { $0.categories.contains(category) } }
    }
    private var filterToken: String { "\(query)|\(category?.rawValue ?? "all")|\(model.rules.count)" }

    var body: some View {
        VStack(spacing: 14) {
            previewHeader(title: "Грамматика \(level.rawValue)", subtitle: "\(rules.count) правил", onBack: { dismiss() }) {
                GlassIconButton(systemImage: "gearshape", accessibilityLabel: "Настройки") { appModel.isSettingsPresented = true }
            }
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if model.isLoading { CenteredLoadingIndicator(title: "Загружаю правила") }
                if let error = model.error {
                    Text(error).foregroundStyle(AppPalette.correction)
                    Button("Повторить") { Task { await model.load() } }
                }
                if !rules.isEmpty {
                    statistics
                    DisclosureGroup("Область тренировки") {
                        Picker("Режим", selection: $scope) {
                            Text("Смешанная тренировка").tag(GrammarSessionPlanner.Scope.mixed)
                            Text("Новые правила").tag(GrammarSessionPlanner.Scope.newRules)
                            Text("Повторять изученные").tag(GrammarSessionPlanner.Scope.studied)
                        }.pickerStyle(.menu)
                        ForEach(GrammarLevel.allCases) { item in
                            Toggle(item.rawValue, isOn: Binding(get: { practiceLevels.contains(item) }, set: { enabled in
                                var next = practiceLevels
                                if enabled { next.insert(item) } else { next.remove(item) }
                                if !next.isEmpty { selectedLevels = next }
                            })).accessibilityIdentifier("grammar.scope.\(item.rawValue)")
                        }
                        Button("Все изученные правила") {
                            appModel.startMixedGrammar(levels: Set(GrammarLevel.allCases), scope: .studied)
                        }.accessibilityIdentifier("grammar.mixed.allStudied")
                    }.accessibilityIdentifier("grammar.scope")
                    Text("Базовая практика: \(rules.filter { GrammarExerciseEngine.hasPractice($0) }.count) · Расширенная: \(rules.filter { GrammarExerciseEngine.hasExtendedPractice($0) }.count). Остальные расширенные материалы требуют проверки.").font(.caption).foregroundStyle(AppPalette.secondaryText)
                    TextField("Конструкция, чтение, значение", text: $query)
                        .textFieldStyle(.roundedBorder).autocorrectionDisabled().textInputAutocapitalization(.never)
                        .accessibilityIdentifier("grammar.search")
                    Picker("Категория", selection: $category) {
                        Text("Все категории").tag(Optional<GrammarCategory>.none)
                        ForEach(categories) { Text($0.title).tag(Optional($0)) }
                    }
                    .pickerStyle(.menu)
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(model.results) { rule in
                            NavigationLink(value: StudyRoute.grammarRule(level, rule.id)) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(rule.pattern)
                                        .font(.system(.title2, design: .serif))
                                        .frame(maxWidth: .infinity, minHeight: 30, alignment: .leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                    HStack(alignment: .top, spacing: 10) {
                                        let meaning = appModel.translationState.displayedGrammarText(
                                            rule.displayedMeaning,
                                            rule: rule,
                                            language: appModel.settings.options(for: level.deck.id).meaningLanguage
                                        )
                                        Text(meaning)
                                            .font(.callout)
                                            .foregroundStyle(AppPalette.secondaryText)
                                            .lineLimit(2)
                                            .frame(maxWidth: .infinity, minHeight: 36, alignment: .topLeading)
                                            .fixedSize(horizontal: false, vertical: true)
                                            .accessibilityLabel(meaning)

                                        Text(GrammarStatistics.status(rule, progress: appModel.trainingSession.reviewStore))
                                            .font(.caption.weight(.medium))
                                            .foregroundStyle(AppPalette.secondaryText)
                                            .multilineTextAlignment(.trailing)
                                            .fixedSize(horizontal: false, vertical: true)
                                            .frame(maxWidth: 112, minHeight: 36, alignment: .topTrailing)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .appSurfaceCard(borderOpacity: 0.55)
                                .cardMasteryChrome(CardMastery(record: appModel.trainingSession.reviewStore.record(for: rule.reviewKey),
                                    isExcluded: appModel.trainingSession.reviewStore.isExcluded(rule.reviewKey),
                                    now: appModel.trainingSession.reviewStore.studyDate()))
                            }
                            .frame(maxWidth: .infinity)
                            .buttonStyle(.plain).accessibilityIdentifier("grammar.rule.\(rule.id)")
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 16)
            .foregroundStyle(AppPalette.text)
        }
        }
        .padding(.horizontal, 12).padding(.top, 8)
        .background(AppPalette.background.ignoresSafeArea()).toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom) {
            BottomActionBar {
                primaryActionButton(title: "Смешанная тренировка", systemImage: "checklist",
                    accessibilityIdentifier: "grammar.learn") { appModel.startMixedGrammar(levels: practiceLevels, scope: scope) }
                GlassIconButton(systemImage: "arrow.clockwise", accessibilityLabel: "Повторить изученное",
                    accessibilityIdentifier: "grammar.review") { appModel.startMixedGrammar(levels: practiceLevels, scope: .studied) }
            }
        }
        .task { await model.load() }
        .onChange(of: query) { model.invalidateSearch() }
        .onChange(of: category) { model.invalidateSearch() }
        .onDisappear { model.invalidateSearch() }
        .task(id: filterToken) {
            if !query.isEmpty {
                do { try await Task.sleep(for: .milliseconds(250)) } catch { return }
            }
            guard !Task.isCancelled else { return }
            await model.search(query, level: level, category: category)
        }
    }

    private var statistics: some View {
        let progress = appModel.trainingSession.reviewStore
        let stats = GrammarStatistics(rules: rules, progress: progress)
        let options = appModel.settings.effectiveOptions(for: level.deck.id, studyDay: progress.studyDate())
        let plan = TrainingSessionEngine.plan(sourceIDs: rules.map(\.id), mode: .grammar,
            deckID: level.deck.id, progress: progress, options: options)
        return VStack(alignment: .leading, spacing: 8) {
            Text("К повторению: \(stats.due)").font(.headline)
            Text("Новые правила: \(stats.new)").foregroundStyle(AppPalette.secondaryText)
            DisclosureGroup("Прогресс и расписание") {
                Text("Изучаются: \(stats.learning + stats.relearning) · На повторении: \(stats.review)")
                Text("Сегодня: \(plan.todayIDs.count) · Новые: \(plan.newCount)")
                Text("Скрыты лимитом: \(plan.hiddenReviews) · Исключены: \(stats.excluded)")
                ForEach(progress.scheduleBuckets(forReviewKeys: Set(rules.map(\.reviewKey)))) { bucket in
                    Text("\(bucket.title): \(bucket.count)")
                }
            }
        }
        .font(.callout).padding(16).appSurfaceCard().accessibilityIdentifier("grammar.statistics")
    }
}
