import SwiftUI

/// Presentation over the shared queue. Questions never schedule their own reviews.
struct GrammarTrainingView: View, StudyViewStyling {
    let session: TrainingSessionViewModel
    let settings: StudyPreferences
    let translationState: TranslationViewModel
    let onOpenSettings: () -> Void
    @State private var operation: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 14) {
            previewHeader(title: "Грамматика", subtitle: "Осталось сегодня: \(session.sessionTotalCards)", onBack: session.finish) {
                GlassIconButton(systemImage: "arrow.uturn.backward", accessibilityLabel: "Отменить ответ",
                    accessibilityIdentifier: "grammar.training.undo") {
                    operation?.cancel()
                    operation = Task { await session.moveToPreviousCard() }
                }.disabled(!session.canGoBack || session.isPreparingCard)
                GlassIconButton(systemImage: "gearshape", accessibilityLabel: "Настройки", action: onOpenSettings)
            }
            if let rule = session.currentGrammarRule {
                GrammarPracticeCard(rule: rule, session: session, settings: settings, translationState: translationState)
                    .id("\(rule.id):\(session.scrollToTopToken)")
            } else {
                CenteredLoadingIndicator(title: "Обновляю очередь")
            }
        }
        .padding(.horizontal, 12).padding(.top, 8)
        .foregroundStyle(AppPalette.text).background(AppPalette.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .onDisappear { operation?.cancel() }
        .onChange(of: session.options) { operation = Task { await session.refreshForNewDay() } }
        .task(id: session.state.nextLearningDate) {
            guard let date = session.state.nextLearningDate else { return }
            let delay = max(0, date.timeIntervalSince(session.reviewStore.studyDate()))
            do { try await Task.sleep(for: .seconds(delay + 0.1)) } catch { return }
            await session.refreshForNewDay()
        }
    }
}

private struct GrammarPracticeCard: View, StudyViewStyling {
    let rule: GrammarRule
    let session: TrainingSessionViewModel
    let settings: StudyPreferences
    let translationState: TranslationViewModel
    @State private var practice: GrammarPracticeViewModel
    @State private var isLessonPresented = false
    @State private var isLessonRead: Bool
    @State private var operation: Task<Void, Never>?

    init(rule: GrammarRule, session: TrainingSessionViewModel, settings: StudyPreferences, translationState: TranslationViewModel) {
        self.rule = rule; self.session = session; self.settings = settings; self.translationState = translationState
        let attempts = session.reviewStore.record(for: rule.reviewKey)?.attempts ?? 0
        _practice = State(initialValue: GrammarPracticeViewModel(rule: rule, seed: "\(rule.id):\(attempts)"))
        _isLessonRead = State(initialValue: session.reviewStore.record(for: rule.reviewKey) != nil)
    }

