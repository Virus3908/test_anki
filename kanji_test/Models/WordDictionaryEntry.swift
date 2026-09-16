import Foundation

struct WordDictionaryEntry: Codable, Identifiable, Sendable {
    var id: String { "\(word)-\(reading)" }

    let word: String
    let reading: String
    let meaning: String
    let examples: [WordUsageExample]

    init(word: String, reading: String, meaning: String, examples: [WordUsageExample] = []) {
        self.word = word
        self.reading = reading
        self.meaning = meaning
        self.examples = examples
    }

    enum CodingKeys: String, CodingKey {
        case word
        case reading
        case meaning
        case examples
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        word = try container.decode(String.self, forKey: .word)
        reading = try container.decode(String.self, forKey: .reading)
        meaning = try container.decode(String.self, forKey: .meaning)
        examples = try container.decodeIfPresent([WordUsageExample].self, forKey: .examples) ?? []
    }
}

struct WordUsageExample: Codable, Identifiable, Sendable {
    var id: String { "\(sentence)-\(reading ?? "")-\(meaning ?? "")" }

    let sentence: String
    let reading: String?
    let meaning: String?

    init(sentence: String, reading: String? = nil, meaning: String? = nil) {
        self.sentence = sentence
        self.reading = reading
        self.meaning = meaning
    }

    enum CodingKeys: String, CodingKey {
        case sentence
        case japanese
        case reading
        case meaning
        case translation
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sentence = try container.decodeIfPresent(String.self, forKey: .sentence)
            ?? container.decodeIfPresent(String.self, forKey: .japanese)
            ?? ""
        reading = try container.decodeIfPresent(String.self, forKey: .reading)
        meaning = try container.decodeIfPresent(String.self, forKey: .meaning)
            ?? container.decodeIfPresent(String.self, forKey: .translation)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(sentence, forKey: .sentence)
        try container.encodeIfPresent(reading, forKey: .reading)
        try container.encodeIfPresent(meaning, forKey: .meaning)
    }
}

struct StudyExample: Identifiable, Sendable, Hashable {
    let id: String
    let text: String
    let reading: String?
    let meaning: String?

    init(id: String, text: String, reading: String? = nil, meaning: String? = nil) {
        self.id = id
        self.text = text
        self.reading = reading?.nilIfBlank
        self.meaning = meaning?.nilIfBlank
    }

    init(wordExample example: WordUsageExample, reading: String? = nil) {
        self.init(
            id: "word-\(example.id)",
            text: example.sentence,
            reading: reading ?? example.reading,
            meaning: example.meaning
        )
    }

    init(kanjiExample example: KanjiExample) {
        self.init(
            id: "kanji-\(example.id)",
            text: example.word,
            reading: example.reading,
            meaning: example.meaning
        )
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
