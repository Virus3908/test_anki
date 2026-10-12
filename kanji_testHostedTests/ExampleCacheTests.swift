import XCTest
@testable import kanji_test

final class ExampleCacheTests: XCTestCase {
    func testFailedWriteRetriesUnchangedInMemoryValue() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        // A file where the directory belongs makes the first atomic write fail.
        try Data("blocked".utf8).write(to: root)
        let url = root.appendingPathComponent("cache.json")
        let cache = ExampleCacheStore<String>(url: url)
        do {
            try await cache.save(["example"], for: "key")
            XCTFail("The blocked directory must reject the write")
        } catch { }
        try FileManager.default.removeItem(at: root)
        try await cache.save(["example"], for: "key")
        let restored = await ExampleCacheStore<String>(url: url).load("key")
        XCTAssertEqual(restored, ["example"])
    }

    func testLegacyReadUnchangedSaveEvictionCorruptionAndClear() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let url = root.appendingPathComponent("cache.json")
        let critical = root.appendingPathComponent("review-memory.json")
        try Data("critical progress".utf8).write(to: critical)
        try JSONEncoder().encode(["old": ["example"]]).write(to: url)
        let cache = ExampleCacheStore<String>(url: url, entryLimit: 2)
        let old = await cache.load("old")
        XCTAssertEqual(old, ["example"])
        let bytes = try Data(contentsOf: url)
        try await cache.save(["example"], for: "old")
        XCTAssertEqual(try Data(contentsOf: url), bytes, "Unchanged legacy data must not be serialized again")
        try await cache.save(["second"], for: "second")
        _ = await cache.load("old")
        try await cache.save(["third"], for: "third")
        let evicted = await cache.load("second")
        XCTAssertNil(evicted)
        let restored = await ExampleCacheStore<String>(url: url).load("old")
        XCTAssertEqual(restored, old)
        try await cache.clear()
        let cleared = await cache.load("old")
        XCTAssertNil(cleared)
        XCTAssertEqual(try String(contentsOf: critical, encoding: .utf8), "critical progress")
        try Data("broken".utf8).write(to: url)
        let recovery = ExampleCacheStore<String>(url: url)
        try await recovery.save(["recovered"], for: "key")
        let recovered = await recovery.load("key")
        XCTAssertEqual(recovered, ["recovered"])
    }

    func testConcurrentWritesAndByteBound() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let cache = ExampleCacheStore<String>(url: url, byteLimit: 1024)
        try await withThrowingTaskGroup(of: Void.self) { group in
            for i in 0..<10 { group.addTask { try await cache.save(["value"], for: String(i)) } }
            try await group.waitForAll()
        }
        for i in 0..<10 {
            let value = await cache.load(String(i))
            XCTAssertEqual(value, ["value"])
        }
        try await cache.save([String(repeating: "x", count: 5000)], for: "oversized")
        XCTAssertLessThanOrEqual(try Data(contentsOf: url).count, 1024)
    }
}
