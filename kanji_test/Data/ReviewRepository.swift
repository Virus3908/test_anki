import Foundation

protocol ReviewPersisting: Sendable {
    func load() async throws -> StudyProgressStore
    func save(_ value: StudyProgressStore) async throws
    func hasRecoverableBackup() async -> Bool
    func restoreBackup() async throws -> StudyProgressStore
}

struct ReviewRepository: ReviewPersisting {
    private let store = JSONFileStore(filename: "review-memory.json", emptyValue: StudyProgressStore(records: [:]))
    func load() async throws -> StudyProgressStore { try await store.load() }
    func save(_ value: StudyProgressStore) async throws { try await store.save(value) }
    func hasRecoverableBackup() async -> Bool { await store.hasRecoverableBackup() }
    func restoreBackup() async throws -> StudyProgressStore { try await store.restoreBackup() }
}
