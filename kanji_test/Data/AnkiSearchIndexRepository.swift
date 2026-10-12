import Foundation
import AnkiImport
import OSLog

/// Disposable index files live in Caches, apart from the imported source and
/// review history. Actor serialization prevents concurrent rebuild/clear races.
actor AnkiSearchIndexRepository {
    static let shared = AnkiSearchIndexRepository()
    private let root: URL
    private let byteLimit: Int
    nonisolated private struct IndexFile: Codable {
        let version: Int
        let importID: String
        let records: [AnkiSearchRecord]
    }

    init(root: URL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("AnkiSearchIndex", isDirectory: true), byteLimit: Int = 128 * 1024 * 1024) {
        self.root = root
        self.byteLimit = byteLimit
    }

    func records(for summary: AnkiImportSummary, sourceURL: URL) throws -> [AnkiSearchRecord] {
        try Task.checkCancellation()
        let url = try indexURL(summary)
        if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
           size <= byteLimit,
           let data = try? Data(contentsOf: url),
           let file = try? JSONDecoder().decode(IndexFile.self, from: data),
           file.version == 1, file.importID == summary.id,
           file.records.count == summary.cardCount,
           Set(file.records.map(\.cardID)).count == file.records.count,
           file.records.allSatisfy({ $0.importID == summary.id }) {
            try Task.checkCancellation()
            try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: url.path)
            return file.records
        }
        // Never prepare/save native fields back into collection.json here.
        try Task.checkCancellation()
        let collection = try AnkiCollectionLoader.load(from: sourceURL)
        let records = try AnkiSearchRecord.records(collection: collection, importID: summary.id, filename: summary.filename)
        try Task.checkCancellation()
        do { try save(records, for: summary) }
        catch is CancellationError { throw CancellationError() }
        catch {
            try Task.checkCancellation()
            Logger(subsystem: "KanjiTrainer", category: "AnkiSearchIndex")
                .error("Could not save disposable search index: \(error.localizedDescription, privacy: .public)")
        }
        try Task.checkCancellation()
        return records
    }

    func save(_ records: [AnkiSearchRecord], for summary: AnkiImportSummary) throws {
        try Task.checkCancellation()
        let url = try indexURL(summary)
        let data = try JSONEncoder().encode(IndexFile(version: 1, importID: summary.id, records: records))
        guard data.count <= byteLimit else { return } // oversized imports remain searchable without a disk cache
        try Task.checkCancellation()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Task.checkCancellation()
        try data.write(to: url, options: .atomic)
        try Task.checkCancellation()
        try trim()
    }

    func remove(_ summary: AnkiImportSummary) throws {
        let url = try indexURL(summary)
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }

    func clear() throws {
        if FileManager.default.fileExists(atPath: root.path) { try FileManager.default.removeItem(at: root) }
    }

    private func indexURL(_ summary: AnkiImportSummary) throws -> URL {
        guard UUID(uuidString: summary.directory) != nil else { throw CocoaError(.fileReadInvalidFileName) }
        return root.appendingPathComponent(summary.directory).appendingPathExtension("json")
    }

    private func trim() throws {
        let urls = try FileManager.default.contentsOfDirectory(at: root,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey])
        let files = try urls.filter { $0.pathExtension == "json" }.map { url in
            (url, try url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey]))
        }.sorted { ($0.1.contentModificationDate ?? .distantPast) < ($1.1.contentModificationDate ?? .distantPast) }
        var size = files.reduce(0) { $0 + ($1.1.fileSize ?? 0) }
        for (url, values) in files where size > byteLimit {
            try Task.checkCancellation()
            try FileManager.default.removeItem(at: url)
            size -= values.fileSize ?? 0
        }
    }
}
