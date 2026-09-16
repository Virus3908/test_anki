import Foundation

enum KanaSVGCacheRepository {
    static func loadSVGText(fileName: String) throws -> String? {
        let url = cacheURL(for: fileName)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }

        return try String(contentsOf: url, encoding: .utf8)
    }

    static func saveSVGText(_ svgText: String, fileName: String) throws {
        let url = cacheURL(for: fileName)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try svgText.write(to: url, atomically: true, encoding: .utf8)
    }

    static func clearCache() throws {
        let directory = cacheDirectoryURL()
        guard FileManager.default.fileExists(atPath: directory.path) else {
            return
        }

        try FileManager.default.removeItem(at: directory)
    }

    private static func cacheURL(for fileName: String) -> URL {
        cacheDirectoryURL().appendingPathComponent(fileName)
    }

    private static func cacheDirectoryURL() -> URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return caches.appendingPathComponent("KanaVGCache", isDirectory: true)
    }
}
