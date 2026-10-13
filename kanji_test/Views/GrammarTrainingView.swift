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
            if let mixed = session.grammarMixed {
                if mixed.isComplete {
                    GrammarMixedResultView(mixed: mixed, session: session)
                } else if let practice = mixed.current {
                    GrammarPracticeCard(rule: practice.rule, session: session, settings: settings,
                        translationState: translationState, practice: practice, mixed: mixed)
                        .id("mixed:\(mixed.currentRuleID ?? ""):\(mixed.revision)")
                }
            } else if let rule = session.currentGrammarRule {
                GrammarPracticeCard(rule: rule, session: session, settings: settings, translationState: translationState)
                    .id("\(rule.id):\(session.scrollToTopToken)")
            } else {
                CenteredLoadingIndicator(title: "Обновляю очередь")
            }
        }
        .padding(.horizontal, 16).padding(.top, 8)
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
    let mixed: GrammarMixedSessionViewModel?
    @State private var practice: GrammarPracticeViewModel
    @State private var isLessonPresented = false
    @FocusState private var isFormFocused: Bool
    @State private var operation: Task<Void, Never>?

    init(rule: GrammarRule, session: TrainingSessionViewModel, settings: StudyPreferences, translationState: TranslationViewModel,
         practice: GrammarPracticeViewModel? = nil, mixed: GrammarMixedSessionViewModel? = nil) {
        self.rule = rule; self.session = session; self.settings = settings; self.translationState = translationState
        self.mixed = mixed
        _practice = State(initialValue: practice ?? session.practice(for: rule))
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
                }.padding(.bottom, 24)
            }
            .mask { BottomScrollMask() }
            .onChange(of: practice.isLessonRead) { proxy.scrollTo("grammar.practice.top", anchor: .top) }
            .onChange(of: practice.position) { proxy.scrollTo("grammar.practice.top", anchor: .top) }
        }
        .safeAreaInset(edge: .bottom) {
            BottomActionBar {
                if !practice.isLessonRead {
                    primaryActionButton(title: "Попробовать", systemImage: "checklist",
                        accessibilityIdentifier: "grammar.training.begin") {
                            if mixed != nil { operation = Task { await session.introduceMixedGrammarRule() } }
                            else { practice.isLessonRead = true }
                        }.disabled(session.isPreparingCard)
                } else if practice.isComplete {
                    primaryActionButton(title: practice.proposedRating == nil && !practice.isSaved ? "Готово" : session.isGrammarResultPending ? "Продолжить" : "Сохранить результат",
                        systemImage: "arrow.right", accessibilityIdentifier: "grammar.training.continue") {
                        operation = Task {
                            if practice.proposedRating == nil && !practice.isSaved { session.finish() }
                            else if session.isGrammarResultPending { await session.continueGrammarAfterResult() }
                            else { await saveResult() }
                        }
                    }.disabled(session.isPreparingCard || practice.isSaving)
                } else if practice.contentError == nil {
                    let assembling = practice.currentExercise?.kind == .assembleSentence && !practice.isAnswerVisible
                    let forming = (practice.currentExercise?.kind == .formProduction || practice.currentExercise?.kind == .restoreSentence) && !practice.isAnswerVisible
                    primaryActionButton(title: assembling || forming ? "Проверить" : "Продолжить", systemImage: "arrow.right",
                        accessibilityIdentifier: "grammar.training.next") {
                        if assembling { practice.checkAssembly() }
                        else if forming { practice.checkForm() }
                        else if mixed != nil { operation = Task { await session.advanceMixedGrammar() } }
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
            guard mixed == nil, practice.isComplete else { return }
            await saveResult()
        }
        .onDisappear { if mixed == nil { operation?.cancel() } }
        .onChange(of: practice.isAnswerVisible) { if practice.isAnswerVisible { isFormFocused = false } }
    }

    private func saveResult() async {
        guard !Task.isCancelled, !session.isGrammarResultPending, let rating = practice.beginSaving() else { return }
        await session.submitReview(rating, expectedKey: rule.reviewKey, holdGrammarResult: true)
        practice.finishSaving(success: session.isGrammarResultPending)
    }

    private func question(_ exercise: GrammarExercise) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("ЗАДАНИЕ \((mixed?.answered ?? practice.position) + (practice.isAnswerVisible && mixed != nil ? 0 : 1)) ИЗ \(mixed?.total ?? practice.count)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppPalette.secondaryText)
                    Spacer(minLength: 8)
                    if mixed != nil {
                        Text("Смешанная практика").font(.caption).foregroundStyle(AppPalette.secondaryText)
                    }
                }
                ProgressView(value: Double(mixed?.answered ?? practice.position), total: Double(mixed?.total ?? practice.count))
                    .tint(AppPalette.accent)
            }
            Rectangle().fill(AppPalette.border.opacity(0.65)).frame(height: 1)
            if mixed == nil, exercise.kind == .distinguishMeaning, let contrasts = rule.teaching?.contrastsRU {
                VStack(alignment: .leading, spacing: 8) {
                    Text("СРАВНИ ЗНАЧЕНИЯ").font(.caption.weight(.bold)).foregroundStyle(AppPalette.secondaryText)
                    ForEach(contrasts, id: \.self) { Text($0).font(.callout).fixedSize(horizontal: false, vertical: true) }
                }
            }
            FuriganaText(text: exercise.promptRU, furigana: exercise.ruby(for: exercise.promptRU), showsFurigana: settings.showExampleFurigana).font(.title3.weight(.medium)).fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("grammar.training.prompt").accessibilityValue(exerciseAccessibilityValue(exercise))
            if exercise.kind == .restoreSentence, let cue = exercise.cueEN {
                Text(cue).font(.title3).fixedSize(horizontal: false, vertical: true)
            }
            if let japanese = exercise.japanese {
                FuriganaText(text: japanese, furigana: exercise.ruby(for: japanese), showsFurigana: settings.showExampleFurigana).font(.title2.weight(.medium)).fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled).accessibilityIdentifier("grammar.training.japanese")
                    .accessibilityValue(settings.showExampleFurigana && exercise.ruby(for: japanese) != nil ? "furigana" : "plain")
            }
            if exercise.kind == .restoreSentence {
                Text("Базовая практика: восстановление оригинала. Она не меняет расписание повторений.")
                    .font(.caption).foregroundStyle(AppPalette.secondaryText)
            }
            Rectangle().fill(AppPalette.border.opacity(0.65)).frame(height: 1)
            if exercise.kind == .formProduction || exercise.kind == .restoreSentence {
                @Bindable var model = practice
                TextField(exercise.kind == .restoreSentence ? "Напиши исходное предложение" : "Напиши форму по-японски", text: $model.textAnswer)
                    .font(.title2)
                    .padding(12)
                    .background(AppPalette.background, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppPalette.border.opacity(0.7), lineWidth: 1))
                    .focused($isFormFocused)
                    .autocorrectionDisabled().textInputAutocapitalization(.never)
                    .submitLabel(.done).onSubmit { practice.checkForm() }
                    .disabled(practice.isAnswerVisible)
                    .accessibilityIdentifier("grammar.form.answer")
            } else if exercise.kind == .assembleSentence {
                assembly(exercise)
            } else {
                VStack(spacing: 0) {
                    ForEach(practice.options.indices, id: \.self) { index in
                        let option = practice.options[index]
                        optionButton(option, exercise: exercise)
                        if index < practice.options.count - 1 {
                            Rectangle().fill(AppPalette.border.opacity(0.5)).frame(height: 1).padding(.leading, 34)
                        }
                    }
                }
            }
            if practice.isAnswerVisible {
                Rectangle().fill(AppPalette.border.opacity(0.65)).frame(height: 1)
                feedback(exercise)
            } else {
                Button { practice.useHint() } label: {
                    Label("Подсказка", systemImage: "lightbulb")
                        .font(.subheadline.weight(.medium))
                }.accessibilityIdentifier("grammar.training.hint")
                if practice.usedHint {
                    let hint = exercise.hintRU ?? exercise.explanationRU
                    FuriganaText(text: hint, furigana: exercise.ruby(for: hint), showsFurigana: settings.showExampleFurigana)
                        .font(.callout).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appSurfaceCard()
    }

    private func optionButton(_ option: GrammarExercise.Option, exercise: GrammarExercise) -> some View {
        let correct = practice.isAnswerVisible && exercise.accepts(option.id)
        let selected = practice.selectedOptionID == option.id
        let stateText: String? = practice.isAnswerVisible
            ? (correct ? "Правильный ответ" : selected ? "Ваш ответ" : "Недоступно")
            : (selected ? "Выбрано" : nil)
        let stateIcon = practice.isAnswerVisible
            ? (correct ? "checkmark.circle.fill" : selected ? "xmark.circle.fill" : "circle")
            : (selected ? "largecircle.fill.circle" : "circle")
        return Button { practice.choose(option.id) } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: stateIcon)
                    .foregroundStyle(correct ? AppPalette.success : practice.isAnswerVisible && selected ? AppPalette.correction : AppPalette.accent)
                    .padding(.top, 2)
                FuriganaText(text: option.text, furigana: exercise.ruby(for: option.text), showsFurigana: settings.showExampleFurigana).font(.title3).fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let stateText {
                    Text(stateText).font(.caption.weight(.medium)).foregroundStyle(AppPalette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }.padding(.vertical, 12)
        }
        .buttonStyle(.plain).disabled(practice.isAnswerVisible)
        .accessibilityIdentifier("grammar.option.\(option.id)")
        .accessibilityValue(correct ? "correct" : practice.isAnswerVisible ? (selected ? "selectedIncorrect" : "unavailable") : selected ? "selected" : "available")
    }
    private func exerciseAccessibilityValue(_ exercise: GrammarExercise) -> String {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ui-testing") { return exercise.id }
        #endif
        return ""
    }

    private func assembly(_ exercise: GrammarExercise) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("СОБЕРИ ПРЕДЛОЖЕНИЕ").font(.caption.weight(.bold)).foregroundStyle(AppPalette.secondaryText)
            FuriganaText(text: practice.selectedElements.compactMap { id in exercise.options.first { $0.id == id }?.text }.joined(),
                furigana: exercise.ruby(for: practice.selectedElements), showsFurigana: settings.showExampleFurigana)
                .font(.title2).frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                .accessibilityIdentifier("grammar.assembly.answer")
            Text("Нажимай на элементы по порядку. Повторное нажатие убирает элемент.").font(.caption)
                .foregroundStyle(AppPalette.secondaryText)
            Rectangle().fill(AppPalette.border.opacity(0.5)).frame(height: 1)
            ForEach(practice.options.indices, id: \.self) { index in
                let option = practice.options[index]
                Button { practice.toggleElement(option.id) } label: {
                    HStack {
                        FuriganaText(text: option.text, furigana: exercise.ruby(for: option.text), showsFurigana: settings.showExampleFurigana).font(.title3)
                        Spacer()
                        if let index = practice.selectedElements.firstIndex(of: option.id) { Text("\(index + 1)") }
                    }.padding(.vertical, 10)
                }.buttonStyle(.plain).disabled(practice.isAnswerVisible)
                    .accessibilityIdentifier("grammar.element.\(option.id)")
                if index < practice.options.count - 1 {
                    Rectangle().fill(AppPalette.border.opacity(0.5)).frame(height: 1).padding(.leading, 30)
                }
            }
        }.accessibilityIdentifier("grammar.assembly")
    }

    private func feedback(_ exercise: GrammarExercise) -> some View {
        let correct = practice.results.last?.isCorrect == true
        let unverified = practice.results.last?.assessment == .differsFromSample
        return VStack(alignment: .leading, spacing: 8) {
            Label(correct ? "Верно" : unverified ? "Отличается от образца" : practice.results.last?.assessment == .incorrectForm ? "Ошибка проверяемой формы" : "Проверяемый ответ неверен", systemImage: correct ? "checkmark.circle" : unverified ? "info.circle" : "xmark.circle")
                .foregroundStyle(correct ? AppPalette.success : AppPalette.correction).font(.headline)
            if !correct {
                FuriganaText(text: exercise.correctAnswer, furigana: exercise.ruby(for: exercise.correctAnswer), showsFurigana: settings.showExampleFurigana).font(.title3)
                if let option = exercise.options.first(where: { $0.id == practice.selectedOptionID }), let text = option.feedbackRU {
                    FuriganaText(text: text, furigana: exercise.ruby(for: text), showsFurigana: settings.showExampleFurigana).font(.callout)
                } else if unverified {
                    Text("Ответ отличается от образца. Это не доказывает грамматическую ошибку; автоматическая оценка FSRS для этой попытки недоступна.").font(.callout)
                } else { FuriganaText(text: exercise.explanationRU, furigana: exercise.ruby(for: exercise.explanationRU), showsFurigana: settings.showExampleFurigana).font(.callout) }
                Button("Посмотреть правило") { isLessonPresented = true }
            }
        }.accessibilityIdentifier("grammar.training.feedback")
    }

    private var result: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(practice.exercises.allSatisfy { $0.isScored == false } ? "Базовая практика завершена" : practice.weakAspects.isEmpty ? "Правило закреплено" : "Практика завершена", systemImage: "checkmark.seal")
                .font(.title2.bold())
            Text("Готово! \(practice.correctCount) из \(practice.count)")
                .font(.headline).accessibilityIdentifier("grammar.training.result")
            if !practice.isSaved && practice.proposedRating == nil {
                Text("Оценка FSRS не записана: этих заданий недостаточно для проверки самостоятельного применения правила.").font(.callout)
            }
            ForEach(practice.weakAspects, id: \.self) { Text("Повтори: " + $0).font(.callout) }
            if session.isGrammarResultPending, let record = session.reviewStore.record(for: rule.reviewKey) {
                Text("Следующее повторение: \(record.dueDate.formatted(date: .abbreviated, time: .shortened))")
                    .accessibilityIdentifier("grammar.training.saved")
            } else if session.isPreparingCard || practice.isSaving {
                CenteredLoadingIndicator(title: "Сохраняю результат")
            }
        }.padding(18).appSurfaceCard()
    }
}

