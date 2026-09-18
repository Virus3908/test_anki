import Foundation
import AnkiImport

nonisolated struct PreparedAnkiCard: Sendable {
    let html: String
    let content: AnkiContent
    let warnings: [String]
    let englishTexts: [String]
}

actor AnkiCardRenderer {
    func prepare(_ card: AnkiStudyCard, answer: Bool) throws -> PreparedAnkiCard {
        try Task.checkCancellation()
        let rendered = AnkiTemplateRenderer.render(card: card.card, note: card.note, type: card.noteType,
            deckName: card.deckName, answer: answer)
        let content = AnkiContentParser.parsePreservingSource(rendered.html)
        return PreparedAnkiCard(html: rendered.html, content: content, warnings: rendered.warnings,
            englishTexts: TranslationViewModel.ankiEnglishTexts(in: content))
    }

    func translate(_ html: String, mapping: [String: String]) throws -> String {
        try Task.checkCancellation()
        return try AnkiContentParser.replacingTexts(in: html, translations: mapping)
    }
}
