import Foundation

/// Compact bundle corpus. Harvested candidates and Python/Sudachi dictionaries stay outside Bundle.
nonisolated struct GrammarSentenceBank: Codable, Sendable {
    struct Source: Codable, Sendable {
        let name: String
        let sentenceID: String
        let author: String?
        let license: String
        let url: String
        let commit: String?
    }
    struct Translation: Codable, Sendable {
        let id: String
        let language: String
        let text: String
        let license: String
        let author: String?
        let url: String
        let status: String
    }
    struct Sentence: Identifiable, Codable, Sendable {
        let id: String
        let japanese: String
        let sources: [Source]
        let translations: [Translation]
        let status: String
        var reading: String? = nil
        var reviewedTranslationRU: String? = nil
    }
    struct Segment: Codable, Sendable { let id: String; let startUTF8: Int; let endUTF8: Int }
    struct Usage: Codable, Sendable {
        let id: String
        let ruleID: String
        let sentenceID: String
        let segments: [Segment]
        let status: String
        let eligibleForScoring: Bool
        let evidence: String
    }
    struct ExampleReference: Codable, Sendable {
        let sentenceID: String
        let translationID: String
        let furigana: String?
        let translationRU: String?
    }
    let schemaVersion: Int
    let texts: [String: String]
    let sentences: [Sentence]
    let usages: [Usage]
    let templates: [String: GrammarExercise]

    enum Error: Swift.Error { case invalid(String) }
    func examples(_ references: [ExampleReference]) throws -> [GrammarExample] {
        let index = Dictionary(uniqueKeysWithValues: sentences.map { ($0.id, $0) })
        return try references.map { reference in
            guard let sentence = index[reference.sentenceID],
                  let translation = sentence.translations.first(where: { $0.id == reference.translationID && $0.language == "eng" }) else {
                throw Error.invalid("missing example reference")
            }
            return GrammarExample(ja: sentence.japanese, en: translation.text,
                furigana: reference.furigana ?? sentence.reading,
                ru: reference.translationRU ?? sentence.reviewedTranslationRU,
                sources: sentence.sources.map { source in
                    GrammarExampleSource(name: source.name, sentenceID: source.sentenceID,
                        author: source.author, license: source.license, url: source.url,
                        commit: source.commit, status: sentence.status)
                },
                translationSources: [GrammarExampleSource(name: "Перевод \(translation.id)",
                    sentenceID: translation.id, author: translation.author, license: translation.license,
                    url: translation.url, commit: nil, status: translation.status)])
        }
    }
    func exercises(_ ids: [String], ruleID: String) throws -> [GrammarExercise] {
        let index = Dictionary(uniqueKeysWithValues: sentences.map { ($0.id, $0) })
        func expand(_ value: Any) throws -> Any {
            if let text = value as? String {
                if text.hasPrefix("@gtext:") {
                    guard let resolved = texts[text] else { throw Error.invalid("missing text reference") }
                    return resolved
                }
                if text.hasPrefix("@gs:") {
                    guard let sentence = index[String(text.dropFirst())] else { throw Error.invalid("missing sentence reference") }
                    return sentence.japanese
                }
                return text
            }
            if let array = value as? [Any] { return try array.map(expand) }
            if let dictionary = value as? [String: Any] {
                var result: [String: Any] = [:]
                for (key, child) in dictionary {
                    guard let resolvedKey = try expand(key) as? String, result[resolvedKey] == nil else {
                        throw Error.invalid("duplicate resolved key")
                    }
                    result[resolvedKey] = try expand(child)
                }
                return result
            }
            return value
        }
        return try ids.map { id in
            guard let template = templates[id], template.ruleID == ruleID else { throw Error.invalid("missing/mismatched template") }
            let payload = try JSONSerialization.jsonObject(with: JSONEncoder().encode(template))
            let data = try JSONSerialization.data(withJSONObject: expand(payload))
            var exercise = try JSONDecoder().decode(GrammarExercise.self, from: data)
            var ruby = exercise.furigana ?? [:]
            for text in [exercise.japanese].compactMap({ $0 }) + exercise.options.map(\.text) {
                if let sentence = sentences.first(where: { $0.japanese.utf8.elementsEqual(text.utf8) }),
                   let reading = sentence.reading, sentence.status == "linguisticallyReviewed" {
                    ruby[text] = reading
                }
            }
            exercise.furigana = ruby
            guard exercise.isUsable(for: ruleID) else { throw Error.invalid("invalid materialized exercise") }
            return exercise
        }
    }
    func validate() throws {
        guard schemaVersion == 1, Set(sentences.map(\.id)).count == sentences.count,
              Set(sentences.map { Data($0.japanese.utf8) }).count == sentences.count else { throw Error.invalid("duplicate sentence/version") }
        let ids = Set(sentences.map(\.id))
        guard templates.allSatisfy({ $0.key == $0.value.id }) else { throw Error.invalid("template identity mismatch") }
        let licenses: Set<String> = ["MIT", "CC-BY-SA-4.0", "CC-BY-2.0-FR", "CC0-1.0"]
        for sentence in sentences {
            guard !sentence.japanese.isEmpty, !sentence.sources.isEmpty,
                  sentence.sources.allSatisfy({ licenses.contains($0.license) && !$0.url.isEmpty }),
                  sentence.translations.allSatisfy({ licenses.contains($0.license) && !$0.text.isEmpty }) else { throw Error.invalid("unlicensed/empty sentence") }
            if let reading = sentence.reading, FuriganaParser.parse(reading, original: sentence.japanese) == nil {
                throw Error.invalid("reviewed reading changes sentence")
            }
        }
        for usage in usages {
            guard ids.contains(usage.sentenceID) else { throw Error.invalid("missing usage sentence") }
            if !usage.segments.isEmpty {
                let sentence = sentences.first { $0.id == usage.sentenceID }!
                let count = sentence.japanese.utf8.count
                var offset = 0
                for segment in usage.segments {
                    guard segment.startUTF8 == offset, segment.endUTF8 > offset, segment.endUTF8 <= count,
                          String(bytes: sentence.japanese.utf8.dropFirst(offset).prefix(segment.endUTF8 - offset), encoding: .utf8) != nil else {
                        throw Error.invalid("invalid semantic segment")
                    }
                    offset = segment.endUTF8
                }
                guard offset == count else { throw Error.invalid("incomplete semantic segments") }
            }
        }
    }
}
