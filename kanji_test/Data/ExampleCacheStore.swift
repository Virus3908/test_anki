import Foundation

/// Bounded storage for disposable Tatoeba examples only. Legacy dictionaries and
/// JSONFileStore envelopes are accepted; critical repositories are unaffected.
actor ExampleCacheStore<Example: Codable & Sendable & Equatable> {
    private let url: URL
    private let entryLimit: Int
    private let byteLimit: Int
    private var values: [String: [Example]]?
    private var access: [String: Int] = [:]
    private var clock = 0
    nonisolated private struct Envelope: Codable {
        let schemaVersion: Int
        let payload: [String: [Example]]
    }

    init(url: URL, entryLimit: Int = 1000, byteLimit: Int = 8 * 1024 * 1024) {
        self.url = url
        self.entryLimit = max(1, entryLimit)
        self.byteLimit = max(1, byteLimit)
    }

    func load(_ key: String) -> [Example]? {
        readIfNeeded()
        touch(key)
        return values?[key]
    }

    func save(_ examples: [Example], for key: String) throws {
        readIfNeeded()
        guard values?[key] != examples else { touch(key); return }
        values?[key] = examples
        touch(key)
        try persistBounded()
    }

    func clear() throws {
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
        values = [:]
        access = [:]
    }

    private func touch(_ key: String) {
        guard values?[key] != nil else { return }
        clock += 1
        access[key] = clock
    }

    private func readIfNeeded() {
        guard values == nil else { return }
        if let data = try? Data(contentsOf: url) {
            if let envelope = try? JSONDecoder().decode(Envelope.self, from: data), envelope.schemaVersion == 1 {
                values = envelope.payload
            } else {
                values = (try? JSONDecoder().decode([String: [Example]].self, from: data)) ?? [:]
            }
        } else { values = [:] }
        // Legacy files carry no recency metadata: deterministic eviction until
        // the current process observes actual reads.
        if (values?.count ?? 0) > entryLimit { try? persistBounded() }
    }

    private func persistBounded() throws {
        let keys = (values ?? [:]).keys.sorted {
            let left = access[$0, default: 0], right = access[$1, default: 0]
            return left == right ? $0 < $1 : left < right
        }
        var nextKey = 0
        func evict() {
            let key = keys[nextKey]
            values?[key] = nil
            access[key] = nil
            nextKey += 1
        }
        while (values?.count ?? 0) > entryLimit { evict() }
        var data = try JSONEncoder().encode(Envelope(schemaVersion: 1, payload: values ?? [:]))
        while data.count > byteLimit, nextKey < keys.count {
            evict()
            data = try JSONEncoder().encode(Envelope(schemaVersion: 1, payload: values ?? [:]))
        }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }
}
