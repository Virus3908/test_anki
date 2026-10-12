import SwiftUI

/// Specialized presentation adapter over the existing persisted training session.
struct GrammarTrainingView: View {
    let session: TrainingSessionViewModel
    let settings: StudyPreferences
    let onOpenSettings: () -> Void
    var body: some View {
        VStack {
            HStack {
                Button("К колоде") { session.finish() }.accessibilityIdentifier("grammar.training.exit")
                Spacer()
                Button("Отменить ответ") { Task { await session.moveToPreviousCard() } }
                    .disabled(!session.canGoBack).accessibilityIdentifier("grammar.training.undo")
            }.padding(.horizontal)
            if let rule = session.currentGrammarRule {
                GrammarPracticeCard(rule: rule, session: session, settings: settings)
                    .id("\(rule.id):\(session.reviewStore.record(for: rule.reviewKey)?.attempts ?? 0):\(session.scrollToTopToken)")
            } else {
                Text("Нет правил, доступных сейчас.")
            }
        }
        .foregroundStyle(AppPalette.text).background(AppPalette.background)
        .disabled(session.isPreparingCard).toolbar(.hidden, for: .navigationBar)
        .cornerGlassControls(onOpenSettings: onOpenSettings)
        .onChange(of: session.options) { Task { await session.refreshForNewDay() } }
        .task(id: session.state.nextLearningDate) {
            guard let date = session.state.nextLearningDate else { return }
            let delay = max(0, date.timeIntervalSince(session.reviewStore.studyDate()))
            do { try await Task.sleep(for: .seconds(delay + 0.1)) } catch { return }
            await session.refreshForNewDay()
        }
    }
}

private struct GrammarPracticeCard: View {
    let rule: GrammarRule
    let session: TrainingSessionViewModel
    let settings: StudyPreferences
    @State private var practice: GrammarPracticeViewModel
    @State private var isLessonPresented = false
    @State private var isLessonRead: Bool

    init(rule: GrammarRule, session: TrainingSessionViewModel, settings: StudyPreferences) {
        self.rule = rule; self.session = session; self.settings = settings
        let attempts = session.reviewStore.record(for: rule.reviewKey)?.attempts ?? 0
        _practice = State(initialValue: GrammarPracticeViewModel(rule: rule, seed: "\(rule.id):\(attempts)"))
        _isLessonRead = State(initialValue: session.reviewStore.record(for: rule.reviewKey) != nil)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("\(rule.level.rawValue) · \(rule.pattern)").font(.title2.bold())
                Text("Осталось на сегодня: \(session.sessionTotalCards)").font(.caption)
                if !isLessonRead {
                    GrammarLessonContent(rule: rule, settings: settings, progress: session.reviewStore)
                    Button("Перейти к самопроверке") { isLessonRead = true }
                        .buttonStyle(.borderedProminent).accessibilityIdentifier("grammar.training.begin")
                } else if practice.isComplete {
                    Text("Самопроверка завершена. Оцени знание всего правила, учитывая формулу, значение и пример.")
                    if !practice.isSelfAssessment {
                        Text("Правильных ответов: \(practice.results.filter(\.isCorrect).count) / \(practice.results.count)")
                    }
                    Text("Одна оценка обновит расписание правила. Результаты отдельных заданий не создают записи FSRS.")
                        .font(.caption).foregroundStyle(AppPalette.secondaryText)
                    TrainingRatingBar(isAnswerVisible: true, isPreparingCard: session.isPreparingCard,
                        intervalLabel: session.intervalLabel) { rating in
                            Task { await session.submitReview(rating, expectedKey: rule.reviewKey) }
                        }
                        .accessibilityIdentifier("grammar.training.rating")
                } else {
                    Text("\(practice.isSelfAssessment ? "Самопроверка" : "Задание") \(practice.position + 1) / \(practice.count)")
                        .font(.headline)
                    if practice.isSelfAssessment, let prompt = practice.currentRecall {
                        Text(prompt.question)
                        Text(prompt.cue).font(.title3).textSelection(.enabled)
                        if practice.isAnswerVisible {
                            Text(prompt.sourceAnswer).fixedSize(horizontal: false, vertical: true)
                            Text("Сравни со своим ответом. Автоматическая проверка не выполняется.")
                                .font(.caption).foregroundStyle(AppPalette.secondaryText)
                        } else {
                            Button("Показать исходный ответ") { practice.reveal() }
                                .buttonStyle(.borderedProminent).accessibilityIdentifier("grammar.training.reveal")
                        }
                    } else if let exercise = practice.currentExercise {
                        Text(exercise.promptRU)
                        ForEach(practice.options) { option in
                            Button(option.text) { practice.choose(option.id) }
                                .buttonStyle(.bordered).disabled(practice.isAnswerVisible)
                        }
                        if practice.isAnswerVisible {
                            Text(practice.results.last?.isCorrect == true ? "Верно" : "Неверно")
                            Text(exercise.explanationRU)
                            if let option = exercise.options.first(where: { $0.id == practice.selectedOptionID }),
                               !exercise.accepts(option.id), let feedback = option.feedbackRU { Text(feedback) }
                        }
                    }
                    if practice.isAnswerVisible {
                        Button("Дальше") { practice.next() }
                            .buttonStyle(.borderedProminent).accessibilityIdentifier("grammar.training.next")
                    }
                }
                if isLessonRead {
                    Button("Открыть объяснение") { isLessonPresented = true }
                }
            }
            .padding(20).frame(maxWidth: .infinity, alignment: .leading)
        }
        .sheet(isPresented: $isLessonPresented) {
            NavigationStack {
                ScrollView { GrammarLessonContent(rule: rule, settings: settings, progress: session.reviewStore).padding(16) }
                    .background(AppPalette.background)
                    .toolbar { Button("Закрыть") { isLessonPresented = false } }
            }
        }
    }
}
