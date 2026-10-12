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
                GrammarContentStatus()
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

struct GrammarContentStatus: View {
    var body: some View {
        Text("Исходный учебный материал на английском языке. Русская локализация и проверенные задания с выбором ответа ещё не подготовлены. Доступна самопроверка с оценкой FSRS.")
            .font(.callout).foregroundStyle(AppPalette.secondaryText)
            .accessibilityIdentifier("grammar.contentStatus")
    }
}

struct GrammarLevelView: View {
    let level: GrammarLevel
    let appModel: StudyAppViewModel
    @State private var model = GrammarLibraryViewModel()
    @State private var query = ""
    @State private var category: GrammarCategory?

    private var rules: [GrammarRule] { model.rules.filter { $0.level == level } }
    private var categories: [GrammarCategory] {
        GrammarCategory.allCases.filter { category in rules.contains { $0.categories.contains(category) } }
    }
    private var filterToken: String { "\(query)|\(category?.rawValue ?? "all")|\(model.rules.count)" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if model.isLoading { ProgressView("Загружаю правила") }
                if let error = model.error {
                    Text(error).foregroundStyle(AppPalette.correction)
                    Button("Повторить") { Task { await model.load() } }
                }
                if !rules.isEmpty {
                    statistics
                    GrammarContentStatus()
                    Button("Начать обучение") { appModel.startGrammar(level) }
                        .buttonStyle(.borderedProminent).accessibilityIdentifier("grammar.learn")
                    Button("Повторить изученное") { appModel.startGrammar(level, reviewsOnly: true) }
                        .buttonStyle(.bordered).accessibilityIdentifier("grammar.review")
                    Button("Настройки колоды") { appModel.isSettingsPresented = true }
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
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(rule.pattern).font(.headline)
                                    Text(rule.displayedMeaning).font(.callout)
                                    Text(GrammarStatistics.status(rule, progress: appModel.trainingSession.reviewStore))
                                        .font(.caption).foregroundStyle(AppPalette.secondaryText)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading).padding(16).appSurfaceCard()
                            }
                            .buttonStyle(.plain).accessibilityIdentifier("grammar.rule.\(rule.id)")
                        }
                    }
                }
            }
            .padding(16).foregroundStyle(AppPalette.text)
        }
        .background(AppPalette.background).navigationTitle("Грамматика \(level.rawValue)")
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
            Text("На повторении: \(stats.review) / \(stats.total)").font(.headline)
            ProgressView(value: Double(stats.review), total: Double(max(1, stats.total)))
            Text("Новые: \(stats.new) · Learning: \(stats.learning) · Relearning: \(stats.relearning)")
            Text("Готовы к повторению: \(stats.due) · Исключены: \(stats.excluded)")
            Text("Сегодня: \(plan.todayIDs.count) · Новые: \(plan.newCount) · Скрыты лимитом: \(plan.hiddenReviews)")
            DisclosureGroup("Расписание") {
                ForEach(progress.scheduleBuckets(forReviewKeys: Set(rules.map(\.reviewKey)))) { bucket in
                    Text("\(bucket.title): \(bucket.count)")
                }
            }
        }
        .font(.callout).padding(16).appSurfaceCard().accessibilityIdentifier("grammar.statistics")
    }
}
