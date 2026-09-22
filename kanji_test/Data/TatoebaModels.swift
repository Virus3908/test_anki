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

    enum CodingKeys: String, CodingKey {
        case id
        case text
        case isUnapproved = "is_unapproved"
        case owner
        case license
        case translations
    }

    var attribution: TatoebaAttribution? {
        guard let license, license == "CC BY 2.0 FR" || license == "CC0 1.0" else { return nil }
        guard license == "CC0 1.0" || owner?.isEmpty == false else { return nil }
        return TatoebaAttribution(sentenceID: id, author: owner, license: license)
    }

    var preferredEnglishTranslation: String? {
        translations
            .first { $0.lang == "eng" && $0.isDirect }
            .map(\.text)
            ?? translations.first { $0.lang == "eng" }?.text
    }
}

nonisolated struct TatoebaAttribution: Codable, Hashable, Sendable {
    let sentenceID: Int
    let author: String?
    let license: String

    var sentenceURL: URL? {
        URL(string: "https://tatoeba.org/en/sentences/show/\(sentenceID)")
    }

    var displayText: String {
        let authorText = author.map { " · автор: \($0)" } ?? ""
        return "Tatoeba · предложение #\(sentenceID)\(authorText) · \(license)"
    }
}

struct TatoebaTranslation: Decodable {
    let text: String
    let lang: String
    let isDirect: Bool

    enum CodingKeys: String, CodingKey {
        case text
        case lang
        case isDirect = "is_direct"
    }
}
