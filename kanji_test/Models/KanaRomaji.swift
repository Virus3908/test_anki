import Foundation

/// Транслитерация кана → ромадзи (wapuro-стиль: こう → "kou", きゃ → "kya").
///
/// Используется поиском карточек, чтобы запрос «kuchi» находил くち,
/// а «go» — ゴ. Некана-символы (точки, латиница) проходят без изменений.
enum KanaRomaji {
    /// Хирагана и катакана дают одинаковый ромадзи, поэтому таблица единая:
    /// ключ — базовый знак, значение — его ромадзи.
    private static let base: [Character: String] = [
        // 平仮名 / 片仮名 — базовые знаки.
        "あ": "a", "い": "i", "う": "u", "え": "e", "お": "o",
        "か": "ka", "き": "ki", "く": "ku", "け": "ke", "こ": "ko",
        "さ": "sa", "し": "shi", "す": "su", "せ": "se", "そ": "so",
        "た": "ta", "ち": "chi", "つ": "tsu", "て": "te", "と": "to",
        "な": "na", "に": "ni", "ぬ": "nu", "ね": "ne", "の": "no",
        "は": "ha", "ひ": "hi", "ふ": "fu", "へ": "he", "ほ": "ho",
        "ま": "ma", "み": "mi", "む": "mu", "め": "me", "も": "mo",
        "や": "ya", "ゆ": "yu", "よ": "yo",
        "ら": "ra", "り": "ri", "る": "ru", "れ": "re", "ろ": "ro",
        "わ": "wa", "を": "o",
        // Дакутэн/хандакутэн.
        "が": "ga", "ぎ": "gi", "ぐ": "gu", "げ": "ge", "ご": "go",
        "ざ": "za", "じ": "ji", "ず": "zu", "ぜ": "ze", "ぞ": "zo",
        "だ": "da", "ぢ": "di", "づ": "du", "で": "de", "ど": "do",
        "ば": "ba", "び": "bi", "ぶ": "bu", "べ": "be", "ぼ": "bo",
        "ぱ": "pa", "ぴ": "pi", "ぷ": "pu", "ぺ": "pe", "ぽ": "po",
        // カタカна.
        "ア": "a", "イ": "i", "ウ": "u", "エ": "e", "オ": "o",
        "カ": "ka", "キ": "ki", "ク": "ku", "ケ": "ke", "コ": "ko",
        "サ": "sa", "シ": "shi", "ス": "su", "セ": "se", "ソ": "so",
        "タ": "ta", "チ": "chi", "ツ": "tsu", "テ": "te", "ト": "to",
        "ナ": "na", "ニ": "ni", "ヌ": "nu", "ネ": "ne", "ノ": "no",
        "ハ": "ha", "ヒ": "hi", "フ": "fu", "ヘ": "he", "ホ": "ho",
        "マ": "ma", "ミ": "mi", "ム": "mu", "メ": "me", "モ": "mo",
        "ヤ": "ya", "ユ": "yu", "ヨ": "yo",
        "ラ": "ra", "リ": "ri", "ル": "ru", "レ": "re", "ロ": "ro",
        "ワ": "wa", "ヲ": "o",
        "ガ": "ga", "ギ": "gi", "グ": "gu", "ゲ": "ge", "ゴ": "go",
        "ザ": "za", "ジ": "ji", "ズ": "zu", "ゼ": "ze", "ゾ": "zo",
        "ダ": "da", "ヂ": "di", "ヅ": "du", "デ": "de", "ド": "do",
        "バ": "ba", "ビ": "bi", "ブ": "bu", "ベ": "be", "ボ": "bo",
        "パ": "pa", "ピ": "pi", "プ": "pu", "ペ": "pe", "ポ": "po",
        // ン и っ обрабатываются отдельно (см. convert(_:)).
        "ン": "n",
        // Малые гласные (外来借用 вроде てぃ) читаются как обычные гласные.
        "ぁ": "a", "ぃ": "i", "ぅ": "u", "ぇ": "e", "ぉ": "o",
        "ァ": "a", "ィ": "i", "ゥ": "u", "ェ": "e", "ォ": "o",
    ]

