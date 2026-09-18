import Foundation

/// Owns temporary WebKit documents; access remains limited to one import's media.
@MainActor
final class AnkiPreviewDocument {
    private(set) var url: URL?

    func write(_ html: String, in directory: URL) throws -> URL {
        let destination = url ?? directory.appendingPathComponent("preview-\(UUID().uuidString).html")
        try Data(html.utf8).write(to: destination, options: .atomic)
        url = destination
        return destination
    }

    func remove() {
        if let url { try? FileManager.default.removeItem(at: url) }
        url = nil
    }
}

actor AnkiMediaService {
    func data(at url: URL) throws -> Data {
        try Task.checkCancellation()
        return try Data(contentsOf: url)
    }
}
