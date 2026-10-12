import XCTest
@testable import kanji_test

@MainActor
final class FuriganaTests: XCTestCase {
    // Reduced real /unstable/sentences response, sentence #10756861.
    private let live = #"{"data":[{"id":10756861,"text":"学校だよ。","is_unapproved":false,"owner":"small_snow","license":"CC BY 2.0 FR","transcriptions":[{"script":"Hrkt","text":"[学校|がっ|こう]だよ。","needsReview":false,"type":"altscript","html":"<ruby>学<rt>がっ</rt></ruby><ruby>校<rt>こう</rt></ruby>だよ。","editor":"small_snow","modified":"2022-04-09T01:53:36+00:00"}],"translations":[{"id":5852683,"text":"I'm at school.","lang":"eng","is_direct":true,"owner":"CK","license":"CC BY 2.0 FR"}]}]}"#

    func testDecodeRealTranscriptionsAndAttributions() throws {
        let sentence = try JSONDecoder().decode(TatoebaSentenceResponse.self, from: Data(live.utf8)).data[0]
        XCTAssertEqual(sentence.transcriptions?.first?.script, "Hrkt")
        XCTAssertEqual(sentence.transcriptions?.first?.type, "altscript")
        XCTAssertEqual(sentence.transcriptions?.first?.editor, "small_snow")
        XCTAssertEqual(sentence.attribution?.sentenceID, 10756861)
        XCTAssertEqual(sentence.preferredEnglishTranslation?.attribution?.author, "CK")
    }

    func testMissingEmptyNullAndMalformedTranscriptionsDoNotDiscardSentence() throws {
        for extra in ["", #", "transcriptions": []"#, #", "transcriptions": null"#,
                      #", "transcriptions": "invalid""#, #", "transcriptions": [{"text": 3}]"#] {
            let json = #"{"data":[{"id":1,"text":"学校。","is_unapproved":false,"owner":"author","license":"CC BY 2.0 FR","translations":[]"# + extra + "}]}"
            let sentence = try JSONDecoder().decode(TatoebaSentenceResponse.self, from: Data(json.utf8)).data[0]
            XCTAssertEqual(sentence.text, "学校。")
            XCTAssertFalse(sentence.transcriptions?.isEmpty == false)
        }
    }

    func testGroupAndPerCharacterReadings() throws {
        let school = try XCTUnwrap(FuriganaParser.parse("[学校|がっ|こう]。", original: "学校。"))
        XCTAssertEqual(school.map(\.reading), ["がっ", "こう", nil])
        let today = try XCTUnwrap(FuriganaParser.parse("[今日|きょう]。", original: "今日。"))
        XCTAssertEqual(today.first, FuriganaSegment(text: "今日", reading: "きょう"))
    }

    func testOkurigana() throws {
        let eat = try XCTUnwrap(FuriganaParser.parse("[食|た]べる", original: "食べる"))
        XCTAssertEqual(eat, [FuriganaSegment(text: "食", reading: "た"), FuriganaSegment(text: "べる", reading: nil)])
        let apply = try XCTUnwrap(FuriganaParser.parse("[申|もう]し[込|こ]む", original: "申し込む"))
        XCTAssertEqual(apply.map(\.text), ["申", "し", "込", "む"])
        XCTAssertEqual(apply.map(\.reading), ["もう", nil, "こ", nil])
    }

    func testMixedKanaLatinPunctuationAndUnknownReadingsPreserveBytes() throws {
        let original = "「オンラインでHello、今日も食べる！」\nカタカナ ABC 123"
        let markup = "「オンラインで[Hello|]、[今日|きょう]も[食|た]べる！」\nカタカナ ABC 123"
        let segments = try XCTUnwrap(FuriganaParser.parse(markup, original: original))
        XCTAssertTrue(segments.map(\.text).joined().utf8.elementsEqual(original.utf8))
        XCTAssertEqual(segments.first { $0.text == "Hello" }?.reading, nil)
        XCTAssertNotNil(FuriganaParser.parse("[珈琲|コーヒー]", original: "珈琲"))
        XCTAssertNotNil(FuriganaParser.parse("[食べる|たべる]", original: "食べる"))
    }

    func testMalformedOrMismatchedMarkupFallsBack() {
        for markup in ["[学校|がっ|こう", "[学校|が|っ|こう]", "[|こう]", "[学校|<script>悪</script>]", "[学[校|こう]", "[別|べつ]", "[学校|school]"] {
            XCTAssertNil(FuriganaParser.parse(markup, original: "学校"), markup)
        }
        // Canonically equal Unicode must not silently replace original bytes.
        XCTAssertNil(FuriganaParser.parse("が", original: "か\u{3099}"))
        let data = ExampleFurigana(transcriptions: [TatoebaTranscription(text: "[別|べつ]", script: "Hrkt", type: "altscript")], checkedAt: Date())
        XCTAssertEqual(data.segments(for: "学校"), [FuriganaSegment(text: "学校", reading: nil)])
    }