    /// Ёон: пара «знак + малая ゃ/ゅ/ょ» → ромадзи слога.
    private static let digraphs: [Character: [Character: String]] = [
        "き": ["ゃ": "kya", "ゅ": "kyu", "ょ": "kyo"],
        "し": ["ゃ": "sha", "ゅ": "shu", "ょ": "sho"],
        "ち": ["ゃ": "cha", "ゅ": "chu", "ょ": "cho"],
        "に": ["ゃ": "nya", "ゅ": "nyu", "ょ": "nyo"],
        "ひ": ["ゃ": "hya", "ゅ": "hyu", "ょ": "hyo"],
        "み": ["ゃ": "mya", "ゅ": "myu", "ょ": "myo"],
        "り": ["ゃ": "rya", "ゅ": "ryu", "ょ": "ryo"],
        "ぎ": ["ゃ": "gya", "ゅ": "gyu", "ょ": "gyo"],
        "じ": ["ゃ": "ja", "ゅ": "ju", "ょ": "jo"],
        "び": ["ゃ": "bya", "ゅ": "byu", "ょ": "byo"],
        "ぴ": ["ゃ": "pya", "ゅ": "pyu", "ょ": "pyo"],
        "キ": ["ャ": "kya", "ュ": "kyu", "ョ": "kyo"],
        "シ": ["ャ": "sha", "ュ": "shu", "ョ": "sho"],
        "チ": ["ャ": "cha", "ュ": "chu", "ョ": "cho"],
        "ニ": ["ャ": "nya", "ュ": "nyu", "ョ": "nyo"],
        "ヒ": ["ャ": "hya", "ュ": "hyu", "ョ": "hyo"],
        "ミ": ["ャ": "mya", "ュ": "myu", "ョ": "myo"],
        "リ": ["ャ": "rya", "ュ": "ryu", "ョ": "ryo"],
        "ギ": ["ャ": "gya", "ュ": "gyu", "ョ": "gyo"],
        "ジ": ["ャ": "ja", "ュ": "ju", "ョ": "jo"],
        "ビ": ["ャ": "bya", "ュ": "byu", "ョ": "byo"],
        "ピ": ["ャ": "pya", "ュ": "pyu", "ョ": "pyo"],
    ]

    /// Переводит строку с кана в ромадзи.
    ///
    ///     KanaRomaji.convert("くち")     // "kuchi"
    ///     KanaRomaji.convert("ゴ")       // "go"
    ///     KanaRomaji.convert("きょう")   // "kyou"
    ///     KanaRomaji.convert("いっぱい")  // "ippai"
    static func convert(_ kana: String) -> String {
        let characters = Array(kana)
        var result = ""
        result.reserveCapacity(characters.count * 2)
        var index = 0

        while index < characters.count {
            let character = characters[index]

            // Ёон: き + ゃ → "kya".
            if index + 1 < characters.count,
               let digraph = digraph(for: character, followedBy: characters[index + 1]) {
                result += digraph
                index += 2
                continue
            }

            switch character {
            case "っ", "ッ":
                // Удвоение согласной: っ + か → "kka", っ + ち → "tchi".
                if index + 1 < characters.count, let romaji = base[characters[index + 1]] {
                    result += consonant(of: romaji) + romaji
                    index += 2
                } else {
                    index += 1
                }
            case "ー":
                // Продление гласной: コー → "koo".
                if let last = result.last, "aiueo".contains(last) {
                    result.append(last)
                }
                index += 1
            default:
                result += base[character] ?? String(character)
                index += 1
            }
        }

        return result
    }

    /// Ромадзи с «сжатыми» долгими гласными: こう → "ko", コーヒー → "kohi".
    /// Второй вариант записи помогает запросам вроде «koen» находить こうえん.
    static func compact(_ romaji: String) -> String {
        var result = ""
        var last: Character?

        for character in romaji {
            // После гласной опускаем «u» и повтор той же гласной: ou/oo/uu → одна.
            if let previous = last,
               "aiueo".contains(previous),
               character == "u" || character == previous {
                continue
            }
            result.append(character)
            last = character
        }

        return result
    }

    /// Пара «знак + малая ゃ/ゅ/ょ», если она читается одним слогом.
    private static func digraph(for character: Character, followedBy next: Character) -> String? {
        guard "ゃゅょャュョ".contains(next) else { return nil }
        return digraphs[character]?[next]
    }

    /// Согласная часть слога: "ka" → "k", "chi" → "ch", "kyo" → "ky".
    private static func consonant(of romaji: String) -> String {
        var consonant = ""
        for character in romaji {
            if "aiueo".contains(character) { break }
            consonant.append(character)
        }
        return consonant
    }
}
