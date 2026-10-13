import Foundation

/// Adapted from Nihongo Mono at ec0ba4a0ce1611c568b0e4f8a223eb8029249a25.
/// MIT © 2026 Stefanus Ndaru Wedhatama; see NihongoMono-LICENSE.txt.
/// Class and permitted forms are editorial input, never guessed from spelling.
nonisolated enum GrammarConjugationEngine {
    enum VerbClass: String, Codable, Sendable {
        case ichidan, godanU, godanKu, godanGu, godanSu, godanTsu, godanNu, godanBu, godanMu, godanRu
        case iku, suru, kuru, aru, honorificRu
    }
    enum Form: String, Codable, Sendable, CaseIterable {
        case stem, masu, te, ta, nai, potential, passive, causative, conditionalBa, conditionalTara, desire
    }
    struct Verb: Codable, Sendable {
        let dictionary: String
        let reading: String
        let verbClass: VerbClass
        let permittedForms: Set<Form>
    }
    struct Surface: Equatable, Sendable { let text: String; let reading: String }

    static func conjugate(_ verb: Verb, to form: Form) -> Surface? {
        guard verb.permittedForms.contains(form), !verb.dictionary.isEmpty, !verb.reading.isEmpty else { return nil }
        let exceptions: [String: VerbClass] = ["行く": .iku, "いく": .iku, "ゆく": .iku,
            "ある": .aru, "有る": .aru, "在る": .aru, "する": .suru, "来る": .kuru, "くる": .kuru,
            "くださる": .honorificRu, "下さる": .honorificRu, "なさる": .honorificRu,
            "いらっしゃる": .honorificRu, "おっしゃる": .honorificRu, "仰る": .honorificRu, "ござる": .honorificRu]
        if let required = exceptions[verb.dictionary], verb.verbClass != required { return nil }
        if verb.verbClass == .honorificRu && exceptions[verb.dictionary] != .honorificRu { return nil }
        func replace(_ text: String, suffix: String, with value: String) -> String? {
            guard text.hasSuffix(suffix) else { return nil }
            return String(text.dropLast(suffix.count)) + value
        }
        if verb.verbClass == .suru {
            let endings: [Form: String] = [.stem: "し", .masu: "します", .te: "して", .ta: "した", .nai: "しない",
                .potential: "できる", .passive: "される", .causative: "させる", .conditionalBa: "すれば",
                .conditionalTara: "したら", .desire: "したい"]
            guard let ending = endings[form], let text = replace(verb.dictionary, suffix: "する", with: ending),
                  let reading = replace(verb.reading, suffix: "する", with: ending) else { return nil }
            return Surface(text: text, reading: reading)
        }
        if verb.verbClass == .kuru {
            let endings: [Form: (String, String)] = [.stem: ("来", "き"), .masu: ("来ます", "きます"),
                .te: ("来て", "きて"), .ta: ("来た", "きた"), .nai: ("来ない", "こない"),
                .potential: ("来られる", "こられる"), .passive: ("来られる", "こられる"),
                .causative: ("来させる", "こさせる"), .conditionalBa: ("来れば", "くれば"),
                .conditionalTara: ("来たら", "きたら"), .desire: ("来たい", "きたい")]
            guard let ending = endings[form], let reading = replace(verb.reading, suffix: "くる", with: ending.1) else { return nil }
            let text = verb.dictionary.hasSuffix("来る")
                ? replace(verb.dictionary, suffix: "来る", with: ending.0)
                : replace(verb.dictionary, suffix: "くる", with: ending.1)
            return text.map { Surface(text: $0, reading: reading) }
        }
        if verb.verbClass == .aru {
            guard ![Form.potential, .passive, .causative, .desire].contains(form),
                  ["ある", "有る", "在る"].contains(verb.dictionary), verb.reading == "ある" else { return nil }
            if form == .nai { return Surface(text: "ない", reading: "ない") }
        }
        if verb.verbClass == .honorificRu && [.potential, .passive, .causative, .desire].contains(form) { return nil }
        let suffix: String
        let expected: String
        if verb.verbClass == .ichidan {
            expected = "る"
            let endings: [Form: String] = [.stem: "", .masu: "ます", .te: "て", .ta: "た", .nai: "ない",
                .potential: "られる", .passive: "られる", .causative: "させる", .conditionalBa: "れば",
                .conditionalTara: "たら", .desire: "たい"]
            guard let value = endings[form] else { return nil }; suffix = value
        } else {
            // Dictionary, a-row, i-row, e-row, te, ta. Exceptions have their own explicit class.
            let rows: [VerbClass: [String]] = [
                .godanU: ["う", "わ", "い", "え", "って", "った"],
                .godanKu: ["く", "か", "き", "け", "いて", "いた"],
                .iku: ["く", "か", "き", "け", "って", "った"],
                .godanGu: ["ぐ", "が", "ぎ", "げ", "いで", "いだ"],
                .godanSu: ["す", "さ", "し", "せ", "して", "した"],
                .godanTsu: ["つ", "た", "ち", "て", "って", "った"],
                .godanNu: ["ぬ", "な", "に", "ね", "んで", "んだ"],
                .godanBu: ["ぶ", "ば", "び", "べ", "んで", "んだ"],
                .godanMu: ["む", "ま", "み", "め", "んで", "んだ"],
                .godanRu: ["る", "ら", "り", "れ", "って", "った"],
                .aru: ["る", "ら", "り", "れ", "って", "った"],
                .honorificRu: ["る", "ら", "い", "れ", "って", "った"]]
            guard let row = rows[verb.verbClass] else { return nil }; expected = row[0]
            if verb.verbClass == .iku && (!["行く", "いく", "ゆく"].contains(verb.dictionary)
                || !["いく", "ゆく"].contains(verb.reading)) { return nil }
            switch form {
            case .stem: suffix = row[2]
            case .masu: suffix = row[2] + "ます"
            case .te: suffix = row[4]
            case .ta: suffix = row[5]
            case .nai: suffix = row[1] + "ない"
            case .potential: suffix = row[3] + "る"
            case .passive: suffix = row[1] + "れる"
            case .causative: suffix = row[1] + "せる"
            case .conditionalBa: suffix = row[3] + "ば"
            case .conditionalTara: suffix = row[5] + "ら"
            case .desire: suffix = row[2] + "たい"
            }
        }
        guard let text = replace(verb.dictionary, suffix: expected, with: suffix),
              let reading = replace(verb.reading, suffix: expected, with: suffix) else { return nil }
        return Surface(text: text, reading: reading)
    }
}
