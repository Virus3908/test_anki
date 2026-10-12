import SwiftUI

struct GrammarRuleView: View {
    let ruleID: String
    let settings: StudyPreferences
    let progress: StudyProgressStore
    var onPractice: (GrammarRule) -> Void
    @State private var model = GrammarLibraryViewModel()
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if model.isLoading { ProgressView("Загружаю правило") }
                if let error = model.error {
                    Text(error).foregroundStyle(AppPalette.correction)
                    Button("Повторить") { Task { await model.load() } }
                } else if let rule = model.rules.first(where: { $0.id == ruleID }) {
                    GrammarLessonContent(rule: rule, settings: settings, progress: progress)
                    if !(rule.relations ?? []).isEmpty {
                        Text("Похожие конструкции и упоминания источника").font(.headline)
                        ForEach(rule.relations ?? [], id: \.ruleID) { relation in
                            if let related = model.rules.first(where: { $0.id == relation.ruleID }) {
                                NavigationLink {
                                    GrammarRuleView(ruleID: related.id, settings: settings,
                                        progress: progress, onPractice: onPractice)
                                } label: {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("\(related.level.rawValue) · \(related.pattern)")
                                        Text(relation.explanationRU).font(.caption)
                                    }
                                }
                                .accessibilityIdentifier("grammar.related.\(related.id)")
                            }
                        }
                    }
                    Button("Практиковать") { onPractice(rule) }
                        .buttonStyle(.borderedProminent).accessibilityIdentifier("grammar.practice")
                } else if !model.isLoading {
                    Text("Правило не найдено.")
                }
            }
            .padding(16)
        }
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
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("\(rule.level.rawValue) · \(rule.pattern)").font(.title2.bold())
                .accessibilityIdentifier("grammar.lesson.title")
            if let reading = rule.reading { Text(reading) }
            if let romaji = rule.romaji { Text(romaji).foregroundStyle(AppPalette.secondaryText) }
            Text(GrammarStatistics.status(rule, progress: progress))
                .font(.caption).accessibilityIdentifier("grammar.lesson.status")
            if rule.localization == nil { GrammarContentStatus() }
            block("Значение", text: rule.displayedMeaning)
            block("Формула образования", text: rule.displayedFormation)
            if let notes = rule.localization?.formationNotesRU { block("Пояснения к формуле", text: notes) }
            if let explanation = rule.displayedExplanation {
                block("Применение и особенности", text: explanation)
                    .accessibilityIdentifier("grammar.lesson.explanation")
            } else {
                Text("В источнике нет отдельного примечания к этому правилу.").font(.caption)
            }
            if let localized = rule.localization {
                ForEach(localized.usageNotesRU, id: \.self) { block("Употребление", text: $0) }
                ForEach(localized.typicalErrorsRU, id: \.self) { block("Типичная ошибка", text: $0) }
            }
            Toggle("Фуригана", isOn: $settings.showExampleFurigana)
                .accessibilityIdentifier("grammar.furigana")
            Text("Примеры").font(.headline)
            ForEach(Array(rule.examples.enumerated()), id: \.offset) { _, example in
                VStack(alignment: .leading, spacing: 8) {
                    FuriganaText(text: example.ja, furigana: example.ruby, showsFurigana: settings.showExampleFurigana)
                    Text(example.ru ?? example.en).foregroundStyle(AppPalette.secondaryText)
                }
                .padding(16).appSurfaceCard().accessibilityIdentifier("grammar.example")
            }
            Text(rule.categories.map(\.title).joined(separator: " · ")).font(.caption)
            Link("OpenJLPT — исходный материал (CC BY-SA 4.0)",
                destination: URL(string: "https://github.com/evanclan/OpenJLPT/blob/0d1d3410bec90bd4098a7c72de820543cb4f707c/data/json/grammar/\(rule.level.rawValue.lowercased()).json")!)
                .font(.caption)
            Text("OpenJLPT contributors, Evan Clan · 0.3.0 · snapshot 0d1d341. Уровни JLPT — неофициальная классификация.")
                .font(.caption).foregroundStyle(AppPalette.secondaryText)
        }
    }
    private func block(_ title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            Text(text).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(16).appSurfaceCard()
    }
}
