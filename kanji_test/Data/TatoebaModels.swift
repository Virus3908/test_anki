import Foundation

struct TatoebaSentenceResponse: Decodable {
    let data: [TatoebaSentence]
}

struct TatoebaSentence: Decodable {
    let id: Int
    let text: String
    let isUnapproved: Bool
    let owner: String?
    let license: String?
    let translations: [TatoebaTranslation]
    let transcriptions: [TatoebaTranscription]?

    enum CodingKeys: String, CodingKey {
        case id
        case text
        case isUnapproved = "is_unapproved"
        case owner
        case license
        case translations
        case transcriptions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        text = try container.decode(String.self, forKey: .text)
        isUnapproved = try container.decode(Bool.self, forKey: .isUnapproved)
        owner = try container.decodeIfPresent(String.self, forKey: .owner)
        license = try container.decodeIfPresent(String.self, forKey: .license)
        translations = try container.decodeIfPresent([TatoebaTranslation].self, forKey: .translations) ?? []
        // Optional malformed associated data must never discard the sentence.
        transcriptions = (try? container.decodeIfPresent([TatoebaTranscription].self, forKey: .transcriptions))
    }

    var attribution: TatoebaAttribution? {
        TatoebaAttribution.make(sentenceID: id, author: owner, license: license)
    }

    var preferredEnglishTranslation: TatoebaTranslation? {
        translations
            .first { $0.lang == "eng" && $0.isDirect && $0.attribution != nil }
            ?? translations.first { $0.lang == "eng" && $0.attribution != nil }
    }
}

nonisolated struct TatoebaAttribution: Codable, Hashable, Sendable {
    let sentenceID: Int
    let author: String?
    let license: String

    static func make(sentenceID: Int, author: String?, license: String?) -> TatoebaAttribution? {
        guard let license, license == "CC BY 2.0 FR" || license == "CC0 1.0" else { return nil }
        guard license == "CC0 1.0" || author?.isEmpty == false else { return nil }
        return TatoebaAttribution(sentenceID: sentenceID, author: author, license: license)
    }

    var sentenceURL: URL? {
        URL(string: "https://tatoeba.org/en/sentences/show/\(sentenceID)")
    }

    var displayText: String {
        let authorText = author.map { " · автор: \($0)" } ?? ""
        return "Tatoeba · предложение #\(sentenceID)\(authorText) · \(license)"
    }
}

struct TatoebaTranslation: Decodable {
    let id: Int
    let text: String
    let lang: String
    let isDirect: Bool
    let owner: String?
    let license: String?

    var attribution: TatoebaAttribution? {
        TatoebaAttribution.make(sentenceID: id, author: owner, license: license)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case text
        case lang
        case isDirect = "is_direct"
        case owner
        case license
    }
}
