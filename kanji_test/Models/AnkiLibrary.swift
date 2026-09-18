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
}

nonisolated struct AnkiImportResult: Sendable {
    let summary: AnkiImportSummary
    let alreadyImported: Bool
}
