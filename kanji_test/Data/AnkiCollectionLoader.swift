import Foundation
import AnkiImport

/// Read-only projection of an imported source. Called on repository actors or
/// detached workers; chunked IO and native-field preparation cooperate with cancellation.
nonisolated enum AnkiCollectionLoader {
    static func load(from url: URL,
                     checkCancellation: () throws -> Void = { try Task.checkCancellation() }) throws -> AnkiCollection {
        try checkCancellation()
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var data = Data()
        while true {
            try checkCancellation()
            guard let chunk = try handle.read(upToCount: 1024 * 1024), !chunk.isEmpty else { break }
            data.append(chunk)
        }
        try checkCancellation()
        var collection = try JSONDecoder().decode(AnkiCollection.self, from: data)
        try checkCancellation()
        for index in collection.notes.indices where collection.notes[index].parsedFields == nil {
            try checkCancellation()
            collection.notes[index].parsedFields = try collection.notes[index].fields.map { field in
                try checkCancellation()
                return AnkiContentParser.parsePreservingSource(field)
            }
        }
        try checkCancellation()
        return collection
    }
}