    var body: some View {
        ScrollViewReader { proxy in
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(!isLessonRead || practice.isComplete ? "\(rule.level.rawValue) · \(rule.pattern)" : "Грамматика \(rule.level.rawValue)").font(.title2.bold()).id("grammar.practice.top")
                if !isLessonRead {
                    Text("1 · Изучи правило → 2 · Выполни задания → 3 · Разбери результат")
                        .font(.callout).foregroundStyle(AppPalette.secondaryText)
                    GrammarLessonContent(rule: rule, settings: settings, progress: session.reviewStore, translationState: translationState)
                } else if let error = practice.contentError {
                    Label("Упражнения недоступны", systemImage: "exclamationmark.triangle")
                        .font(.headline).foregroundStyle(AppPalette.correction)
                    Text(error).accessibilityIdentifier("grammar.training.error")
                    Button("Посмотреть правило") { isLessonPresented = true }
                } else if practice.isComplete {
                    result
                } else if let exercise = practice.currentExercise {
                    question(exercise)
                }
            }.padding(.horizontal, 4).padding(.bottom, 44)
        }
        .mask { BottomScrollMask() }
        .onChange(of: isLessonRead) { proxy.scrollTo("grammar.practice.top", anchor: .top) }
        .onChange(of: practice.position) { proxy.scrollTo("grammar.practice.top", anchor: .top) }
        }
        .safeAreaInset(edge: .bottom) {
            BottomActionBar {
                if !isLessonRead {
                    primaryActionButton(title: "Перейти к упражнениям", systemImage: "checklist",
                        accessibilityIdentifier: "grammar.training.begin") { isLessonRead = true }
                } else if practice.isComplete {
                    primaryActionButton(title: session.isGrammarResultPending ? "Следующее правило" : "Сохранить результат",
                        systemImage: "arrow.right", accessibilityIdentifier: "grammar.training.continue") {
                        operation?.cancel()
                        operation = Task {
                            if session.isGrammarResultPending { await session.continueGrammarAfterResult() }
                            else { await saveResult() }
                        }
                    }.disabled(session.isPreparingCard)
                } else if practice.contentError == nil {
                    primaryActionButton(title: "Продолжить", systemImage: "arrow.right",
                        accessibilityIdentifier: "grammar.training.next") { practice.next() }
                        .disabled(!practice.isAnswerVisible)
                }
                GlassIconButton(systemImage: "book", accessibilityLabel: "Посмотреть правило") { isLessonPresented = true }
            }
        }
        .sheet(isPresented: $isLessonPresented) {
            NavigationStack {
                ScrollView { GrammarLessonContent(rule: rule, settings: settings, progress: session.reviewStore, translationState: translationState).padding(16) }
                    .background(AppPalette.background)
                    .toolbar { Button("Закрыть") { isLessonPresented = false } }
            }
        }
        .task(id: "\(rule.id):\(settings.options(for: rule.level.deck.id).meaningLanguage)") {
            await translationState.translateGrammarIfNeeded(rule, language: settings.options(for: rule.level.deck.id).meaningLanguage)
        }
        .task(id: practice.isComplete) {
            guard practice.isComplete else { return }
            await saveResult()
        }
        .onDisappear { practice.close(); operation?.cancel() }
    }

    private func english(_ text: String) -> String {
        translationState.displayedGrammarText(text, rule: rule, language: settings.options(for: rule.level.deck.id).meaningLanguage)
    }

    private func saveResult() async {
        guard !Task.isCancelled, !session.isGrammarResultPending, let rating = practice.proposedRating else { return }
        await session.submitReview(rating, expectedKey: rule.reviewKey, holdGrammarResult: true)
    }

    private func question(_ exercise: GrammarExercise) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Задание \(practice.position + 1) из \(practice.count) · \(exercise.kind.title)").font(.headline)
            ProgressView(value: Double(practice.position), total: Double(practice.count))
            Text(exercise.promptRU).font(.title3).fixedSize(horizontal: false, vertical: true)
            if let cue = exercise.cueEN { Text(english(cue)).font(.title3) }
            ForEach(practice.options) { option in
                let correct = practice.isAnswerVisible && exercise.accepts(option.id)
                let selected = practice.selectedOptionID == option.id
                Button { practice.choose(option.id) } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: correct ? "checkmark.circle.fill" : selected ? "xmark.circle.fill" : "circle")
                            .foregroundStyle(correct ? AppPalette.success : selected ? AppPalette.correction : AppPalette.accent)
                        Text(option.text).fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if correct { Text("Верно").font(.caption) }
                        else if selected { Text("Твой ответ").font(.caption) }
                    }.padding(16).appSurfaceCard()
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(
                            correct ? AppPalette.success : selected ? AppPalette.correction : .clear, lineWidth: 2))
                }
                .buttonStyle(.plain).disabled(practice.isAnswerVisible)
                .accessibilityIdentifier("grammar.option.\(option.id)")
                .accessibilityValue(correct ? "correct" : selected ? "selectedIncorrect" : "available")
            }
            if practice.isAnswerVisible {
                VStack(alignment: .leading, spacing: 8) {
                    Label(practice.results.last?.isCorrect == true ? "Правильно" : "Есть ошибка",
                        systemImage: practice.results.last?.isCorrect == true ? "checkmark.circle" : "xmark.circle")
                    Text(exercise.explanationRU)
                    if let explanation = exercise.explanationEN { Text(english(explanation)) }
                    if let option = exercise.options.first(where: { $0.id == practice.selectedOptionID }),
                       !exercise.accepts(option.id), let feedback = option.feedbackRU { Text(feedback) }
                }.padding(16).appSurfaceCard().accessibilityIdentifier("grammar.training.feedback")
            }
        }
    }

    private var result: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Урок завершён", systemImage: "checkmark.seal").font(.title2.bold())
            Text("Правильных ответов: \(practice.correctCount) из \(practice.count)")
                .font(.headline).accessibilityIdentifier("grammar.training.result")
            ForEach(practice.results, id: \.exerciseID) { answer in
                if let exercise = practice.exercises.first(where: { $0.id == answer.exerciseID }) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(exercise.promptRU, systemImage: answer.isCorrect ? "checkmark.circle" : "xmark.circle")
                        if !answer.isCorrect {
                            Text("Твой ответ: \(exercise.options.first { $0.id == answer.optionID }?.text ?? "")")
                            Text("Правильно: \(exercise.options.filter { exercise.accepts($0.id) }.map(\.text).joined(separator: "; "))")
                        }
                        Text(exercise.explanationRU)
                    if let explanation = exercise.explanationEN { Text(english(explanation)).font(.callout) }
                    }.padding(16).appSurfaceCard()
                }
            }
            if session.isGrammarResultPending, let record = session.reviewStore.record(for: rule.reviewKey) {
                Text("Следующее повторение: \(record.dueDate.formatted(date: .abbreviated, time: .shortened))")
                Text("Результат сохранён. Одно прохождение — одна запись повторения.").font(.caption).accessibilityIdentifier("grammar.training.saved")
            } else if session.isPreparingCard {
                CenteredLoadingIndicator(title: "Сохраняю результат")
            } else {
                Text("Оценка: \(practice.proposedRating?.title ?? "—"). Сохраняем результат всего урока.").font(.callout)
            }
        }
    }
}
