import SwiftUI

struct GrammarRuleView: View, StudyViewStyling {
    @Environment(\.dismiss) private var dismiss
    let ruleID: String
    let settings: StudyPreferences
    let progress: StudyProgressStore
    let translationState: TranslationViewModel
    var onPractice: (GrammarRule) -> Void
    @State private var model = GrammarLibraryViewModel()

    var body: some View {
        VStack(spacing: 14) {
            previewHeader(title: "Грамматика", subtitle: model.rules.first(where: { $0.id == ruleID })?.level.rawValue ?? "", onBack: { dismiss() })
            ScrollView {
                if model.isLoading {
                    CenteredLoadingIndicator(title: "Загружаю правило")
                        .frame(maxWidth: .infinity, minHeight: 160)
                } else if let error = model.error {
                    VStack(spacing: 12) {
                        Text(error).foregroundStyle(AppPalette.correction)
                        Button("Повторить") { Task { await model.load() } }
                    }
                    .frame(maxWidth: .infinity, minHeight: 160)
                } else if let rule = model.rules.first(where: { $0.id == ruleID }) {
                    GrammarLessonContent(
                        rule: rule,
                        settings: settings,
                        progress: progress,
                        translationState: translationState,
                        relatedRules: model.rules
                    )
                } else if !model.isLoading {
                    Text("Правило не найдено.")
                        .frame(maxWidth: .infinity, minHeight: 160)
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 16)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .safeAreaInset(edge: .bottom) {
            if let rule = model.rules.first(where: { $0.id == ruleID }) {
                BottomActionBar {
                    primaryActionButton(title: "Практиковать", systemImage: "checklist",
                        accessibilityIdentifier: "grammar.practice") { onPractice(rule) }
                        .disabled(!GrammarExerciseEngine.hasPractice(rule))
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .background(AppPalette.background.ignoresSafeArea())
        .foregroundStyle(AppPalette.text)
        .navigationTitle(model.rules.first(where: { $0.id == ruleID })?.pattern ?? "Грамматика")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load() }
    }
}

struct GrammarLessonContent: View, StudyViewStyling {
    let rule: GrammarRule
    @Bindable var settings: StudyPreferences
    let progress: StudyProgressStore
    let translationState: TranslationViewModel
    var relatedRules: [GrammarRule] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .center, spacing: 8) {
                    Text(rule.pattern)
                        .font(.largeTitle.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("grammar.lesson.title")
                    Text(displayedMeaning)
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("grammar.lesson.meaning")
                    if let teaching = rule.teaching {
                        Text(teaching.usageRU)
                            .font(.callout)
                            .foregroundStyle(AppPalette.secondaryText)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    translationControls(
                        originalText: rule.meaning,
                        allowsRetry: rule.teaching == nil && rule.localization?.meaningRU == nil,
                        identifier: "grammar.translation.meaning"
                    )
                }

                lessonDivider
                detailBlock("Как образуется") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(displayedFormation)
                            .font(.title3.weight(.medium))
                            .foregroundStyle(AppPalette.text)
                        translationControls(
                            originalText: rule.formation,
                            allowsRetry: rule.teaching == nil && rule.localization?.formationRU == nil,
                            identifier: "grammar.translation.formation"
                        )
                    }
                }

                lessonDivider
                detailBlock("Пример") {
                    if let mainExample {
                        exampleContent(mainExample, index: -1, identifier: "grammar.example")
                    }
                }

                if let teaching = rule.teaching, !teaching.parts.isEmpty {
                    lessonDivider
                    detailBlock("Разбор предложения") {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(Array(teaching.parts.enumerated()), id: \.offset) { _, part in
                                HStack(alignment: .firstTextBaseline, spacing: 6) {
                                    Text(part.text).font(.callout.weight(.medium))
                                    Text("— " + part.roleRU)
                                        .font(.callout)
                                        .foregroundStyle(AppPalette.secondaryText)
                                }
                                .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }

                if !additionalExamples.isEmpty {
                    lessonDivider
                    DisclosureGroup("Дополнительные примеры") {
                        Toggle("Фуригана", isOn: $settings.showExampleFurigana)
                            .accessibilityIdentifier("grammar.furigana")
                        ForEach(Array(additionalExamples.enumerated()), id: \.offset) { index, example in
                            exampleContent(example, index: index, identifier: "grammar.example.additional.\(index)")
                            if index < additionalExamples.count - 1 { lessonDivider }
                        }
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("grammar.lesson.examples")
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Toggle("Фуригана", isOn: $settings.showExampleFurigana)
                        .accessibilityIdentifier("grammar.furigana")
                }

                if let localized = rule.localization {
                    lessonDivider
                    DisclosureGroup("Подробное объяснение") {
                        Text(localized.explanationRU)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("grammar.lesson.explanation")
                        if let originalNotes = rule.notes, !originalNotes.isEmpty {
                            translationControls(
                                originalText: originalNotes,
                                allowsRetry: false,
                                identifier: "grammar.translation.explanation"
                            )
                        }
                        Text(localized.formationNotesRU)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("grammar.lesson.details")
                } else if let notes = rule.notes, !notes.isEmpty {
                    lessonDivider
                    DisclosureGroup("Подробное объяснение") {
                        Text(translationState.displayedGrammarText(notes, rule: rule, language: language))
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("grammar.lesson.explanation")
                        translationControls(originalText: notes, allowsRetry: true,
                            identifier: "grammar.translation.explanation")
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("grammar.lesson.details")
                }

                if let teaching = rule.teaching, !teaching.notesRU.isEmpty {
                    lessonDivider
                    DisclosureGroup("Особенности употребления") {
                        ForEach(teaching.notesRU, id: \.self) { Text($0).font(.callout).fixedSize(horizontal: false, vertical: true) }
                    }
                } else if let localized = rule.localization, !localized.usageNotesRU.isEmpty {
                    lessonDivider
                    DisclosureGroup("Особенности употребления") {
                        ForEach(localized.usageNotesRU, id: \.self) { Text($0).font(.callout).fixedSize(horizontal: false, vertical: true) }
                    }
                }

                if let teaching = rule.teaching, !teaching.contrastsRU.isEmpty {
                    lessonDivider
                    DisclosureGroup("Похожие конструкции") {
                        ForEach(teaching.contrastsRU, id: \.self) { Text($0).font(.callout).fixedSize(horizontal: false, vertical: true) }
                    }
                }

                if let localized = rule.localization, !localized.typicalErrorsRU.isEmpty {
                    lessonDivider
                    DisclosureGroup("Типичные ошибки") {
                        ForEach(localized.typicalErrorsRU, id: \.self) { Text($0).fixedSize(horizontal: false, vertical: true) }
                    }
                }

                if let supplement = rule.supplement {
                    lessonDivider
                    DisclosureGroup("Дополнительный материал Nihongo Mono") {
                        Text(translated(supplement.summary)).font(.callout).fixedSize(horizontal: false, vertical: true)
                        translationControls(originalText: supplement.summary, allowsRetry: true,
                            identifier: "grammar.translation.supplement.summary")
                        ForEach(Array(supplement.structure.enumerated()), id: \.offset) { index, text in
                            Text(translated(text)).font(.callout).fixedSize(horizontal: false, vertical: true)
                            translationControls(originalText: text, allowsRetry: true,
                                identifier: "grammar.translation.supplement.structure.\(index)")
                        }
                        ForEach(Array(supplement.pitfalls.enumerated()), id: \.offset) { index, text in
                            Text(translated(text)).font(.callout).fixedSize(horizontal: false, vertical: true)
                            translationControls(originalText: text, allowsRetry: true,
                                identifier: "grammar.translation.supplement.pitfall.\(index)")
                        }
                        ForEach(Array(supplement.examples.enumerated()), id: \.offset) { index, example in
                            Text(example.ja).font(.title3).fixedSize(horizontal: false, vertical: true)
                            Text(translated(example.en)).font(.callout).foregroundStyle(AppPalette.secondaryText).fixedSize(horizontal: false, vertical: true)
                            translationControls(originalText: example.en, allowsRetry: true,
                                identifier: "grammar.translation.supplement.example.\(index)")
                        }
                    }
                }

                lessonDivider
                detailBlock("Практика") {
                    Text(practiceAvailability)
                        .font(.callout)
                        .foregroundStyle(AppPalette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("grammar.practice.availability")
                }

                if !relatedRelations.isEmpty {
                    lessonDivider
                    DisclosureGroup("Похожие конструкции") {
                        ForEach(relatedRelations, id: \.ruleID) { relation in
                            if let related = relatedRules.first(where: { $0.id == relation.ruleID }) {
                                NavigationLink(value: StudyRoute.grammarRule(related.level, related.id)) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("\(related.level.rawValue) · \(related.pattern)")
                                        Text(relation.explanationRU).font(.caption).foregroundStyle(AppPalette.secondaryText)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 6)
                                }
                                .accessibilityIdentifier("grammar.related.\(related.id)")
                            }
                        }
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("grammar.rule.relations")
                }

                lessonDivider
                DisclosureGroup("Источник и лицензия") {
                    Link("OpenJLPT · CC BY-SA 4.0", destination: URL(string: "https://github.com/evanclan/OpenJLPT")!)
                    Text("OpenJLPT contributors, Evan Clan. Исходные материалы и адаптации: CC BY-SA 4.0. Добавлены учебные ситуации и русские пояснения.")
                        .font(.caption).fixedSize(horizontal: false, vertical: true)
                    Link("Условия лицензии", destination: URL(string: "https://creativecommons.org/licenses/by-sa/4.0/")!)
                    if rule.supplement != nil {
                        Link("Nihongo Mono · MIT", destination: URL(string: "https://github.com/stndaru/nihongo-mono/blob/ec0ba4a0ce1611c568b0e4f8a223eb8029249a25/LICENSE-DATA.md")!)
                        Text("Оригинальные дополнительные материалы: © 2026 Stefanus Ndaru Wedhatama. MIT. Английский оригинал доступен офлайн.")
                            .font(.caption).fixedSize(horizontal: false, vertical: true)
                    }
                    Text("Уровни JLPT — неофициальная классификация. Учебные адаптации требуют лингвистического ревью.")
                        .font(.caption).fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("grammar.lesson.license")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .appSurfaceCard()
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("grammar.lesson.card")
        }
        .foregroundStyle(AppPalette.text)
        .task(id: "\(rule.id):\(language)") {
            await translationState.translateGrammarIfNeeded(rule, language: language)
        }
    }

    private var language: MeaningLanguage { settings.options(for: rule.level.deck.id).meaningLanguage }
    private var displayedMeaning: String {
        if let authored = rule.teaching?.meaningRU { return authored }
        return translationState.displayedGrammarText(rule.displayedMeaning, rule: rule, language: language)
    }
    private var displayedFormation: String {
        if let authored = rule.teaching?.formationRU { return authored }
        return translationState.displayedGrammarText(rule.displayedFormation, rule: rule, language: language)
    }
    private var mainExample: GrammarExample? { rule.teaching?.example ?? rule.examples.first }
    private var additionalExamples: [GrammarExample] {
        let examples = rule.examples + rule.studyExamples
        guard let mainExample else { return examples }
        return examples.filter { $0.ja != mainExample.ja }
    }
    private var relatedRelations: [GrammarRelation] { rule.relations ?? [] }
    private var practiceAvailability: String {
        let base = GrammarExerciseEngine.hasPractice(rule) ? "Базовая практика доступна" : "Практика пока недоступна"
        return GrammarExerciseEngine.hasExtendedPractice(rule)
            ? base + " · расширенная практика доступна"
            : base + " · расширенные материалы требуют проверки"
    }
    private var translationKey: TranslationBlockKey { .grammarContent(rule.id) }

    private func translated(_ text: String) -> String {
        translationState.displayedGrammarText(text, rule: rule, language: language)
    }

    @ViewBuilder
    private func translationControls(originalText: String, allowsRetry: Bool, identifier: String) -> some View {
        if language == .russian {
            TranslationRetryControls(
                originalText: originalText,
                isLoading: translationState.isManuallyTranslating(translationKey)
                    || translationState.isAutomaticallyTranslating(translationKey),
                action: { translationState.retranslateGrammar(rule) },
                showsRetryAction: allowsRetry,
                accessibilityIdentifier: identifier
            )
        }
    }

    private func exampleContent(_ example: GrammarExample, index: Int, identifier: String) -> some View {
        let studyExample = StudyExample(
            id: "grammar-\(rule.id)-\(index)",
            text: example.ja,
            meaning: language == .russian || example.en.isEmpty ? (example.ru ?? translated(example.en)) : translated(example.en),
            sources: exampleSources(example),
            furigana: example.ruby
        )
        return VStack(alignment: .leading, spacing: 6) {
            if example.preparationStatus == "assistantPrepared" {
                Text("Учебный контекст · подготовлено ИИ, независимое ревью не выполнено. Перевод и чтения требуют проверки.")
                    .font(.caption).foregroundStyle(AppPalette.secondaryText)
                if let target = example.targetConstruction { Text("Конструкция: " + target).font(.callout) }
                if let skill = example.skillRU { Text(skill).font(.callout) }
            }
            StudyExamplesContent(
                examples: [studyExample],
                showsFurigana: settings.showExampleFurigana,
                isLoading: false,
                loadingText: "Перевожу пример",
                emptyText: "Пример недоступен"
            ) {
                translationControls(
                    originalText: example.en,
                    allowsRetry: language == .russian && example.ru == nil,
                    identifier: "grammar.translation.example.\(index)"
                )
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier)
    }

    private func exampleSources(_ example: GrammarExample) -> [StudyExampleSource] {
        let sentenceSources = (example.sources ?? []).compactMap { source -> StudyExampleSource? in
            let author = source.author.map { " · автор: \($0)" } ?? ""
            let title = "\(source.name) · предложение #\(source.sentenceID)\(author) · \(source.license)"
            return StudyExampleSource(id: source.id, title: title, url: source.url)
        }
        let translationSources = (example.translationSources ?? []).compactMap { source -> StudyExampleSource? in
            let author = source.author.map { " · автор: \($0)" } ?? ""
            let title = "\(source.name)\(author) · \(source.license)"
            return StudyExampleSource(id: source.id, title: title, url: source.url)
        }
        return sentenceSources + translationSources
    }

    private var lessonDivider: some View {
        Rectangle().fill(AppPalette.border.opacity(0.65)).frame(height: 1)
    }
}
