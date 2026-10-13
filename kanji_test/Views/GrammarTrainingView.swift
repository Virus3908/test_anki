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
    @FocusState private var isFormFocused: Bool
    @State private var operation: Task<Void, Never>?

    init(rule: GrammarRule, session: TrainingSessionViewModel, settings: StudyPreferences, translationState: TranslationViewModel) {
        self.rule = rule; self.session = session; self.settings = settings; self.translationState = translationState
        _practice = State(initialValue: session.practice(for: rule))
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Color.clear.frame(height: 1).id("grammar.practice.top")
                    if !practice.isLessonRead {
                        GrammarLessonContent(rule: rule, settings: settings, progress: session.reviewStore, translationState: translationState)
                    } else if let error = practice.contentError {
                        Text(error).accessibilityIdentifier("grammar.training.error")
                        Button("Посмотреть правило") { isLessonPresented = true }
                    } else if practice.isComplete {
                        result
                    } else if let exercise = practice.currentExercise {
                        question(exercise)
                    }
                }.padding(.horizontal, 8).padding(.bottom, 24)
            }
            .mask { BottomScrollMask() }
            .onChange(of: practice.isLessonRead) { proxy.scrollTo("grammar.practice.top", anchor: .top) }
            .onChange(of: practice.position) { proxy.scrollTo("grammar.practice.top", anchor: .top) }
        }
        .safeAreaInset(edge: .bottom) {
            BottomActionBar {
                if !practice.isLessonRead {
                    primaryActionButton(title: "Попробовать", systemImage: "checklist",
                        accessibilityIdentifier: "grammar.training.begin") { practice.isLessonRead = true }
                } else if practice.isComplete {
                    primaryActionButton(title: session.isGrammarResultPending ? "Продолжить" : "Сохранить результат",
                        systemImage: "arrow.right", accessibilityIdentifier: "grammar.training.continue") {
                        operation = Task {
                            if session.isGrammarResultPending { await session.continueGrammarAfterResult() }
                            else { await saveResult() }
                        }
                    }.disabled(session.isPreparingCard || practice.isSaving)
                } else if practice.contentError == nil {
                    let assembling = practice.currentExercise?.kind == .assembleSentence && !practice.isAnswerVisible
                    let forming = practice.currentExercise?.kind == .formProduction && !practice.isAnswerVisible
                    primaryActionButton(title: assembling || forming ? "Проверить" : "Продолжить", systemImage: "arrow.right",
                        accessibilityIdentifier: "grammar.training.next") {
                        if assembling { practice.checkAssembly() }
                        else if forming { practice.checkForm() }
                        else { practice.next() }
                    }.disabled(assembling ? practice.selectedElements.isEmpty : forming ? practice.textAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty : !practice.isAnswerVisible)
                }
                GlassIconButton(systemImage: "book", accessibilityLabel: "Посмотреть правило",
                    accessibilityIdentifier: "grammar.training.theory") {
                    if practice.isLessonRead { practice.useHint() }; isLessonPresented = true
                }
            }
        }
        .sheet(isPresented: $isLessonPresented) {
            NavigationStack {
                ScrollView { GrammarLessonContent(rule: rule, settings: settings, progress: session.reviewStore, translationState: translationState).padding(16) }
                    .background(AppPalette.background)
                    .toolbar { Button("Закрыть") { isLessonPresented = false } }
            }
        }
        .task(id: practice.isComplete) {
            guard practice.isComplete else { return }
            await saveResult()
        }
        .onDisappear { operation?.cancel() }
        .onChange(of: practice.isAnswerVisible) { if practice.isAnswerVisible { isFormFocused = false } }
    }

    private func saveResult() async {
        guard !Task.isCancelled, !session.isGrammarResultPending, let rating = practice.beginSaving() else { return }
        await session.submitReview(rating, expectedKey: rule.reviewKey, holdGrammarResult: true)
        practice.finishSaving(success: session.isGrammarResultPending)
    }

    private func question(_ exercise: GrammarExercise) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Задание \(practice.position + 1) из \(practice.count)").font(.subheadline)
                .foregroundStyle(AppPalette.secondaryText)
            ProgressView(value: Double(practice.position), total: Double(practice.count))
            if exercise.kind == .distinguishMeaning, let contrasts = rule.teaching?.contrastsRU {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Сравни значения").font(.headline)
                    ForEach(contrasts, id: \.self) { Text($0).font(.callout).fixedSize(horizontal: false, vertical: true) }
                }.padding(16).appSurfaceCard()
            }
            Text(exercise.promptRU).font(.title3.weight(.medium)).fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("grammar.training.prompt").accessibilityValue(exercise.id)
            if let japanese = exercise.japanese {
                Text(japanese).font(.title2).fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled).accessibilityIdentifier("grammar.training.japanese")
            }
            if exercise.kind == .formProduction {
                @Bindable var model = practice
                TextField("Напиши форму по-японски", text: $model.textAnswer)
                    .font(.title2).padding(16).appSurfaceCard()
                    .focused($isFormFocused)
                    .autocorrectionDisabled().textInputAutocapitalization(.never)
                    .submitLabel(.done).onSubmit { practice.checkForm() }
                    .disabled(practice.isAnswerVisible)
                    .accessibilityIdentifier("grammar.form.answer")
            } else if exercise.kind == .assembleSentence {
                assembly(exercise)
            } else {
                ForEach(practice.options) { option in optionButton(option, exercise: exercise) }
            }
            if practice.isAnswerVisible {
                feedback(exercise)
            } else {
                Button("Подсказка") { practice.useHint() }.accessibilityIdentifier("grammar.training.hint")
                if practice.usedHint { Text(exercise.hintRU ?? exercise.explanationRU).font(.callout) }
            }
        }
    }

    private func optionButton(_ option: GrammarExercise.Option, exercise: GrammarExercise) -> some View {
        let correct = practice.isAnswerVisible && exercise.accepts(option.id)
        let selected = practice.selectedOptionID == option.id
        return Button { practice.choose(option.id) } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: correct ? "checkmark.circle.fill" : selected ? "xmark.circle.fill" : "circle")
                    .foregroundStyle(correct ? AppPalette.success : selected ? AppPalette.correction : AppPalette.accent)
                Text(option.text).font(.title3).fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }.padding(16).appSurfaceCard()
        }
        .buttonStyle(.plain).disabled(practice.isAnswerVisible)
        .accessibilityIdentifier("grammar.option.\(option.id)")
        .accessibilityValue(correct ? "correct" : selected ? "selectedIncorrect" : "available")
    }

    private func assembly(_ exercise: GrammarExercise) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(practice.selectedElements.compactMap { id in exercise.options.first { $0.id == id }?.text }.joined())
                .font(.title2).frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                .accessibilityIdentifier("grammar.assembly.answer")
            Text("Нажимай на элементы по порядку. Повторное нажатие убирает элемент.").font(.caption)
                .foregroundStyle(AppPalette.secondaryText)
            // A wrapping vertical layout also works with large text and narrow phones.
            ForEach(practice.options) { option in
                Button { practice.toggleElement(option.id) } label: {
                    HStack {
                        Text(option.text).font(.title3)
                        Spacer()
                        if let index = practice.selectedElements.firstIndex(of: option.id) { Text("\(index + 1)") }
                    }.padding(12).appSurfaceCard()
                }.buttonStyle(.plain).disabled(practice.isAnswerVisible)
                    .accessibilityIdentifier("grammar.element.\(option.id)")
            }
        }.accessibilityIdentifier("grammar.assembly")
    }

    private func feedback(_ exercise: GrammarExercise) -> some View {
        let correct = practice.results.last?.isCorrect == true
        return VStack(alignment: .leading, spacing: 8) {
            Label(correct ? "Правильно" : "Есть ошибка", systemImage: correct ? "checkmark.circle" : "xmark.circle")
                .foregroundStyle(correct ? AppPalette.success : AppPalette.correction).font(.headline)
            if !correct {
                Text(exercise.correctAnswer).font(.title3)
                if let option = exercise.options.first(where: { $0.id == practice.selectedOptionID }), let text = option.feedbackRU {
                    Text(text).font(.callout)
                } else { Text(exercise.explanationRU).font(.callout) }
                Button("Посмотреть правило") { isLessonPresented = true }
            }
        }.accessibilityIdentifier("grammar.training.feedback")
    }

    private var result: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label(practice.weakAspects.isEmpty ? "Правило закреплено" : "Практика завершена", systemImage: "checkmark.seal")
                .font(.title2.bold())
            Text("Готово! \(practice.correctCount) из \(practice.count)")
                .font(.headline).accessibilityIdentifier("grammar.training.result")
            ForEach(practice.weakAspects, id: \.self) { Text("Повтори: " + $0).font(.callout) }
            if session.isGrammarResultPending, let record = session.reviewStore.record(for: rule.reviewKey) {
                Text("Следующее повторение: \(record.dueDate.formatted(date: .abbreviated, time: .shortened))")
                    .accessibilityIdentifier("grammar.training.saved")
            } else if session.isPreparingCard || practice.isSaving {
                CenteredLoadingIndicator(title: "Сохраняю результат")
            }
        }
    }
}
