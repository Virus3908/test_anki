import Foundation

public struct AnkiDeck: Codable, Sendable, Identifiable {
    public let id: Int64
    public let name: String
}

public struct AnkiTemplate: Codable, Sendable {
    public let ordinal: Int
    public let name: String
    public let question: String
    public let answer: String
}

public struct AnkiNoteType: Codable, Sendable, Identifiable {
    public let id: Int64
    public let name: String
    public let isCloze: Bool
    public let fields: [String]
    public let templates: [AnkiTemplate]
    public let css: String
}

public struct AnkiNote: Codable, Sendable, Identifiable {
    public let id: Int64
    public let guid: String
    public let noteTypeID: Int64
    public let fields: [String]
    public let tags: [String]
    public var parsedFields: [AnkiContent]? = nil
}

public struct AnkiCard: Codable, Sendable, Identifiable {
    public let id: Int64
    public let noteID: Int64
    public let deckID: Int64
    public let ordinal: Int
    /// Original Anki values. These are not converted into the application's FSRS state.
    public let scheduling: [String: Int64]
}

public struct AnkiMedia: Codable, Sendable {
    public let name: String
    public let size: Int
}

public struct AnkiCollection: Codable, Sendable {
    public let decks: [AnkiDeck]
    public let noteTypes: [AnkiNoteType]
    public var notes: [AnkiNote]
    public let cards: [AnkiCard]
    public var media: [AnkiMedia] = []
    public var warnings: [String] = []
}

public enum AnkiImportError: LocalizedError {
    case invalid(String)
    case limit
    case unsupported(Int)

    public var errorDescription: String? {
        switch self {
        case .invalid(let detail): "Не удалось импортировать Anki: \(detail)"
        case .limit: "Колода превышает лимит импорта: 512 МБ для базы, 256 МБ на медиафайл, 4 ГБ всего."
        case .unsupported(let version): "Версия пакета Anki \(version) пока не поддерживается."
        }
    }
}
