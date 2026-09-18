import Foundation

actor KanaSVGCacheRepository {
    static let shared = KanaSVGCacheRepository()
    enum CacheError: LocalizedError {
        case invalidFileName
        var errorDescription: String? { "Неверное имя SVG-файла кэша." }
    }
    func loadSVGText(fileName: String) throws -> String? {
        guard Self.isSafeFileName(fileName) else { throw CacheError.invalidFileName }
        let url = cacheURL(for: fileName)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }

        return try String(contentsOf: url, encoding: .utf8)
    }

    func saveSVGText(_ svgText: String, fileName: String) throws {
        try Task.checkCancellation()
        guard Self.isSafeFileName(fileName) else { throw CacheError.invalidFileName }
        let url = cacheURL(for: fileName)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try svgText.write(to: url, atomically: true, encoding: .utf8)
    }

    func clearCache() throws {
        let directory = cacheDirectoryURL()
        guard FileManager.default.fileExists(atPath: directory.path) else {
            return
        }

        try FileManager.default.removeItem(at: directory)
    }

    private func cacheURL(for fileName: String) -> URL {
        cacheDirectoryURL().appendingPathComponent(fileName)
    }

    private nonisolated static func isSafeFileName(_ fileName: String) -> Bool {
        fileName == URL(fileURLWithPath: fileName).lastPathComponent &&
        fileName.hasSuffix(".svg") &&
        !fileName.isEmpty && !fileName.contains("..")
    }

    private func cacheDirectoryURL() -> URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return caches.appendingPathComponent("KanaVGCache", isDirectory: true)
    }
}
