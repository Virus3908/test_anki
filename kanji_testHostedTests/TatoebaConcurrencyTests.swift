import XCTest
@testable import kanji_test

@MainActor
final class TatoebaConcurrencyTests: XCTestCase {
    func testCachedKanjiAppearsBeforeMetadataResponse() async {
        let refresh = expectation(description: "Metadata request started")
        ControlledTatoebaProtocol.configure { count in if count == 1 { refresh.fulfill() } }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [ControlledTatoebaProtocol.self]
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel() }
        let card = KanjiCard(kanji: UUID().uuidString, meanings: [], onyomi: [], kunyomi: [], examples: [],
                             source: KanjiSource(name: "test", file: "", license: ""), strokes: [])
        let cached = KanjiExample(word: "学校だよ。", reading: "", meaning: "",
            attribution: TatoebaAttribution(sentenceID: 10756861, author: "small_snow", license: "CC BY 2.0 FR"))
        await KanjiExampleCacheRepository.saveExamples([cached], for: card.id)
        let app = StudyAppViewModel(kanjiProvider: KanjiAPIProvider(session: session))
        let task = Task { await app.translationState.loadKanjiExamplesIfNeeded(for: card, language: .english) }
        await fulfillment(of: [refresh], timeout: 5)
        XCTAssertEqual(app.translationState.kanjiUsageExamples[card.id], [cached])
        ControlledTatoebaProtocol.completeActive()
        await task.value
        XCTAssertEqual(app.translationState.kanjiUsageExamples[card.id]?.first?.word, cached.word)
        XCTAssertEqual(app.translationState.kanjiUsageExamples[card.id]?.first?.attribution, cached.attribution)
    }

    func testTranscriptionsReserveCapacityForUncachedExamples() async {
        let metadataStarted = expectation(description: "Two metadata requests")
        let searchStarted = expectation(description: "Visible search uses reserved slot")
        let remainingStarted = expectation(description: "Remaining metadata requests")
        ControlledTatoebaProtocol.configure { count in
            if count == 2 { metadataStarted.fulfill() }
            if count == 3 { searchStarted.fulfill() }
            if count == 5 { remainingStarted.fulfill() }
        }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [ControlledTatoebaProtocol.self]
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel() }
        let metadata = Task {
            await withTaskGroup(of: Data?.self) { group in
                for id in 1...4 {
                    group.addTask {
                        await TatoebaRequests.shared.data(from: URL(string: "https://mock.invalid/detail/\(id)")!,
                                                         session: session, kind: .transcription)
                    }
                }
                for await _ in group { }
            }
        }
        await fulfillment(of: [metadataStarted], timeout: 5)
        XCTAssertEqual(ControlledTatoebaProtocol.activeCount, 2)
        let search = Task {
            await TatoebaRequests.shared.data(from: URL(string: "https://mock.invalid/search")!, session: session)
        }
        await fulfillment(of: [searchStarted], timeout: 5)
        XCTAssertEqual(ControlledTatoebaProtocol.activeCount, 3)
        ControlledTatoebaProtocol.completeActive()
        await fulfillment(of: [remainingStarted], timeout: 5)
        ControlledTatoebaProtocol.completeActive()
        await metadata.value
        let data = await search.value
        XCTAssertNotNil(data)
        XCTAssertEqual(ControlledTatoebaProtocol.requestCount, 5)
        XCTAssertLessThanOrEqual(ControlledTatoebaProtocol.maximumActive, 3)
    }

    func testCachedWordAppearsBeforeRefreshAndCancelledRefreshRetriesOnReopen() async {
        let firstRefresh = expectation(description: "First metadata refresh started")
        let secondRefresh = expectation(description: "Cancelled refresh retried")
        ControlledTatoebaProtocol.configure { count in
            if count == 1 { firstRefresh.fulfill() }
            if count == 2 { secondRefresh.fulfill() }
        }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [ControlledTatoebaProtocol.self]
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel() }
        let card = WordStudyCard(word: UUID().uuidString, reading: "test", meaning: "test", examples: [], kanjiCards: [])
        let cached = WordUsageExample(sentence: "学校だよ。",
            attribution: TatoebaAttribution(sentenceID: 10756861, author: "small_snow", license: "CC BY 2.0 FR"))
        await WordExampleCacheRepository.saveExamples([cached], for: card.id)
        let app = StudyAppViewModel(wordProvider: TatoebaWordExampleProvider(session: session))
        let first = Task { await app.translationState.loadAndTranslateWordExamples(for: card, language: .english) }
        await fulfillment(of: [firstRefresh], timeout: 5)
        XCTAssertEqual(app.translationState.wordUsageExamples[card.id], [cached])
        first.cancel()
        await first.value
        let second = Task { await app.translationState.loadAndTranslateWordExamples(for: card, language: .english) }
        await fulfillment(of: [secondRefresh], timeout: 5)
        ControlledTatoebaProtocol.completeActive()
        await second.value
        XCTAssertEqual(app.translationState.wordUsageExamples[card.id]?.first?.sentence, cached.sentence)
        await app.translationState.loadAndTranslateWordExamples(for: card, language: .english)
        XCTAssertEqual(ControlledTatoebaProtocol.requestCount, 2)
    }

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
