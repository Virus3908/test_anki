import Foundation

struct WordDictionaryEntry: Codable, Identifiable, Sendable {
    var id: String { "\(word)-\(reading)" }

    let word: String
    let reading: String
    let meaning: String
}