    func testWrongScriptAndTypeAreNotUsed() {
        for transcription in [TatoebaTranscription(text: "[学校|がっこう]", script: "Latn", type: "transcription"),
                              TatoebaTranscription(text: "[学校|がっこう]", script: "Hrkt", type: "transcription")] {
            let data = ExampleFurigana(transcriptions: [transcription], checkedAt: Date())
            XCTAssertEqual(data.segments(for: "学校").first?.reading, nil)
        }
    }

    func testOldCacheAndNewRoundTrip() throws {
        let oldWord = Data(#"{"japanese":"学校だよ。","translation":"School","attribution":{"sentenceID":10756861,"author":"small_snow","license":"CC BY 2.0 FR"}}"#.utf8)
        var word = try JSONDecoder().decode(WordUsageExample.self, from: oldWord)
        XCTAssertNil(word.furigana)
        let oldKanji = Data(#"{"word":"学校だよ。","reading":"","meaning":"School"}"#.utf8)
        XCTAssertNil(try JSONDecoder().decode(KanjiExample.self, from: oldKanji).furigana)
        word.furigana = ExampleFurigana(transcriptions: [TatoebaTranscription(text: "[学校|がっ|こう]だよ。", script: "Hrkt", type: "altscript", editor: "editor")], checkedAt: Date())
        let restored = try JSONDecoder().decode(WordUsageExample.self, from: JSONEncoder().encode(word))
        XCTAssertEqual(restored.furigana, word.furigana)
        XCTAssertEqual(restored.sentence, word.sentence)
        XCTAssertEqual(restored.attribution, word.attribution)
        XCTAssertEqual(restored.id, "tatoeba-10756861")
    }

    func testSearchQueryRetainsFiltersAndAddsInclude() throws {
        let url = try XCTUnwrap(TatoebaEndpoint.sentences(for: "学校"))
        let query = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        let values = Dictionary(uniqueKeysWithValues: query.map { ($0.name, $0.value ?? "") })
        XCTAssertEqual(url.path, "/unstable/sentences")
        XCTAssertEqual(values["include"], "transcriptions")
        XCTAssertEqual(values["license"], "CC BY 2.0 FR,CC0 1.0")
        XCTAssertEqual(values["trans:lang"], "eng")
        XCTAssertEqual(values["trans:is_orphan"], "no")
        XCTAssertEqual(values["trans:is_unapproved"], "no")
        XCTAssertEqual(values["showtrans"], "matching")
    }

    func testFreshExamplesNeedOnlyOneSearchAndSurviveCache() async throws {
        let session = mockSession(data: Data(live.utf8))
        let card = makeCard()
        let provider = TatoebaWordExampleProvider(session: session)
        let first = await provider.loadExamples(for: card)
        let second = await provider.loadExamples(for: card)
        XCTAssertEqual(FuriganaURLProtocol.requests.count, 1)
        XCTAssertEqual(first.first?.furigana, second.first?.furigana)
        XCTAssertEqual(second.first?.furigana?.segments(for: "学校だよ。").first?.reading, "がっ")
    }

    func testOldCacheRefreshesByIDOnceAndKeepsSentenceAndTranslation() async throws {
        let session = mockSession(data: try singleResponse())
        let card = makeCard()
        let old = WordUsageExample(sentence: "学校だよ。", meaning: "Old translation", attribution: attribution,
                                   translationAttribution: TatoebaAttribution(sentenceID: 5852683, author: "CK", license: "CC BY 2.0 FR"))
        await WordExampleCacheRepository.saveExamples([old], for: card.id)
        let provider = TatoebaWordExampleProvider(session: session)
        let updated = await provider.loadExamples(for: card)
        _ = await provider.loadExamples(for: card)
        XCTAssertEqual(updated.first?.sentence, old.sentence)
        XCTAssertEqual(updated.first?.meaning, old.meaning)
        XCTAssertEqual(updated.first?.attribution, old.attribution)
        XCTAssertEqual(FuriganaURLProtocol.requests.map(\.path), ["/unstable/sentences/10756861"])
        let cached = await WordExampleCacheRepository.loadExamples(for: card.id)
        XCTAssertEqual(cached?.first?.furigana, updated.first?.furigana)
    }

    func testMissingTranscriptionIsCachedAndNeverRetriedAutomatically() async throws {
        let session = mockSession(data: try singleResponse(transcriptions: []))
        let provider = TatoebaWordExampleProvider(session: session)
        let old = WordUsageExample(sentence: "学校だよ。", attribution: attribution)
        let updated = await provider.enrich([old])
        let again = await provider.enrich(updated)
        XCTAssertEqual(FuriganaURLProtocol.requests.count, 1)
        XCTAssertEqual(again.first?.furigana?.transcriptions, [])
        XCTAssertEqual(again.first?.furigana?.needsRefresh, false)
        XCTAssertEqual(again.first?.sentence, old.sentence)
    }

    func testOfflineAndChangedTextPreserveExamplesAndBackOff() async throws {
        let session = mockSession(data: Data(), error: .notConnectedToInternet)
        let provider = TatoebaWordExampleProvider(session: session)
        let old = WordUsageExample(sentence: "学校だよ。", meaning: "School", attribution: attribution)
        let updated = await provider.enrich([old])
        _ = await provider.enrich(updated)
        XCTAssertEqual(FuriganaURLProtocol.requests.count, 1)
        XCTAssertEqual(updated.first?.sentence, old.sentence)
        XCTAssertEqual(updated.first?.meaning, old.meaning)
        XCTAssertNil(updated.first?.furigana?.transcriptions)
        XCTAssertEqual(updated.first?.furigana?.needsRefresh, false)
        let stale = ExampleFurigana(transcriptions: nil, checkedAt: Date().addingTimeInterval(-86401))
        XCTAssertTrue(stale.needsRefresh)

        FuriganaURLProtocol.configure(data: try singleResponse(text: "学校に行く。"))
        let mismatch = await provider.enrich([old])
        XCTAssertEqual(mismatch.first?.sentence, old.sentence)
        XCTAssertNil(mismatch.first?.furigana?.transcriptions)
    }

    func testKanjiCacheRetainsTranscriptions() async {
        let key = "furigana-test-" + UUID().uuidString
        let example = KanjiExample(word: "学校だよ。", reading: "", meaning: "School", attribution: attribution,
                                   furigana: ExampleFurigana(transcriptions: [], checkedAt: Date()))
        await KanjiExampleCacheRepository.saveExamples([example], for: key)
        let restored = await KanjiExampleCacheRepository.loadExamples(for: key)
        XCTAssertEqual(restored?.first?.furigana, example.furigana)
        XCTAssertEqual(restored?.first?.attribution, example.attribution)
    }

    func testSettingDefaultsOnAndPersistsWithoutMutatingExamples() throws {
        let suite = "FuriganaTests-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = StudyPreferences(defaults: defaults, errors: StorageStatus())
        XCTAssertTrue(preferences.showExampleFurigana)
        preferences.showExampleFurigana = false
        XCTAssertFalse(StudyPreferences(defaults: defaults, errors: StorageStatus()).showExampleFurigana)
        preferences.showExampleFurigana = true
        XCTAssertTrue(StudyPreferences(defaults: defaults, errors: StorageStatus()).showExampleFurigana)
    }

    private var attribution: TatoebaAttribution {
        TatoebaAttribution(sentenceID: 10756861, author: "small_snow", license: "CC BY 2.0 FR")
    }
    private func makeCard() -> WordStudyCard {
        WordStudyCard(word: "学校", reading: UUID().uuidString, meaning: "School", examples: [], kanjiCards: [])
    }
    private func mockSession(data: Data, error: URLError.Code? = nil) -> URLSession {
        FuriganaURLProtocol.configure(data: data, error: error)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FuriganaURLProtocol.self]
        return URLSession(configuration: configuration)
    }
    private func singleResponse(text: String? = nil, transcriptions: [[String: Any]]? = nil) throws -> Data {
        var sentence = (try JSONSerialization.jsonObject(with: Data(live.utf8)) as! [String: Any])["data"] as! [[String: Any]]
        if let text { sentence[0]["text"] = text }
        if let transcriptions { sentence[0]["transcriptions"] = transcriptions }
        return try JSONSerialization.data(withJSONObject: ["data": sentence[0]])
    }
}

nonisolated private final class FuriganaURLProtocol: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var responseData = Data()
    nonisolated(unsafe) private static var responseError: URLError.Code?
    nonisolated(unsafe) private static var captured: [URL] = []

    static var requests: [URL] { lock.withLock { captured } }
    static func configure(data: Data, error: URLError.Code? = nil) {
        lock.withLock { responseData = data; responseError = error; captured = [] }
    }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let (data, error) = Self.lock.withLock {
            if let url = request.url { Self.captured.append(url) }
            return (Self.responseData, Self.responseError)
        }
        if let error { client?.urlProtocol(self, didFailWithError: URLError(error)); return }
        guard let url = request.url, let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"]) else { return }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