private struct GrammarMixedResultView: View, StudyViewStyling {
    let mixed: GrammarMixedSessionViewModel
    let session: TrainingSessionViewModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Label("Практика завершена", systemImage: "checkmark.seal").font(.title2.bold())
                Text("\(mixed.answered) заданий · \(mixed.correct) правильных")
                    .accessibilityIdentifier("grammar.mixed.result")
                Text("Повторено правил: \(mixed.repeatedRules) · Изучено новых: \(mixed.newRules)")
                if mixed.basicCompletedRules > 0 {
                    Text("Базовая практика: \(mixed.basicCompletedRules) правил без оценки FSRS.")
                }
                if !mixed.weakRules.isEmpty {
                    Text("Требует внимания").font(.headline)
                    ForEach(mixed.weakRules) { Text($0.pattern) }
                }
                if mixed.hasUnsavedResults { Text("Есть несохранённые результаты. Повтори сохранение.") }
            }.padding(.vertical, 12).appSurfaceCard().padding(.vertical, 12)
        }.safeAreaInset(edge: .bottom) {
            BottomActionBar {
                primaryActionButton(title: mixed.hasUnsavedResults ? "Сохранить результаты" : "Готово", systemImage: "checkmark",
                    accessibilityIdentifier: "grammar.mixed.finish") {
                    if mixed.hasUnsavedResults { Task { await session.saveMixedGrammarResults() } }
                    else { session.finish() }
                }.disabled(session.isPreparingCard)
            }
        }
    }
}
