import XCTest
@testable import kanji_test

final class GrammarConjugationTests: XCTestCase {
    private func verb(_ text: String, _ reading: String, _ cls: GrammarConjugationEngine.VerbClass,
                      forms: Set<GrammarConjugationEngine.Form> = Set(GrammarConjugationEngine.Form.allCases)) -> GrammarConjugationEngine.Verb {
        .init(dictionary: text, reading: reading, verbClass: cls, permittedForms: forms)
    }
    func testGodanSoundChangesNegativesAndDesire() {
        let cases: [(String, GrammarConjugationEngine.VerbClass, String, String, String)] = [
            ("かう", .godanU, "かって", "かわない", "かいたい"),
            ("かく", .godanKu, "かいて", "かかない", "かきたい"),
            ("およぐ", .godanGu, "およいで", "およがない", "およぎたい"),
            ("はなす", .godanSu, "はなして", "はなさない", "はなしたい"),
            ("まつ", .godanTsu, "まって", "またない", "まちたい"),
            ("しぬ", .godanNu, "しんで", "しなない", "しにたい"),
            ("あそぶ", .godanBu, "あそんで", "あそばない", "あそびたい"),
            ("よむ", .godanMu, "よんで", "よまない", "よみたい"),
            ("かえる", .godanRu, "かえって", "かえらない", "かえりたい")]
        for (text, cls, te, nai, tai) in cases {
            let v = verb(text, text, cls)
            XCTAssertEqual(GrammarConjugationEngine.conjugate(v, to: .te)?.text, te)
            XCTAssertEqual(GrammarConjugationEngine.conjugate(v, to: .nai)?.text, nai)
            XCTAssertEqual(GrammarConjugationEngine.conjugate(v, to: .desire)?.text, tai)
        }
    }
    func testIchidanDerivedFormsAndExplicitGodanRu() {
        let v = verb("食べる", "たべる", .ichidan)
        let expected: [GrammarConjugationEngine.Form: String] = [.stem: "食べ", .masu: "食べます", .te: "食べて",
            .ta: "食べた", .nai: "食べない", .potential: "食べられる", .passive: "食べられる",
            .causative: "食べさせる", .conditionalBa: "食べれば", .conditionalTara: "食べたら", .desire: "食べたい"]
        for (form, text) in expected { XCTAssertEqual(GrammarConjugationEngine.conjugate(v, to: form)?.text, text) }
        XCTAssertEqual(GrammarConjugationEngine.conjugate(verb("帰る", "かえる", .godanRu), to: .nai)?.text, "帰らない")
        XCTAssertEqual(GrammarConjugationEngine.conjugate(verb("読む", "よむ", .godanMu), to: .potential)?.text, "読める")
        XCTAssertEqual(GrammarConjugationEngine.conjugate(verb("読む", "よむ", .godanMu), to: .passive)?.text, "読まれる")
        XCTAssertEqual(GrammarConjugationEngine.conjugate(verb("読む", "よむ", .godanMu), to: .causative)?.text, "読ませる")
        XCTAssertEqual(GrammarConjugationEngine.conjugate(verb("読む", "よむ", .godanMu), to: .conditionalBa)?.text, "読めば")
        XCTAssertEqual(GrammarConjugationEngine.conjugate(verb("読む", "よむ", .godanMu), to: .conditionalTara)?.text, "読んだら")
    }
    func testIrregularsCompoundsAndSeparateKuruReading() {
        XCTAssertEqual(GrammarConjugationEngine.conjugate(verb("行く", "いく", .iku), to: .te)?.text, "行って")
        XCTAssertEqual(GrammarConjugationEngine.conjugate(verb("行く", "いく", .iku), to: .ta)?.text, "行った")
        let suru = verb("勉強する", "べんきょうする", .suru)
        XCTAssertEqual(GrammarConjugationEngine.conjugate(suru, to: .te)?.text, "勉強して")
        XCTAssertEqual(GrammarConjugationEngine.conjugate(suru, to: .potential)?.text, "勉強できる")
        XCTAssertEqual(GrammarConjugationEngine.conjugate(suru, to: .desire)?.text, "勉強したい")
        let kuru = verb("来る", "くる", .kuru)
        XCTAssertEqual(GrammarConjugationEngine.conjugate(kuru, to: .te), .init(text: "来て", reading: "きて"))
        XCTAssertEqual(GrammarConjugationEngine.conjugate(kuru, to: .nai), .init(text: "来ない", reading: "こない"))
        XCTAssertEqual(GrammarConjugationEngine.conjugate(verb("持ってくる", "もってくる", .kuru), to: .ta)?.text, "持ってきた")
    }
    func testUnsupportedFormsAndMalformedMetadataFailClosed() {
        let aru = verb("ある", "ある", .aru)
        XCTAssertEqual(GrammarConjugationEngine.conjugate(aru, to: .nai)?.text, "ない")
        for form in [GrammarConjugationEngine.Form.potential, .passive, .causative, .desire] {
            XCTAssertNil(GrammarConjugationEngine.conjugate(aru, to: form))
        }
        XCTAssertNil(GrammarConjugationEngine.conjugate(verb("食べる", "たべる", .godanKu), to: .te))
        XCTAssertNil(GrammarConjugationEngine.conjugate(verb("食べる", "たべる", .ichidan, forms: [.te]), to: .desire))
        XCTAssertNil(GrammarConjugationEngine.conjugate(verb("する", "する", .kuru), to: .te))
        XCTAssertNil(GrammarConjugationEngine.conjugate(verb("行く", "いく", .godanKu), to: .te))
        XCTAssertEqual(GrammarConjugationEngine.conjugate(verb("くださる", "くださる", .honorificRu), to: .masu)?.text, "くださいます")
        XCTAssertNil(GrammarConjugationEngine.conjugate(verb("くださる", "くださる", .honorificRu), to: .desire))
    }
}
