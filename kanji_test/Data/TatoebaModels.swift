import Foundation

struct TatoebaSentenceResponse: Decodable {
    let data: [TatoebaSentence]
}

struct TatoebaSentence: Decodable {
    let text: String
    let isUnapproved: Bool
    let translations: [TatoebaTranslation]

    enum CodingKeys: String, CodingKey {
        case text
        case isUnapproved = "is_unapproved"
        case translations
    }

    var preferredEnglishTranslation: String? {
        translations
            .first { $0.lang == "eng" && $0.isDirect }
            .map(\.text)
            ?? translations.first { $0.lang == "eng" }?.text
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
