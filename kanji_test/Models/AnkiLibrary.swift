import Foundation
import AnkiImport

nonisolated struct AnkiImportSummary: Codable, Sendable, Identifiable {
    let id: String
    let directory: String
    let filename: String
    let importedAt: Date
    let decks: [AnkiDeck]
    let cardCount: Int
    let noteCount: Int
    let mediaCount: Int
    let warnings: [String]
    var deckCardCounts: [String: Int]? = nil
    var schedulingMigrationVersion: String? = nil
}

nonisolated struct AnkiDeckReference: Identifiable, Hashable, Sendable {
    let importID: String
    let sourceDeckID: Int64
    let title: String
    let cardCount: Int
    var id: String { "anki:\(importID):deck:\(sourceDeckID)" }
    var studyDeck: StudyDeck { .init(id: id, title: title, mode: .anki) }
}

nonisolated struct AnkiStudyCard: Identifiable, Sendable, StudyItem {
    let importID: String
    let card: AnkiCard
    let note: AnkiNote
    let noteType: AnkiNoteType
    let deckName: String
    let mediaDirectory: URL
    nonisolated var id: String { "\(importID):card:\(card.id)" }
    nonisolated var reviewKey: String { "anki:\(id)" }
    var fieldPreferencesKey: String { "\(importID):\(card.deckID):\(noteType.id)" }
    var displayTitle: String {
        displayTitle(using: .defaults(fieldCount: noteType.fields.count))
    }

    func displayTitle(using options: AnkiFieldDisplayOptions) -> String {
        let text = (note.parsedFields?[safe: options.titleOrdinal]?.plainText ?? note.fields[safe: options.titleOrdinal] ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? "Карточка \(card.id)" : String(text.prefix(120))
    }
    var templateName: String {
        noteType.isCloze ? "Пропуск \(card.ordinal + 1)" : noteType.templates.first(where: { $0.ordinal == card.ordinal })?.name ?? noteType.name
    }

    /// Keeps incomplete vocabulary notes available without letting them occupy the
    /// beginning of a deck. The partition is stable, so Anki's order is preserved
    /// within both groups.
    static func orderedWithContentlessCardsLast(_ cards: [Self]) -> [Self] {
        var regular: [Self] = []
        var contentless: [Self] = []
        regular.reserveCapacity(cards.count)
        contentless.reserveCapacity(cards.count)

        for card in cards {
            if card.hasNeitherMeaningNorExamples {
                contentless.append(card)
            } else {
                regular.append(card)
            }
        }
        return regular + contentless
    }

    private var hasNeitherMeaningNorExamples: Bool {
        let meaningFields = semanticFieldOrdinals(matching: Self.meaningFieldNames)
        let exampleFields = semanticFieldOrdinals(matching: Self.exampleFieldNames)

        // Unknown note types should retain their original order: their fields may
        // carry the same information under names we cannot classify safely.
        guard !meaningFields.isEmpty || !exampleFields.isEmpty else { return false }
        return !meaningFields.contains(where: fieldHasContent)
            && !exampleFields.contains(where: fieldHasContent)
    }

    private func semanticFieldOrdinals(matching names: Set<String>) -> [Int] {
        noteType.fields.indices.filter { ordinal in
            let fieldName = noteType.fields[ordinal]
                .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
            let words = fieldName.components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { !$0.isEmpty }
            return words.contains(where: names.contains)
                || (names == Self.meaningFieldNames && fieldName.contains("意味"))
                || (names == Self.exampleFieldNames && (fieldName.contains("例文") || fieldName.contains("用例")))
        }
    }

    private func fieldHasContent(_ ordinal: Int) -> Bool {
        if let parsed = note.parsedFields?[safe: ordinal] {
            return parsed.blocks.contains(where: Self.blockHasContent)
        }
        guard let raw = note.fields[safe: ordinal] else { return false }
        let text = raw
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ", options: .caseInsensitive)
            .replacingOccurrences(of: "\u{00a0}", with: " ")
        return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static func blockHasContent(_ block: AnkiContentBlock) -> Bool {
        switch block.kind {
        case .text:
            block.runs.contains { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        case .image, .audio, .video:
            true
        case .hint:
            block.children.contains(where: blockHasContent)
        case .divider, .input:
            false
        }
    }

    private static let meaningFieldNames: Set<String> = [
        "meaning", "meanings", "definition", "definitions", "translation", "translations", "gloss",
        "answer", "back", "значение", "значения", "перевод", "переводы"
    ]

    private static let exampleFieldNames: Set<String> = [
        "example", "examples", "sentence", "sentences", "usage", "context",
        "пример", "примеры", "предложение", "предложения"
    ]
}

nonisolated struct AnkiImportResult: Sendable {
    let summary: AnkiImportSummary
    let alreadyImported: Bool
}
