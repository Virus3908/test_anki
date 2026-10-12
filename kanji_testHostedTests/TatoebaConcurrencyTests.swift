import XCTest
@testable import kanji_test

@MainActor
final class TatoebaConcurrencyTests: XCTestCase {
    func testGlobalCapAndSingleFlightAcrossConcurrentCallers() async throws {
        let firstWave = expectation(description: "First three requests")
        let secondWave = expectation(description: "Next three requests")
        ControlledTatoebaProtocol.configure { count in
            if count == 3 { firstWave.fulfill() }
            if count == 6 { secondWave.fulfill() }
        }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [ControlledTatoebaProtocol.self]
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel() }
        let urls = (1...6).map { URL(string: "https://mock.invalid/\($0)")! }
        let task = Task {
            await withTaskGroup(of: Data?.self) { group in
                for url in urls {
                    // Duplicate subscriber for every identity.
                    for _ in 0..<2 { group.addTask { await TatoebaRequests.shared.data(from: url, session: session) } }
                }
                var received = 0
                for await data in group { if data != nil { received += 1 } }
                return received
            }
        }
        await fulfillment(of: [firstWave], timeout: 5)
        XCTAssertEqual(ControlledTatoebaProtocol.activeCount, 3)
        ControlledTatoebaProtocol.completeActive()
        await fulfillment(of: [secondWave], timeout: 5)
        ControlledTatoebaProtocol.completeActive()
        let received = await task.value
        XCTAssertEqual(received, 12)
        XCTAssertEqual(ControlledTatoebaProtocol.requestCount, 6)
        XCTAssertLessThanOrEqual(ControlledTatoebaProtocol.maximumActive, 3)
    }
}

// URLProtocol requires restating its inherited unchecked conformance; all shared
// mock state is protected by the lock, and callbacks run outside the lock.
nonisolated private final class ControlledTatoebaProtocol: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var active: [ControlledTatoebaProtocol] = []
    nonisolated(unsafe) private static var count = 0
    nonisolated(unsafe) private static var maximum = 0
    nonisolated(unsafe) private static var observer: (@Sendable (Int) -> Void)?
    static var requestCount: Int { lock.withLock { count } }
    static var activeCount: Int { lock.withLock { active.count } }
    static var maximumActive: Int { lock.withLock { maximum } }
    static func configure(_ callback: @escaping @Sendable (Int) -> Void) {
        lock.withLock { active = []; count = 0; maximum = 0; observer = callback }
    }
    static func completeActive() {
        let requests = lock.withLock { let requests = active; active = []; return requests }
        for request in requests {
            let response = HTTPURLResponse(url: request.request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            request.client?.urlProtocol(request, didReceive: response, cacheStoragePolicy: .notAllowed)
            request.client?.urlProtocol(request, didLoad: Data("{}".utf8))
            request.client?.urlProtocolDidFinishLoading(request)
        }
    }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let (count, observer) = Self.lock.withLock {
            Self.count += 1
            Self.active.append(self)
            Self.maximum = max(Self.maximum, Self.active.count)
            return (Self.count, Self.observer)
        }
        observer?(count)
    }
    override func stopLoading() { Self.lock.withLock { Self.active.removeAll { $0 === self } } }
}
