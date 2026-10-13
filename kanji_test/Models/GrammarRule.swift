import Foundation

nonisolated enum GrammarLevel: String, CaseIterable, Codable, Identifiable, Sendable {
    case n5 = "N5", n4 = "N4", n3 = "N3", n2 = "N2", n1 = "N1"
    var id: String { rawValue }
    var expectedCount: Int {
        switch self {
        case .n5: 81
        case .n4: 98
        case .n3: 101
        case .n2, .n1: 123
        }
    }
    var deck: StudyDeck { .init(id: "grammar:\(rawValue.lowercased())", title: rawValue, mode: .grammar) }
}

nonisolated struct GrammarContentMetadata: Codable, Sendable {
    let source: String
    let repository: String
    let commit: String
    let version: String
    let license: String
    let authors: [String]
    let modifications: String
    let sourceSHA256: String
}

nonisolated struct GrammarResource: Codable, Sendable {
    let schemaVersion: Int
    let metadata: GrammarContentMetadata
    let rules: [GrammarRule]
}

/// Source fields are kept separately from reviewed Russian adaptation.
/// Missing localization is explicit, never a fabricated successful translation.
nonisolated struct GrammarRule: Identifiable, Codable, Sendable, StudyItem {
    let id: String
    let level: GrammarLevel
    let pattern: String
    let reading: String?
    let romaji: String?
    let meaning: String
    let formation: String
    let notes: String?
    let examples: [GrammarExample]
    let tags: [String]
    let localization: GrammarLocalization?
    let exercises: [GrammarExercise]?
    let relations: [GrammarRelation]?
    var teaching: GrammarTeaching? = nil

    var reviewKey: String { "grammar:\(id)" }
    var categories: [GrammarCategory] { tags.compactMap(GrammarCategory.init(rawValue:)) }
    var displayedMeaning: String { localization?.meaningRU ?? meaning }
    var displayedFormation: String { localization?.formationRU ?? formation }
    var displayedExplanation: String? { localization?.explanationRU ?? notes ?? meaning }

    func withExercises(_ value: [GrammarExercise]?) -> GrammarRule {
        GrammarRule(id: id, level: level, pattern: pattern, reading: reading, romaji: romaji,
            meaning: meaning, formation: formation, notes: notes, examples: examples, tags: tags,
            localization: localization, exercises: value, relations: relations, teaching: teaching)
    }
}

extension GrammarRule {
    // Malformed exercise content disables this rule's practice, not other lessons.
    nonisolated init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let decodedID = try values.decode(String.self, forKey: .id)
        id = decodedID
        level = try values.decode(GrammarLevel.self, forKey: .level)
        pattern = try values.decode(String.self, forKey: .pattern)
        reading = try values.decodeIfPresent(String.self, forKey: .reading)
        romaji = try values.decodeIfPresent(String.self, forKey: .romaji)
        meaning = try values.decode(String.self, forKey: .meaning)
        formation = try values.decode(String.self, forKey: .formation)
        notes = try values.decodeIfPresent(String.self, forKey: .notes)
        examples = try values.decode([GrammarExample].self, forKey: .examples)
        tags = try values.decode([String].self, forKey: .tags)
        localization = try values.decodeIfPresent(GrammarLocalization.self, forKey: .localization)
        relations = try values.decodeIfPresent([GrammarRelation].self, forKey: .relations)
        teaching = try values.decodeIfPresent(GrammarTeaching.self, forKey: .teaching)
        let decoded = try? values.decodeIfPresent([GrammarExercise].self, forKey: .exercises)
        if let decoded, decoded.allSatisfy({ $0.isUsable(for: decodedID) }),
           Set(decoded.map(\.id)).count == decoded.count { exercises = decoded }
        else { exercises = nil }
    }
}

/// Separate authored learning material; never modifies the immutable source example.
nonisolated struct GrammarTeaching: Codable, Sendable {
    struct Part: Codable, Sendable {
        let text: String
        let roleRU: String
        var highlight: Bool? = nil
    }
    let meaningRU: String
    let usageRU: String
    let formationRU: String
    let example: GrammarExample
    let parts: [Part]
    let notesRU: [String]
    let contrastsRU: [String]
    let complexity: Int
}

nonisolated struct GrammarLocalization: Codable, Sendable {
    let meaningRU: String
    let formationRU: String
    let formationNotesRU: String
    let explanationRU: String
    let usageNotesRU: [String]
    let typicalErrorsRU: [String]
    let reviewer: String
}

nonisolated struct GrammarExample: Codable, Sendable {
    let ja: String
    let en: String
    let furigana: String?
    let ru: String?

    /// Adapt explicit OpenJLPT braces to the existing strict parser.
    /// No reading inference; byte reconstruction is checked by FuriganaParser.
    var ruby: ExampleFurigana? {
        guard let furigana else { return nil }
        let transcription = furigana.replacingOccurrences(of: "{", with: "[")
            .replacingOccurrences(of: "}", with: "]")
        guard FuriganaParser.parse(transcription, original: ja) != nil else { return nil }
        return ExampleFurigana(transcriptions: [TatoebaTranscription(text: transcription,
            script: "Hrkt", type: "altscript")], checkedAt: Date(timeIntervalSince1970: 0))
    }
}

nonisolated struct GrammarRelation: Codable, Sendable {
    enum Kind: String, Codable, Sendable { case similarMeaning, register, contrast, prerequisite, sourceMention }
    let ruleID: String
    let kind: Kind
    let explanationRU: String
}
