import Foundation
import CryptoKit
import AnkiImport

/// Anki content is separate from built-in content; review-memory.json remains owned by ReviewRepository.
actor AnkiRepository {
    private let store = JSONFileStore<[AnkiImportSummary]>(filename: "anki-library.json", emptyValue: [])
    private var importing = false

    func load() async throws -> [AnkiImportSummary] { try await store.load() }
    func hasRecoverableBackup() async -> Bool { await store.hasRecoverableBackup() }
    func restoreBackup() async throws -> [AnkiImportSummary] { try await store.restoreBackup() }

    func importPackage(_ url: URL) async throws -> AnkiImportResult {
        guard !importing else { throw AnkiImportError.invalid("дождитесь завершения текущего импорта") }
        importing = true
        defer { importing = false }
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        guard ["apkg", "colpkg"].contains(url.pathExtension.lowercased()) else {
            throw AnkiImportError.invalid("выберите файл .apkg или .colpkg")
        }
        var library = try await store.load()
        let root = try rootURL()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let staging = root.appendingPathComponent("staging-\(UUID().uuidString)", isDirectory: true)
        let worker = Task.detached(priority: .userInitiated) {
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            var hash = SHA256()
            var size: Int64 = 0
            while let data = try handle.read(upToCount: 1024 * 1024), !data.isEmpty {
                try Task.checkCancellation()
                size += Int64(data.count)
                guard size <= 4 * 1024 * 1024 * 1024 else { throw AnkiImportError.limit }
                hash.update(data: data)
            }
            let fingerprint = hash.finalize().map { String(format: "%02x", $0) }.joined()
            if let existing = library.first(where: { $0.id == fingerprint }) {
                return AnkiImportResult(summary: existing, alreadyImported: true)
            }
            let collection = try AnkiPackageParser.extract(from: url, to: staging)
            let summary = AnkiImportSummary(id: fingerprint, directory: UUID().uuidString,
                filename: url.lastPathComponent, importedAt: Date(), decks: collection.decks,
                cardCount: collection.cards.count, noteCount: collection.notes.count,
                mediaCount: collection.media.count, warnings: collection.warnings)
            return AnkiImportResult(summary: summary, alreadyImported: false)
        }
        let result = try await withTaskCancellationHandler { try await worker.value } onCancel: { worker.cancel() }
        if result.alreadyImported { return result }
        let destination = root.appendingPathComponent(result.summary.directory, isDirectory: true)
        do {
            try Task.checkCancellation()
            try FileManager.default.moveItem(at: staging, to: destination)
            library.insert(result.summary, at: 0)
            try await store.save(library)
        } catch {
            // Both directories belong exclusively to this attempt; existing imports are untouched.
            try? FileManager.default.removeItem(at: staging)
            try? FileManager.default.removeItem(at: destination)
            throw error
        }
        return result
    }

    func collection(_ summary: AnkiImportSummary) async throws -> AnkiCollection {
        let url = try directory(summary).appendingPathComponent("collection.json")
        return try await Task.detached(priority: .userInitiated) {
            try JSONDecoder().decode(AnkiCollection.self, from: Data(contentsOf: url))
        }.value
    }

    func mediaDirectory(_ summary: AnkiImportSummary) throws -> URL {
        try directory(summary).appendingPathComponent("media", isDirectory: true)
    }

    private func directory(_ summary: AnkiImportSummary) throws -> URL {
        guard UUID(uuidString: summary.directory) != nil else { throw AnkiImportError.invalid("неверный каталог колоды") }
        return try rootURL().appendingPathComponent(summary.directory, isDirectory: true)
    }

    private func rootURL() throws -> URL {
        try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("KanjiTrainer/Anki", isDirectory: true)
    }
}
