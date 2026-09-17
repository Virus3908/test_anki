import Foundation

protocol TranslationPersisting: Sendable {
    func load() async throws -> TranslationStore
    func save(_ translation: StoredTextTranslation, for key: TranslationBlockKey) async throws
    func hasRecoverableBackup() async -> Bool
    func restoreBackup() async throws -> TranslationStore
}

struct TranslationRepository: TranslationPersisting {
    private let store = JSONFileStore(filename: "translations.json", emptyValue: TranslationStore())
    func load() async throws -> TranslationStore { try await store.load() }
    func save(_ translation: StoredTextTranslation, for key: TranslationBlockKey) async throws {
        try await store.update {
            $0.entries[key.storageKey] = translation
            $0.removeLegacy(key)
        }
    }
    func hasRecoverableBackup() async -> Bool { await store.hasRecoverableBackup() }
    func restoreBackup() async throws -> TranslationStore { try await store.restoreBackup() }
}
