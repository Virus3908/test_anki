import Foundation

enum ReviewRepository {
    static func load() -> KanjiReviewStore {
        do {
            let url = try storageURL()
            guard FileManager.default.fileExists(atPath: url.path) else {
                return KanjiReviewStore(records: [:])
            }

            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(KanjiReviewStore.self, from: data)
        } catch {
            assertionFailure("Failed to load review memory: \(error)")
            return KanjiReviewStore(records: [:])
        }
    }

    static func save(_ store: KanjiReviewStore) {
        do {
            let url = try storageURL()
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(store)
            try data.write(to: url, options: .atomic)
        } catch {
            assertionFailure("Failed to save review memory: \(error)")
        }
    }

    private static func storageURL() throws -> URL {
        let directory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        return directory
            .appendingPathComponent("KanjiTrainer", isDirectory: true)
            .appendingPathComponent("review-memory.json")
    }
}
