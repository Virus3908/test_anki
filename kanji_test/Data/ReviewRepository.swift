import Foundation

protocol ReviewPersisting: Sendable {
    func load() async throws -> KanjiReviewStore
    func save(_ value: KanjiReviewStore) async throws
    func hasRecoverableBackup() async -> Bool
    func restoreBackup() async throws -> KanjiReviewStore
}

struct ReviewRepository: ReviewPersisting {
    private let store = JSONFileStore(filename: "review-memory.json", emptyValue: KanjiReviewStore(records: [:]))
    func load() async throws -> KanjiReviewStore { try await store.load() }
    func save(_ value: KanjiReviewStore) async throws { try await store.save(value) }
    func hasRecoverableBackup() async -> Bool { await store.hasRecoverableBackup() }
    func restoreBackup() async throws -> KanjiReviewStore { try await store.restoreBackup() }
}
