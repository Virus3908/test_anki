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
    @State private var fieldDropTarget: FieldDropTarget?
    private let renderer = AnkiCardRenderer()

    private let fieldPreferences = AnkiFieldDisplayPreferences.shared

    private enum FieldSide: String, CaseIterable, Identifiable {
        case front, back
        var id: String { rawValue }
        var title: String { self == .front ? "Лицевая сторона" : "Задняя сторона" }
    }

    private struct FieldDropTarget: Equatable {
        let before: Int?
        let intoVisibleList: Bool
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
            let value = try? await renderer.prepare(card, answer: answer)
            guard !Task.isCancelled else { return }
            prepared = value
        }
        .task(id: AnkiTranslationRenderRequest(html: prepared?.html ?? "", texts: englishTexts, translated: nil, language: language.rawValue)) {
            await translationState.translateAnkiIfNeeded(key: translationKey, texts: englishTexts, language: language)
        }
        .task(id: AnkiTranslationRenderRequest(html: prepared?.html ?? "", texts: englishTexts, translated: translations, language: language.rawValue)) {
            guard let prepared, !mapping.isEmpty else { translatedHTML = nil; return }
            let html = try? await renderer.translate(prepared.html, mapping: mapping)
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
                        Text("Перетаскивайте поля между списками и меняйте их порядок.")
                            .font(.caption).foregroundStyle(AppPalette.secondaryText)
                        fieldList(title: "Показываются", ordinals: visibleFieldOrdinals, isVisible: true)
                        fieldList(title: "Скрыты", ordinals: hiddenFieldOrdinals, isVisible: false)
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

    private var visibleFieldOrdinals: [Int] {
        displayedOrdinals.filter { visibleOrdinals.contains($0) }
    }

    private var hiddenFieldOrdinals: [Int] {
        displayedOrdinals.filter { !visibleOrdinals.contains($0) }
    }

    @ViewBuilder
    private func fieldList(title: String, ordinals: [Int], isVisible: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.subheadline.weight(.semibold))
            if ordinals.isEmpty {
                Label("Перетащите поле сюда", systemImage: "arrow.down.circle")
                    .font(.caption.weight(.medium)).foregroundStyle(AppPalette.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18).appSurfaceCard()
            } else {
                ForEach(ordinals, id: \.self) { ordinal in
                    fieldRow(ordinal, intoVisibleList: isVisible)
                }
            }
        }
        .padding(8)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(fieldDropTarget == FieldDropTarget(before: nil, intoVisibleList: isVisible)
                      ? AppPalette.accent.opacity(0.12) : .clear)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(fieldDropTarget == FieldDropTarget(before: nil, intoVisibleList: isVisible)
                        ? AppPalette.accent : .clear, lineWidth: 2)
        }
        .dropDestination(for: String.self,
                         action: { items, _ in
                             return dropField(items.first, before: nil, intoVisibleList: isVisible)
                         },
                         isTargeted: { targeted in
                             updateDropTarget(targeted, before: nil, intoVisibleList: isVisible)
                         })
    }

    @ViewBuilder
    private func fieldDragPreview(_ ordinal: Int) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal")
            Text(card.noteType.fields[ordinal]).font(.body.weight(.semibold))
            Spacer()
        }
        .foregroundStyle(AppPalette.text)
        .padding(16)
        .frame(width: 300, alignment: .leading)
        .background(AppPalette.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AppPalette.accent, lineWidth: 2) }
    }

    @ViewBuilder
    private func fieldRow(_ ordinal: Int, intoVisibleList isVisible: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "line.3.horizontal")
                    .foregroundStyle(AppPalette.secondaryText)
                Text(card.noteType.fields[ordinal]).font(.body.weight(.medium))
                Spacer()
            }
            if let content = card.note.parsedFields?[safe: ordinal] {
                AnkiNativeContentView(blocks: content.blocks, mediaDirectory: card.mediaDirectory)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(12).appSurfaceCard()
        .overlay(alignment: .top) {
            if fieldDropTarget == FieldDropTarget(before: ordinal, intoVisibleList: isVisible) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down")
                    Text("Вставить сюда").font(.caption.weight(.semibold))
                }
                .foregroundStyle(AppPalette.background)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(AppPalette.accent, in: Capsule())
                .offset(y: -14)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(fieldDropTarget == FieldDropTarget(before: ordinal, intoVisibleList: isVisible)
                        ? AppPalette.accent : .clear, lineWidth: 2)
        }
        .draggable(String(ordinal)) { fieldDragPreview(ordinal) }
        .dropDestination(for: String.self,
                         action: { items, _ in
                             return dropField(items.first, before: ordinal, intoVisibleList: isVisible)
                         },
                         isTargeted: { targeted in
                             updateDropTarget(targeted, before: ordinal, intoVisibleList: isVisible)
                         })
    }

    private func updateDropTarget(_ targeted: Bool, before: Int?, intoVisibleList: Bool) {
        let target = FieldDropTarget(before: before, intoVisibleList: intoVisibleList)
        if targeted { fieldDropTarget = target }
        else if fieldDropTarget == target { fieldDropTarget = nil }
    }

    private func dropField(_ value: String?, before destination: Int?, intoVisibleList: Bool) -> Bool {
        fieldDropTarget = nil
        guard let value, let ordinal = Int(value), displayedOrdinals.contains(ordinal) else { return false }
        var visible = visibleFieldOrdinals
        var hidden = hiddenFieldOrdinals
        visible.removeAll { $0 == ordinal }
        hidden.removeAll { $0 == ordinal }
        var target = intoVisibleList ? visible : hidden
        if let destination, let index = target.firstIndex(of: destination) {
            target.insert(ordinal, at: index)
        } else {
            target.append(ordinal)
        }
        if intoVisibleList { visible = target } else { hidden = target }
        updateFieldOptions { options in
            if fieldSide == .front {
                options.frontOrder = visible + hidden
                options.frontVisible = Set(visible)
            } else {
                options.backOrder = visible + hidden
                options.backVisible = Set(visible)
            }
        }
        return true
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

nonisolated private struct AnkiTranslationRenderRequest: Hashable {
    let html: String
    let texts: [String]
    let translated: [String]?
    let language: String
}
