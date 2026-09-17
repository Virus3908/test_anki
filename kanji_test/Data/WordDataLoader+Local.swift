import Foundation

extension WordDataLoader {
    static func loadDictionaryEntries() async throws -> [WordDictionaryEntry] {
        try await BundledStudyData.shared.wordEntries()
    }
}
