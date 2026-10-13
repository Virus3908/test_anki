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
                        .disabled(!GrammarExerciseEngine.hasPractice(rule))
                    Text(GrammarExerciseEngine.hasExtendedPractice(rule) ? "Базовая практика · Расширенная практика" : GrammarExerciseEngine.hasPractice(rule) ? "Базовая практика · Расширенная требует проверки" : "Требует проверки").font(.caption).foregroundStyle(AppPalette.secondaryText)
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

struct GrammarLessonContent: View, StudyViewStyling {
    let rule: GrammarRule
    @Bindable var settings: StudyPreferences
    let progress: StudyProgressStore
    let translationState: TranslationViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .center, spacing: 8) {
                    Text(rule.pattern)
                        .font(.largeTitle.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("grammar.lesson.title")
                    Text(rule.teaching?.meaningRU ?? translated(rule.displayedMeaning))
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    if let teaching = rule.teaching {
                        Text(teaching.usageRU)
                            .font(.callout)
                            .foregroundStyle(AppPalette.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                lessonDivider

                detailBlock("Как образуется") {
                    Text(rule.teaching?.formationRU ?? translated(rule.displayedFormation))
                        .font(.title3.weight(.medium))
                        .foregroundStyle(AppPalette.text)
                }

                if let teaching = rule.teaching {
                    lessonDivider
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Пример").font(.caption.weight(.bold)).foregroundStyle(AppPalette.secondaryText)
                        FuriganaText(text: teaching.example.ja, furigana: teaching.example.ruby,
                                     showsFurigana: settings.showExampleFurigana)
                            .font(.title2)
                            .fixedSize(horizontal: false, vertical: true)
                        if let meaning = teaching.example.ru, !meaning.isEmpty {
                            Text(meaning).foregroundStyle(AppPalette.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .accessibilityIdentifier("grammar.example")

                    lessonDivider
                    detailBlock("Разбор") {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(Array(teaching.parts.enumerated()), id: \.offset) { _, part in
                                HStack(alignment: .firstTextBaseline, spacing: 6) {
                                    Text(part.text).font(.callout.weight(.medium))
                                    Text("— " + part.roleRU).font(.callout).foregroundStyle(AppPalette.secondaryText)
                                }
                                .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                } else if let example = rule.examples.first {
                    lessonDivider
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Пример").font(.caption.weight(.bold)).foregroundStyle(AppPalette.secondaryText)
                        FuriganaText(text: example.ja, furigana: example.ruby,
                                     showsFurigana: settings.showExampleFurigana)
                            .font(.title2).fixedSize(horizontal: false, vertical: true)
                        Text(example.ru ?? translated(example.en))
                            .foregroundStyle(AppPalette.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityIdentifier("grammar.example")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .appSurfaceCard()

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
                ForEach(Array(rule.examples.enumerated()), id: \.offset) { index, example in
                    exampleView(example)
                    if index < rule.examples.count - 1 { lessonDivider }
                }
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
        .foregroundStyle(AppPalette.text)
        .task(id: "\(rule.id):\(language)") { await translationState.translateGrammarIfNeeded(rule, language: language) }
    }
    private var lessonDivider: some View {
        Rectangle().fill(AppPalette.border.opacity(0.65)).frame(height: 1)
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
