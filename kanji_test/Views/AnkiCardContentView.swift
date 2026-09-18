import SwiftUI
import AnkiImport

/// Shared by deck preview and SRS training; the imported HTML stays inside the standard app card.
@MainActor
struct AnkiCardContentView: View {
    let card: AnkiStudyCard
    let answer: Bool
    let translationState: TranslationViewModel
    let language: MeaningLanguage
    @AppStorage("ankiCardDisplayMode") private var displayMode = "native"
    @State private var showFields = false
    @State private var fieldSide = FieldSide.front
    @State private var prepared: PreparedAnkiCard?
    @State private var translatedHTML: String?

    private let fieldPreferences = AnkiFieldDisplayPreferences.shared

    private enum FieldSide: String, CaseIterable, Identifiable {
        case front, back
        var id: String { rawValue }
        var title: String { self == .front ? "Лицевая сторона" : "Задняя сторона" }
    }

    private var translationKey: TranslationBlockKey { .ankiContent("\(card.id):\(answer ? "answer" : "question")") }
    private var fieldOptions: AnkiFieldDisplayOptions {
        fieldPreferences.options(for: card.fieldPreferencesKey, fieldCount: card.noteType.fields.count)
    }
    private var hasCustomFields: Bool { fieldPreferences.hasCustomOptions(for: card.fieldPreferencesKey) }
    private var englishTexts: [String] {
        if displayMode == "native", hasCustomFields {
            return TranslationViewModel.ankiEnglishTexts(in: nativeContent)
        }
        return prepared?.englishTexts ?? []
    }
    private var translations: [String]? {
        language == .russian ? translationState.cached(translationKey, source: englishTexts) : nil
    }
    private var mapping: [String: String] {
        guard let translations, translations.count == englishTexts.count else { return [:] }
        return Dictionary(uniqueKeysWithValues: zip(englishTexts, translations).map { source, translated in
            let leading = source.prefix(while: \.isWhitespace)
            let trailing = source.reversed().prefix(while: \.isWhitespace).reversed()
            return (source, String(leading) + translated.trimmingCharacters(in: .whitespacesAndNewlines) + String(trailing))
        })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(answer ? "Ответ" : "Задание")
                    .font(.caption.weight(.bold)).textCase(.uppercase)
                Spacer()
                Button("Все поля", systemImage: "list.bullet.rectangle") { showFields = true }
                    .font(.caption)
            }.foregroundStyle(AppPalette.secondaryText)
            if let prepared {
                if displayMode == "template" {
                    AnkiHTMLView(html: translatedHTML ?? prepared.html, mediaDirectory: card.mediaDirectory)
                        .id("\(card.id)-\(answer)").frame(minHeight: 240)
                } else {
                    ScrollView {
                        AnkiNativeContentView(blocks: (hasCustomFields ? nativeContent : prepared.content).replacingTexts(mapping).blocks,
                                              mediaDirectory: card.mediaDirectory)
                            .id("\(card.id)-\(answer)")
                    }.frame(minHeight: 240)
                }
                if language == .russian, !englishTexts.isEmpty {
                    if translationState.isAutomaticallyTranslating(translationKey) {
                        ProgressView("Перевожу…").font(.caption)
                    }
                    TranslationRetryControls(originalText: englishTexts.joined(separator: "\n"),
                        isLoading: translationState.isManuallyTranslating(translationKey)) {
                        translationState.retranslateAnki(key: translationKey, texts: englishTexts)
                    }
                }
                let warnings = prepared.warnings + (displayMode == "native" ? prepared.content.warnings : [])
                if !warnings.isEmpty {
                DisclosureGroup("Особенности шаблона") {
                    ScrollView { Text(warnings.joined(separator: "\n")).font(.caption) }
                        .frame(maxHeight: 90)
                }.font(.caption).foregroundStyle(AppPalette.secondaryText)
                }
            } else { ProgressView("Открываю карточку…").frame(maxWidth: .infinity, minHeight: 240) }
        }
        .padding(18).appSurfaceCard()
        .task(id: "\(card.id)-\(answer)") {
            prepared = nil; translatedHTML = nil
            let sourceCard = card
            let isAnswer = answer
            let value = await Task.detached(priority: .userInitiated) {
                let rendered = AnkiTemplateRenderer.render(card: sourceCard.card, note: sourceCard.note, type: sourceCard.noteType,
                    deckName: sourceCard.deckName, answer: isAnswer)
                let content = AnkiContentParser.parsePreservingSource(rendered.html)
                return PreparedAnkiCard(html: rendered.html, content: content, warnings: rendered.warnings,
                    englishTexts: TranslationViewModel.ankiEnglishTexts(in: content))
            }.value
            guard !Task.isCancelled else { return }
            prepared = value
        }
        .task(id: AnkiTranslationRenderRequest(html: prepared?.html ?? "", texts: englishTexts, translated: nil, language: language.rawValue)) {
            await translationState.translateAnkiIfNeeded(key: translationKey, texts: englishTexts, language: language)
        }
        .task(id: AnkiTranslationRenderRequest(html: prepared?.html ?? "", texts: englishTexts, translated: translations, language: language.rawValue)) {
            guard let prepared, !mapping.isEmpty else { translatedHTML = nil; return }
            let values = mapping
            let html = await Task.detached(priority: .userInitiated) {
                try? AnkiContentParser.replacingTexts(in: prepared.html, translations: values)
            }.value
            guard !Task.isCancelled else { return }
            translatedHTML = html
        }
        .sheet(isPresented: $showFields) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(card.noteType.name).font(.headline)
                        Picker("Сторона", selection: $fieldSide) {
                            ForEach(FieldSide.allCases) { side in Text(side.title).tag(side) }
                        }.pickerStyle(.segmented)
                        Picker("Заголовок карточки", selection: Binding(
                            get: { fieldOptions.titleOrdinal },
                            set: { ordinal in updateFieldOptions { $0.titleOrdinal = ordinal } })) {
                            ForEach(Array(card.noteType.fields.enumerated()), id: \.offset) { ordinal, name in Text(name).tag(ordinal) }
                        }
                        Text("Поля можно скрыть и расположить в нужном порядке для каждой стороны.")
                            .font(.caption).foregroundStyle(AppPalette.secondaryText)
                        ForEach(displayedOrdinals, id: \.self) { ordinal in
                            let name = card.noteType.fields[ordinal]
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Toggle(name, isOn: Binding(
                                        get: { isVisible(ordinal) },
                                        set: { setVisible($0, ordinal: ordinal) }))
                                    Button { moveField(ordinal, direction: -1) } label: { Image(systemName: "chevron.up") }
                                        .disabled(!canMove(ordinal, direction: -1))
                                    Button { moveField(ordinal, direction: 1) } label: { Image(systemName: "chevron.down") }
                                        .disabled(!canMove(ordinal, direction: 1))
                                }
                                if let content = card.note.parsedFields?[safe: ordinal] {
                                    AnkiNativeContentView(blocks: content.blocks, mediaDirectory: card.mediaDirectory)
                                }
                                DisclosureGroup("Исходное поле Anki") {
                                    Text(card.note.fields[safe: ordinal] ?? "").font(.caption).textSelection(.enabled)
                                }
                            }.frame(maxWidth: .infinity, alignment: .leading).padding(12).appSurfaceCard()
                        }
                        if !card.note.tags.isEmpty { Text(card.note.tags.joined(separator: ", ")).font(.footnote) }
                    }.padding(20)
                }.background(AppPalette.background).foregroundStyle(AppPalette.text)
                    .navigationTitle("Поля заметки")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { Button("Готово") { showFields = false } }
            }
        }
    }

    private var displayedOrdinals: [Int] {
        fieldSide == .front ? fieldOptions.frontOrder : fieldOptions.backOrder
    }

    private var visibleOrdinals: Set<Int> {
        fieldSide == .front ? fieldOptions.frontVisible : fieldOptions.backVisible
    }

    private func isVisible(_ ordinal: Int) -> Bool { visibleOrdinals.contains(ordinal) }

    private func setVisible(_ visible: Bool, ordinal: Int) {
        updateFieldOptions { options in
            if fieldSide == .front {
                if visible { options.frontVisible.insert(ordinal) } else { options.frontVisible.remove(ordinal) }
            } else {
                if visible { options.backVisible.insert(ordinal) } else { options.backVisible.remove(ordinal) }
            }
        }
    }

    private func canMove(_ ordinal: Int, direction: Int) -> Bool {
        guard let index = displayedOrdinals.firstIndex(of: ordinal) else { return false }
        return displayedOrdinals.indices.contains(index + direction)
    }

    private func moveField(_ ordinal: Int, direction: Int) {
        guard let index = displayedOrdinals.firstIndex(of: ordinal), displayedOrdinals.indices.contains(index + direction) else { return }
        updateFieldOptions { options in
            if fieldSide == .front { options.frontOrder.swapAt(index, index + direction) }
            else { options.backOrder.swapAt(index, index + direction) }
        }
    }

    private func updateFieldOptions(_ change: (inout AnkiFieldDisplayOptions) -> Void) {
        var options = fieldOptions
        change(&options)
        fieldPreferences.update(options, for: card.fieldPreferencesKey, fieldCount: card.noteType.fields.count)
    }

    private var nativeContent: AnkiContent {
        let fields = card.note.parsedFields ?? card.note.fields.map { AnkiContentParser.parsePreservingSource($0) }
        let order = answer ? fieldOptions.backOrder : fieldOptions.frontOrder
        let visible = answer ? fieldOptions.backVisible : fieldOptions.frontVisible
        var content = AnkiContentParser.parsePreservingSource("")
        content.blocks = order.filter { visible.contains($0) }.flatMap { fields[safe: $0]?.blocks ?? [] }
        content.warnings = []
        return content
    }
}

nonisolated private struct PreparedAnkiCard: Sendable {
    let html: String
    let content: AnkiContent
    let warnings: [String]
    let englishTexts: [String]
}

nonisolated private struct AnkiTranslationRenderRequest: Hashable {
    let html: String
    let texts: [String]
    let translated: [String]?
    let language: String
}
