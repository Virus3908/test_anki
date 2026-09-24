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

    /// Anki stores the position of new cards in `cards.due`. Reorder only the
    /// new-card slots by that position, keeping all other cards in source order.
    static func orderedByAnkiPosition(_ cards: [Self]) -> [Self] {
        let newCards = cards
            .filter { $0.card.scheduling["type"] == 0 }
            .sorted {
                let left = $0.card.scheduling["due", default: 0]
                let right = $1.card.scheduling["due", default: 0]
                return left == right ? $0.card.id < $1.card.id : left < right
            }

        var nextNewCard = 0
        return cards.map { card in
            guard card.card.scheduling["type"] == 0, nextNewCard < newCards.count else { return card }
            defer { nextNewCard += 1 }
            return newCards[nextNewCard]
        }
    }
}

nonisolated struct AnkiImportResult: Sendable {
    let summary: AnkiImportSummary
    let alreadyImported: Bool
}
