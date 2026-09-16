import Foundation

struct RemoteKanjiDetail: Decodable {
    let kanji: String
    let meanings: [String]
    let onReadings: [String]
    let kunReadings: [String]
    let grade: Int?
    let jlpt: Int?

    enum CodingKeys: String, CodingKey {
        case kanji
        case meanings
        case onReadings = "on_readings"
        case kunReadings = "kun_readings"
        case grade
        case jlpt
    }
}

struct RemoteWordEntry: Decodable {
    let meanings: [RemoteWordMeaning]
    let variants: [RemoteWordVariant]
}

struct RemoteWordMeaning: Decodable {
    let glosses: [String]
}

struct RemoteWordVariant: Decodable {
    let pronounced: String
    let written: String
}

enum RemoteKanjiError: Error {
    case missingStrokes
}
