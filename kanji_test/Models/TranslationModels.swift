import Foundation

nonisolated enum TranslationBlockKey: Hashable, Sendable {
    case kanjiMeaning(String), kanjiExamples(String), wordMeaning(String), wordExamples(String)
    case ankiContent(String)
    var storageKey: String {
        switch self {
        case .kanjiMeaning(let id): return "kanji-meaning:\(id):ru"
        case .kanjiExamples(let id): return "kanji-examples:\(id):ru"
        case .wordMeaning(let id): return "word-meaning:\(id):ru"
        case .wordExamples(let id): return "word-examples:\(id):ru"
        case .ankiContent(let id): return "anki-content:\(id):ru"
        }
    }
}

nonisolated struct StoredTextTranslation: Codable, Sendable {
    let source: [String]
    let sourceLanguage: String
    let targetLanguage: String
    let texts: [String]
    func matches(_ fingerprint: [String]) -> Bool {
        source == fingerprint && sourceLanguage == "en" && targetLanguage == "ru"
    }
}

nonisolated struct TranslationStore: Codable, Sendable {
    var entries: [String: StoredTextTranslation] = [:]
    // Kept only until the old, unbound translation is adopted against its first source text.
    var legacy = KanjiTranslationStore()
    init() {}
    private enum CodingKeys: String, CodingKey { case formatVersion, entries, legacy }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let version = try values.decodeIfPresent(Int.self, forKey: .formatVersion) ?? 0
        switch version {
        case 0: legacy = try KanjiTranslationStore(from: decoder)
        case 1:
            entries = try values.decode([String: StoredTextTranslation].self, forKey: .entries)
            legacy = try values.decodeIfPresent(KanjiTranslationStore.self, forKey: .legacy) ?? KanjiTranslationStore()
        default: throw StorageFormatError.unsupportedVersion(version)
        }
    }
    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(1, forKey: .formatVersion)
        try values.encode(entries, forKey: .entries)
        try values.encode(legacy, forKey: .legacy)
    }
    mutating func removeLegacy(_ key: TranslationBlockKey) {
        switch key {
        case .wordMeaning(let id): legacy.wordTranslations[id] = nil
        case .wordExamples(let id): legacy.wordExampleTranslations[id] = nil
        case .kanjiMeaning(let id): legacy.kanjiTranslations[id]?.russianMeanings = nil
        case .kanjiExamples(let id): legacy.kanjiTranslations[id]?.russianExamples = nil
        case .ankiContent: break
        }
    }
}
