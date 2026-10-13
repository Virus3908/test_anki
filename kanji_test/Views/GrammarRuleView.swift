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
            VStack(alignment: .leading, spacing: 16) {
                if model.isLoading { CenteredLoadingIndicator(title: "Загружаю правило") }
                if let error = model.error {
                    Text(error).foregroundStyle(AppPalette.correction)
                    Button("Повторить") { Task { await model.load() } }
                } else if let rule = model.rules.first(where: { $0.id == ruleID }) {
                    GrammarLessonContent(rule: rule, settings: settings, progress: progress, translationState: translationState)
                    if !(rule.relations ?? []).isEmpty {
                        DisclosureGroup("Похожие конструкции") {
                        ForEach(rule.relations ?? [], id: \.ruleID) { relation in
                            if let related = model.rules.first(where: { $0.id == relation.ruleID }) {
                                NavigationLink {
                                    GrammarRuleView(ruleID: related.id, settings: settings,
                                        progress: progress, translationState: translationState, onPractice: onPractice)
                                } label: {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("\(related.level.rawValue) · \(related.pattern)")
                                        Text(relation.explanationRU).font(.caption)
                                    }
                                }
                                .accessibilityIdentifier("grammar.related.\(related.id)")
                            }
                        }
                        }.accessibilityIdentifier("grammar.rule.relations")
                    }

                } else if !model.isLoading {
                    Text("Правило не найдено.")
                }
            }
            .padding(16)
        }
        }
        .padding(.horizontal, 12).padding(.top, 8)
        .safeAreaInset(edge: .bottom) {
            if let rule = model.rules.first(where: { $0.id == ruleID }) {
                BottomActionBar {
                    primaryActionButton(title: "Попробовать", systemImage: "checklist",
                        accessibilityIdentifier: "grammar.practice") { onPractice(rule) }
                        .disabled(rule.teaching == nil || (rule.exercises ?? []).filter(\.eligibleForPractice).count < 3)
                    if rule.teaching == nil { Text("Практика готовится").font(.caption).foregroundStyle(AppPalette.secondaryText) }
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .background(AppPalette.background).foregroundStyle(AppPalette.text)
        .navigationTitle(model.rules.first(where: { $0.id == ruleID })?.pattern ?? "Грамматика")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load() }
    }
}

struct GrammarLessonContent: View {
    let rule: GrammarRule
    @Bindable var settings: StudyPreferences
    let progress: StudyProgressStore
    let translationState: TranslationViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(rule.pattern).font(.largeTitle.weight(.semibold))
                .accessibilityIdentifier("grammar.lesson.title")
            Text(rule.teaching?.meaningRU ?? translated(rule.displayedMeaning)).font(.title3)
            if let teaching = rule.teaching {
                Text(teaching.usageRU).foregroundStyle(AppPalette.secondaryText)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Как образуется").font(.headline)
                Text(rule.teaching?.formationRU ?? translated(rule.displayedFormation))
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let teaching = rule.teaching {
                VStack(alignment: .leading, spacing: 12) {
                    Text(highlighted(teaching)).font(.title2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(teaching.example.ru ?? "").foregroundStyle(AppPalette.secondaryText)
                    ForEach(Array(teaching.parts.enumerated()), id: \.offset) { _, part in
                        Text(part.text + " — " + part.roleRU).font(.callout)
                    }
                }.accessibilityIdentifier("grammar.example")
            } else if let example = rule.examples.first {
                exampleView(example)
            }
            DisclosureGroup("Подробное объяснение") {
                if let text = rule.displayedExplanation {
                    Text(translated(text)).fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("grammar.lesson.explanation")
                }
                if let text = rule.localization?.formationNotesRU { Text(text) }
            }.accessibilityIdentifier("grammar.lesson.details")
            DisclosureGroup("Дополнительные примеры") {
                Toggle("Фуригана", isOn: $settings.showExampleFurigana)
                    .accessibilityIdentifier("grammar.furigana")
                ForEach(Array(rule.examples.enumerated()), id: \.offset) { _, example in exampleView(example) }
            }.accessibilityIdentifier("grammar.lesson.examples")
            if let teaching = rule.teaching {
                DisclosureGroup("Особенности употребления") {
                    ForEach(teaching.notesRU, id: \.self) { Text($0).font(.callout) }
                }
                if !teaching.contrastsRU.isEmpty {
                    DisclosureGroup("Похожие конструкции") {
                        ForEach(teaching.contrastsRU, id: \.self) { Text($0).font(.callout) }
                    }
                }
            }
            if let localized = rule.localization {
                DisclosureGroup("Типичные ошибки") {
                    ForEach(localized.typicalErrorsRU, id: \.self) { Text($0) }
                }
            }
            if let supplement = rule.supplement {
                DisclosureGroup("Дополнительный материал Nihongo Mono") {
                    Text(supplement.summary).font(.callout)
                    ForEach(supplement.structure, id: \.self) { Text($0).font(.callout) }
                    ForEach(supplement.pitfalls, id: \.self) { Text($0).font(.callout) }
                    ForEach(Array(supplement.examples.enumerated()), id: \.offset) { _, example in
                        Text(example.ja).font(.title3).fixedSize(horizontal: false, vertical: true)
                        Text(example.en).font(.callout).foregroundStyle(AppPalette.secondaryText)
                    }
                }
            }
            DisclosureGroup("Источник и лицензия") {
                Link("OpenJLPT · CC BY-SA 4.0", destination: URL(string: "https://github.com/evanclan/OpenJLPT")!)
                Text("OpenJLPT contributors, Evan Clan. Исходные материалы и адаптации: CC BY-SA 4.0. Добавлены учебные ситуации и русские пояснения.").font(.caption)
                Link("Условия лицензии", destination: URL(string: "https://creativecommons.org/licenses/by-sa/4.0/")!)
                if rule.supplement != nil {
                    Link("Nihongo Mono · MIT", destination: URL(string: "https://github.com/stndaru/nihongo-mono/blob/ec0ba4a0ce1611c568b0e4f8a223eb8029249a25/LICENSE-DATA.md")!)
                    Text("Оригинальные дополнительные материалы: © 2026 Stefanus Ndaru Wedhatama. MIT. Английский оригинал доступен офлайн.").font(.caption)
                }
                Text("Уровни JLPT — неофициальная классификация. Учебные адаптации требуют лингвистического ревью.").font(.caption)
            }
        }
        .task(id: "\(rule.id):\(language)") { await translationState.translateGrammarIfNeeded(rule, language: language) }
    }
    private var language: MeaningLanguage { settings.options(for: rule.level.deck.id).meaningLanguage }
    private func translated(_ text: String) -> String { translationState.displayedGrammarText(text, rule: rule, language: language) }
    private func highlighted(_ teaching: GrammarTeaching) -> AttributedString {
        var text = AttributedString(teaching.example.ja)
        for part in teaching.parts where part.highlight != false {
            if let range = text.range(of: part.text) { text[range].foregroundColor = AppPalette.accent }
        }
        return text
    }
    private func exampleView(_ example: GrammarExample) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            FuriganaText(text: example.ja, furigana: example.ruby, showsFurigana: settings.showExampleFurigana)
                .font(.title2)
            Text(example.ru ?? translated(example.en)).foregroundStyle(AppPalette.secondaryText)
        }.padding(.vertical, 12).accessibilityIdentifier("grammar.example")
    }
}
