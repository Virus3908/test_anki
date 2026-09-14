import Foundation
import CoreGraphics
import Translation

struct KanjiCard: Codable, Identifiable, Sendable {
    var id: String { kanji }

    let kanji: String
    let meanings: [String]
    let onyomi: [String]
    let kunyomi: [String]
    let examples: [KanjiExample]
    let source: KanjiSource
    let strokes: [KanjiStroke]
    let grade: Int?
    let jlpt: Int?
    let translationState: String?

    init(
        kanji: String,
        meanings: [String],
        onyomi: [String],
        kunyomi: [String],
        examples: [KanjiExample],
        source: KanjiSource,
        strokes: [KanjiStroke],
        grade: Int? = nil,
        jlpt: Int? = nil,
        translationState: String? = nil
    ) {
        self.kanji = kanji
        self.meanings = meanings
        self.onyomi = onyomi
        self.kunyomi = kunyomi
        self.examples = examples
        self.source = source
        self.strokes = strokes
        self.grade = grade
        self.jlpt = jlpt
        self.translationState = translationState
    }

    func translated(meanings: [String], examples: [KanjiExample]) -> KanjiCard {
        KanjiCard(
            kanji: kanji,
            meanings: meanings,
            onyomi: onyomi,
            kunyomi: kunyomi,
            examples: examples,
            source: source,
            strokes: strokes,
            grade: grade,
            jlpt: jlpt,
            translationState: "ru-system"
        )
    }
}

struct KanjiExample: Codable, Identifiable, Sendable {
    var id: String { "\(word)-\(reading)" }

    let word: String
    let reading: String
    let meaning: String
}

enum PracticeMode: String, CaseIterable, Identifiable {
    case kanji
    case words
    case hiragana
    case katakana

    var id: String { rawValue }

    var title: String {
        switch self {
        case .kanji:
            return "Кандзи"
        case .words:
            return "Слова"
        case .hiragana:
            return "Хирагана"
        case .katakana:
            return "Катакана"
        }
    }
}

struct WordStudyCard: Identifiable, Sendable {
    var id: String { "\(word)-\(reading)" }

    let word: String
    let reading: String
    let meaning: String
    let kanjiCards: [KanjiCard]

    var kanjiText: String {
        kanjiCards.map(\.kanji).joined()
    }

    static func build(from cards: [KanjiCard]) -> [WordStudyCard] {
        let cardsByKanji = Dictionary(cards.map { ($0.kanji, $0) }, uniquingKeysWith: { current, _ in current })
        var seen: Set<String> = []
        var result: [WordStudyCard] = []

        for card in cards {
            for example in card.examples {
                let characters = example.word.map(String.init)
                let wordStudyCards = characters.compactMap { character -> KanjiCard? in
                    if let card = cardsByKanji[character] {
                        return card
                    }

                    guard isKana(character) else {
                        return nil
                    }

                    return kanaCard(for: character)
                }
                guard characters.allSatisfy(isJapaneseStudyCharacter),
                      wordStudyCards.count == characters.count,
                      seen.insert(example.word).inserted else {
                    continue
                }

                result.append(
                    WordStudyCard(
                        word: example.word,
                        reading: example.reading,
                        meaning: example.meaning,
                        kanjiCards: wordStudyCards
                    )
                )
            }
        }

        return result.sorted { left, right in
            if left.kanjiCards.count != right.kanjiCards.count {
                return left.kanjiCards.count < right.kanjiCards.count
            }

            if left.word.count != right.word.count {
                return left.word.count < right.word.count
            }

            return left.word < right.word
        }
    }

    nonisolated private static func isKanji(_ text: String) -> Bool {
        guard let scalar = text.unicodeScalars.first else {
            return false
        }

        return (0x4E00...0x9FFF).contains(Int(scalar.value))
    }

    nonisolated private static func isKana(_ text: String) -> Bool {
        guard let scalar = text.unicodeScalars.first else {
            return false
        }

        let value = Int(scalar.value)
        return (0x3040...0x309F).contains(value)
            || (0x30A0...0x30FF).contains(value)
    }

    private static func kanaCard(for character: String) -> KanjiCard {
        KanjiCard(
            kanji: character,
            meanings: [],
            onyomi: [],
            kunyomi: [],
            examples: [],
            source: KanjiSource(name: "Kana", file: "local-kana", license: "App data"),
            strokes: [],
            translationState: "ru-system"
        )
    }

    nonisolated private static func isJapaneseStudyCharacter(_ text: String) -> Bool {
        guard let scalar = text.unicodeScalars.first else {
            return false
        }

        let value = Int(scalar.value)
        return (0x3040...0x309F).contains(value)
            || (0x30A0...0x30FF).contains(value)
            || (0x4E00...0x9FFF).contains(value)
    }
}

struct KanaStudyCard: Identifiable, Sendable {
    var id: String { character }

    let character: String
    let reading: String

    static let hiragana: [KanaStudyCard] = cards([
        ("あ", "a"), ("い", "i"), ("う", "u"), ("え", "e"), ("お", "o"),
        ("か", "ka"), ("き", "ki"), ("く", "ku"), ("け", "ke"), ("こ", "ko"),
        ("さ", "sa"), ("し", "shi"), ("す", "su"), ("せ", "se"), ("そ", "so"),
        ("た", "ta"), ("ち", "chi"), ("つ", "tsu"), ("て", "te"), ("と", "to"),
        ("な", "na"), ("に", "ni"), ("ぬ", "nu"), ("ね", "ne"), ("の", "no"),
        ("は", "ha"), ("ひ", "hi"), ("ふ", "fu"), ("へ", "he"), ("ほ", "ho"),
        ("ま", "ma"), ("み", "mi"), ("む", "mu"), ("め", "me"), ("も", "mo"),
        ("や", "ya"), ("ゆ", "yu"), ("よ", "yo"),
        ("ら", "ra"), ("り", "ri"), ("る", "ru"), ("れ", "re"), ("ろ", "ro"),
        ("わ", "wa"), ("を", "wo"), ("ん", "n"),
        ("が", "ga"), ("ぎ", "gi"), ("ぐ", "gu"), ("げ", "ge"), ("ご", "go"),
        ("ざ", "za"), ("じ", "ji"), ("ず", "zu"), ("ぜ", "ze"), ("ぞ", "zo"),
        ("だ", "da"), ("ぢ", "ji"), ("づ", "zu"), ("で", "de"), ("ど", "do"),
        ("ば", "ba"), ("び", "bi"), ("ぶ", "bu"), ("べ", "be"), ("ぼ", "bo"),
        ("ぱ", "pa"), ("ぴ", "pi"), ("ぷ", "pu"), ("ぺ", "pe"), ("ぽ", "po"),
        ("ぁ", "small a"), ("ぃ", "small i"), ("ぅ", "small u"), ("ぇ", "small e"), ("ぉ", "small o"),
        ("ゃ", "small ya"), ("ゅ", "small yu"), ("ょ", "small yo"), ("っ", "small tsu"), ("ゎ", "small wa"),
        ("きゃ", "kya"), ("きゅ", "kyu"), ("きょ", "kyo"),
        ("しゃ", "sha"), ("しゅ", "shu"), ("しょ", "sho"),
        ("ちゃ", "cha"), ("ちゅ", "chu"), ("ちょ", "cho"),
        ("にゃ", "nya"), ("にゅ", "nyu"), ("にょ", "nyo"),
        ("ひゃ", "hya"), ("ひゅ", "hyu"), ("ひょ", "hyo"),
        ("みゃ", "mya"), ("みゅ", "myu"), ("みょ", "myo"),
        ("りゃ", "rya"), ("りゅ", "ryu"), ("りょ", "ryo"),
        ("ぎゃ", "gya"), ("ぎゅ", "gyu"), ("ぎょ", "gyo"),
        ("じゃ", "ja"), ("じゅ", "ju"), ("じょ", "jo"),
        ("びゃ", "bya"), ("びゅ", "byu"), ("びょ", "byo"),
        ("ぴゃ", "pya"), ("ぴゅ", "pyu"), ("ぴょ", "pyo")
    ])

    static let katakana: [KanaStudyCard] = cards([
        ("ア", "a"), ("イ", "i"), ("ウ", "u"), ("エ", "e"), ("オ", "o"),
        ("カ", "ka"), ("キ", "ki"), ("ク", "ku"), ("ケ", "ke"), ("コ", "ko"),
        ("サ", "sa"), ("シ", "shi"), ("ス", "su"), ("セ", "se"), ("ソ", "so"),
        ("タ", "ta"), ("チ", "chi"), ("ツ", "tsu"), ("テ", "te"), ("ト", "to"),
        ("ナ", "na"), ("ニ", "ni"), ("ヌ", "nu"), ("ネ", "ne"), ("ノ", "no"),
        ("ハ", "ha"), ("ヒ", "hi"), ("フ", "fu"), ("ヘ", "he"), ("ホ", "ho"),
        ("マ", "ma"), ("ミ", "mi"), ("ム", "mu"), ("メ", "me"), ("モ", "mo"),
        ("ヤ", "ya"), ("ユ", "yu"), ("ヨ", "yo"),
        ("ラ", "ra"), ("リ", "ri"), ("ル", "ru"), ("レ", "re"), ("ロ", "ro"),
        ("ワ", "wa"), ("ヲ", "wo"), ("ン", "n"),
        ("ガ", "ga"), ("ギ", "gi"), ("グ", "gu"), ("ゲ", "ge"), ("ゴ", "go"),
        ("ザ", "za"), ("ジ", "ji"), ("ズ", "zu"), ("ゼ", "ze"), ("ゾ", "zo"),
        ("ダ", "da"), ("ヂ", "ji"), ("ヅ", "zu"), ("デ", "de"), ("ド", "do"),
        ("バ", "ba"), ("ビ", "bi"), ("ブ", "bu"), ("ベ", "be"), ("ボ", "bo"),
        ("パ", "pa"), ("ピ", "pi"), ("プ", "pu"), ("ペ", "pe"), ("ポ", "po"),
        ("ァ", "small a"), ("ィ", "small i"), ("ゥ", "small u"), ("ェ", "small e"), ("ォ", "small o"),
        ("ャ", "small ya"), ("ュ", "small yu"), ("ョ", "small yo"), ("ッ", "small tsu"), ("ヮ", "small wa"),
        ("ヴ", "vu"),
        ("キャ", "kya"), ("キュ", "kyu"), ("キョ", "kyo"),
        ("シャ", "sha"), ("シュ", "shu"), ("ショ", "sho"),
        ("チャ", "cha"), ("チュ", "chu"), ("チョ", "cho"),
        ("ニャ", "nya"), ("ニュ", "nyu"), ("ニョ", "nyo"),
        ("ヒャ", "hya"), ("ヒュ", "hyu"), ("ヒョ", "hyo"),
        ("ミャ", "mya"), ("ミュ", "myu"), ("ミョ", "myo"),
        ("リャ", "rya"), ("リュ", "ryu"), ("リョ", "ryo"),
        ("ギャ", "gya"), ("ギュ", "gyu"), ("ギョ", "gyo"),
        ("ジャ", "ja"), ("ジュ", "ju"), ("ジョ", "jo"),
        ("ビャ", "bya"), ("ビュ", "byu"), ("ビョ", "byo"),
        ("ピャ", "pya"), ("ピュ", "pyu"), ("ピョ", "pyo")
    ])

    private static func cards(_ pairs: [(String, String)]) -> [KanaStudyCard] {
        pairs.map { KanaStudyCard(character: $0.0, reading: $0.1) }
    }
}

enum WordFrequencyDeck: String, CaseIterable, Identifiable, Sendable {
    case top1000
    case top2000
    case top5000
    case top10000

    var id: String { rawValue }

    var title: String {
        switch self {
        case .top1000:
            return "0-1000"
        case .top2000:
            return "1001-2000"
        case .top5000:
            return "2001-5000"
        case .top10000:
            return "5001-10000"
        }
    }

    var subtitle: String {
        "Диапазон частоты слов"
    }

    var bounds: Range<Int> {
        switch self {
        case .top1000:
            return 0..<1000
        case .top2000:
            return 1000..<2000
        case .top5000:
            return 2000..<5000
        case .top10000:
            return 5000..<10000
        }
    }

    static var groups: [(title: String, decks: [WordFrequencyDeck])] {
        [
            ("Frequency", [.top1000, .top2000, .top5000, .top10000])
        ]
    }

    func cards(from words: [WordStudyCard]) -> [WordStudyCard] {
        let ordered = words.sorted { left, right in
            if left.word.count != right.word.count {
                return left.word.count < right.word.count
            }

            if left.kanjiCards.count != right.kanjiCards.count {
                return left.kanjiCards.count < right.kanjiCards.count
            }

            return left.word < right.word
        }

        return Array(ordered[bounds.clamped(to: ordered.indices)])
    }
}

struct KanjiSource: Codable, Sendable {
    let name: String
    let file: String
    let license: String
}

struct KanjiStroke: Codable, Identifiable, Sendable {
    var id: Int { order }

    let order: Int
    let pathData: String
    let start: [Double]
    let end: [Double]
    let axis: StrokeAxis

    enum CodingKeys: String, CodingKey {
        case order
        case pathData = "path"
        case start
        case end
        case axis
    }

    var startPoint: CGPoint {
        CGPoint(x: start[0], y: start[1])
    }

    var endPoint: CGPoint {
        CGPoint(x: end[0], y: end[1])
    }
}

enum StrokeAxis: String, Codable, Sendable {
    case horizontal
    case vertical
    case corner
}

enum ReviewRating: String, CaseIterable, Identifiable, Codable {
    case again
    case hard
    case good

    var id: String { rawValue }

    var title: String {
        switch self {
        case .again:
            return "Неправильно"
        case .hard:
            return "Почти"
        case .good:
            return "Правильно"
        }
    }

    var iconName: String {
        switch self {
        case .again:
            return "xmark.circle.fill"
        case .hard:
            return "exclamationmark.circle.fill"
        case .good:
            return "checkmark.circle.fill"
        }
    }
}

struct KanjiReviewRecord: Codable {
    var attempts: Int
    var successes: Int
    var streak: Int
    var intervalDays: Double
    var dueDate: Date
    var lastRating: ReviewRating
    var lastReviewedAt: Date
}

struct KanjiReviewStore: Codable {
    private(set) var records: [String: KanjiReviewRecord]

    static func load() -> KanjiReviewStore {
        do {
            let url = try storageURL()
            guard FileManager.default.fileExists(atPath: url.path) else {
                return KanjiReviewStore(records: [:])
            }

            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(KanjiReviewStore.self, from: data)
        } catch {
            assertionFailure("Failed to load review memory: \(error)")
            return KanjiReviewStore(records: [:])
        }
    }

    mutating func apply(_ rating: ReviewRating, to kanji: String, now: Date = Date()) {
        var record = records[kanji] ?? KanjiReviewRecord(
            attempts: 0,
            successes: 0,
            streak: 0,
            intervalDays: 0,
            dueDate: now,
            lastRating: rating,
            lastReviewedAt: now
        )

        record.attempts += 1
        record.lastRating = rating
        record.lastReviewedAt = now

        switch rating {
        case .again:
            record.streak = 0
            record.intervalDays = 0
            record.dueDate = now
        case .hard:
            record.streak = max(0, record.streak)
            record.intervalDays = max(0.02, record.intervalDays * 0.5)
            record.dueDate = now.addingTimeInterval(30 * 60)
        case .good:
            record.successes += 1
            record.streak += 1
            if record.intervalDays == 0 {
                record.intervalDays = 1
            } else {
                record.intervalDays = min(record.intervalDays * 2.5, 180)
            }
            record.dueDate = now.addingTimeInterval(record.intervalDays * 24 * 60 * 60)
        }

        records[kanji] = record
        save()
    }

    func record(for kanji: String) -> KanjiReviewRecord? {
        records[kanji]
    }

    func orderedCards(_ cards: [KanjiCard], now: Date = Date()) -> [KanjiCard] {
        cards.sorted { left, right in
            let leftDate = records[left.kanji]?.dueDate ?? .distantPast
            let rightDate = records[right.kanji]?.dueDate ?? .distantPast
            let leftDue = leftDate <= now
            let rightDue = rightDate <= now

            if leftDue != rightDue {
                return leftDue
            }

            if leftDate != rightDate {
                return leftDate < rightDate
            }

            return left.kanji < right.kanji
        }
    }

    private func save() {
        do {
            let url = try Self.storageURL()
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(self)
            try data.write(to: url, options: .atomic)
        } catch {
            assertionFailure("Failed to save review memory: \(error)")
        }
    }

    private static func storageURL() throws -> URL {
        let directory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        return directory
            .appendingPathComponent("KanjiTrainer", isDirectory: true)
            .appendingPathComponent("review-memory.json")
    }
}

enum KanjiDeck: String, CaseIterable, Identifiable {
    case jlpt5
    case jlpt4
    case jlpt3
    case jlpt2
    case jlpt1
    case grade1
    case grade2
    case grade3
    case grade4
    case grade5
    case grade6
    case grade8
    case joyo
    case jinmeiyo
    case all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .jlpt5:
            return "JLPT N5"
        case .jlpt4:
            return "JLPT N4"
        case .jlpt3:
            return "JLPT N3"
        case .jlpt2:
            return "JLPT N2"
        case .jlpt1:
            return "JLPT N1"
        case .grade1:
            return "Grade 1"
        case .grade2:
            return "Grade 2"
        case .grade3:
            return "Grade 3"
        case .grade4:
            return "Grade 4"
        case .grade5:
            return "Grade 5"
        case .grade6:
            return "Grade 6"
        case .grade8:
            return "Secondary School"
        case .joyo:
            return "Joyo"
        case .jinmeiyo:
            return "Jinmeiyo"
        case .all:
            return "All kanji"
        }
    }

    var endpointPath: String {
        switch self {
        case .jlpt5:
            return "jlpt-5"
        case .jlpt4:
            return "jlpt-4"
        case .jlpt3:
            return "jlpt-3"
        case .jlpt2:
            return "jlpt-2"
        case .jlpt1:
            return "jlpt-1"
        case .grade1:
            return "grade-1"
        case .grade2:
            return "grade-2"
        case .grade3:
            return "grade-3"
        case .grade4:
            return "grade-4"
        case .grade5:
            return "grade-5"
        case .grade6:
            return "grade-6"
        case .grade8:
            return "grade-8"
        case .joyo:
            return "joyo"
        case .jinmeiyo:
            return "jinmeiyo"
        case .all:
            return "all"
        }
    }

    var masterFilter: (KanjiCard) -> Bool {
        switch self {
        case .jlpt5:
            return { $0.jlpt == 5 }
        case .jlpt4:
            return { $0.jlpt == 4 }
        case .jlpt3:
            return { $0.jlpt == 3 }
        case .jlpt2:
            return { $0.jlpt == 2 }
        case .jlpt1:
            return { $0.jlpt == 1 }
        case .grade1:
            return { $0.grade == 1 }
        case .grade2:
            return { $0.grade == 2 }
        case .grade3:
            return { $0.grade == 3 }
        case .grade4:
            return { $0.grade == 4 }
        case .grade5:
            return { $0.grade == 5 }
        case .grade6:
            return { $0.grade == 6 }
        case .grade8:
            return { $0.grade == 8 }
        case .joyo, .jinmeiyo:
            return { _ in false }
        case .all:
            return { _ in true }
        }
    }

    static var groups: [(title: String, decks: [KanjiDeck])] {
        [
            ("JLPT", [.jlpt5, .jlpt4, .jlpt3, .jlpt2, .jlpt1]),
            ("School grades", [.grade1, .grade2, .grade3, .grade4, .grade5, .grade6, .grade8]),
            ("Other kanjiapi.dev sets", [.joyo, .jinmeiyo, .all])
        ]
    }
}

enum KanjiDataLoader {
    static func loadBundledMasterCards() -> [KanjiCard] {
        guard let url = Bundle.main.url(forResource: "kanji-all", withExtension: "json") else {
            return []
        }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([KanjiCard].self, from: data)
        } catch {
            assertionFailure("Failed to decode kanji-all.json: \(error)")
            return []
        }
    }

    static func loadAvailableCards(deck: KanjiDeck) -> [KanjiCard] {
        let masterCards = loadBundledMasterCards()
        let masterDeckCards = masterCards.filter(deck.masterFilter)
        if !masterDeckCards.isEmpty {
            return masterDeckCards
        }

        if deck != .all, let allCachedCards = try? loadCachedCards(for: .all), !allCachedCards.isEmpty {
            let filteredCards = allCachedCards.filter(deck.masterFilter)
            if !filteredCards.isEmpty {
                return filteredCards
            }
        }

        if let cachedCards = try? loadCachedCards(for: deck), !cachedCards.isEmpty {
            return cachedCards
        }

        return []
    }

    static func loadLocalCards() -> [KanjiCard] {
        guard let url = Bundle.main.url(forResource: "kanji-data", withExtension: "json") else {
            assertionFailure("kanji-data.json is missing from the app bundle.")
            return []
        }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([KanjiCard].self, from: data)
        } catch {
            assertionFailure("Failed to decode kanji-data.json: \(error)")
            return []
        }
    }

    static func loadCards(deck: KanjiDeck = .jlpt5) async -> [KanjiCard] {
        let availableCards = loadAvailableCards(deck: deck)
        if !availableCards.isEmpty {
            return availableCards
        }

        do {
            let cachedCards = try loadCachedCards(for: deck) ?? []
            let remoteKanjiList = try await RemoteKanjiProvider.loadKanjiList(deck: deck)

            if !cachedCards.isEmpty {
                let cachedByKanji = Dictionary(cachedCards.map { ($0.kanji, $0) }, uniquingKeysWith: { current, _ in current })
                let missingKanji = remoteKanjiList.filter { cachedByKanji[$0] == nil }

                if missingKanji.isEmpty {
                    return remoteKanjiList.compactMap { cachedByKanji[$0] }
                }

                let missingCards = try await RemoteKanjiProvider.loadCards(for: missingKanji)
                let mergedByKanji = Dictionary((cachedCards + missingCards).map { ($0.kanji, $0) }, uniquingKeysWith: { _, new in new })
                let mergedCards = remoteKanjiList.compactMap { mergedByKanji[$0] }

                if !mergedCards.isEmpty {
                    try mergeCardsIntoAllCache(mergedCards)
                    return mergedCards
                }
            }

            let remoteCards = try await RemoteKanjiProvider.loadCards(for: remoteKanjiList)
            if !remoteCards.isEmpty {
                try mergeCardsIntoAllCache(remoteCards)
                return remoteCards
            }
        } catch {
            if let cachedCards = try? loadCachedCards(for: deck), !cachedCards.isEmpty {
                return cachedCards
            }

            assertionFailure("Failed to load remote kanji data: \(error)")
        }

        return loadLocalCards()
    }

    static func loadCardsProgressively(
        deck: KanjiDeck,
        onUpdate: @MainActor @escaping ([KanjiCard], Int?) -> Void
    ) async {
        let bundledOrCachedCards = loadAvailableCards(deck: deck)
        if !bundledOrCachedCards.isEmpty {
            onUpdate(bundledOrCachedCards, bundledOrCachedCards.count)
        }

        do {
            let remoteKanjiList = try await RemoteKanjiProvider.loadKanjiList(deck: deck)
            var cardsByKanji = Dictionary(bundledOrCachedCards.map { ($0.kanji, $0) }, uniquingKeysWith: { current, _ in current })
            let missingKanji = remoteKanjiList.filter { cardsByKanji[$0] == nil }

            if missingKanji.isEmpty {
                let orderedCards = remoteKanjiList.compactMap { cardsByKanji[$0] }
                onUpdate(orderedCards, remoteKanjiList.count)
                return
            }

            for await batch in RemoteKanjiProvider.loadCardsStream(for: missingKanji) {
                for card in batch {
                    cardsByKanji[card.kanji] = card
                }

                let orderedCards = remoteKanjiList.compactMap { cardsByKanji[$0] }
                onUpdate(orderedCards, remoteKanjiList.count)
            }

            let finalCards = remoteKanjiList.compactMap { cardsByKanji[$0] }
            if !finalCards.isEmpty {
                try mergeCardsIntoAllCache(finalCards)
                onUpdate(finalCards, remoteKanjiList.count)
            }
        } catch {
            if bundledOrCachedCards.isEmpty {
                onUpdate(loadLocalCards(), nil)
            }
        }
    }

    static func clearCache() {
        do {
            let directory = cacheDirectoryURL()
            guard FileManager.default.fileExists(atPath: directory.path) else {
                return
            }

            try FileManager.default.removeItem(at: directory)
        } catch {
            assertionFailure("Failed to clear kanji deck cache: \(error)")
        }
    }

    static func translateCardIfNeeded(_ card: KanjiCard, deck: KanjiDeck) async -> KanjiCard {
        guard card.translationState != "ru-system" else {
            return card
        }

        async let translatedMeanings = RussianMeaningTranslator.translate(card.meanings)
        async let translatedExampleMeanings = RussianMeaningTranslator.translate(card.examples.map(\.meaning))

        let meanings = await translatedMeanings
        let exampleMeanings = await translatedExampleMeanings
        let examples = card.examples.enumerated().map { index, example in
            KanjiExample(
                word: example.word,
                reading: example.reading,
                meaning: index < exampleMeanings.count ? exampleMeanings[index] : example.meaning
            )
        }
        let translatedCard = card.translated(meanings: meanings, examples: examples)

        do {
            try updateCachedCard(translatedCard, for: deck)
        } catch {
            assertionFailure("Failed to update translated kanji cache: \(error)")
        }

        return translatedCard
    }

    private static func loadCachedCards(for deck: KanjiDeck) throws -> [KanjiCard]? {
        let url = cacheURL(for: deck)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }

        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([KanjiCard].self, from: data)
    }

    private static func saveCachedCards(_ cards: [KanjiCard], for deck: KanjiDeck) throws {
        let url = cacheURL(for: deck)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(cards)
        try data.write(to: url, options: .atomic)
    }

    private static func updateCachedCard(_ card: KanjiCard, for deck: KanjiDeck) throws {
        let cacheDeck = deck == .all ? deck : .all
        guard var cachedCards = try loadCachedCards(for: cacheDeck) else {
            try saveCachedCards([card], for: cacheDeck)
            return
        }

        if let index = cachedCards.firstIndex(where: { $0.kanji == card.kanji }) {
            cachedCards[index] = card
        } else {
            cachedCards.append(card)
        }

        try saveCachedCards(cachedCards, for: cacheDeck)
    }

    private static func mergeCardsIntoAllCache(_ cards: [KanjiCard]) throws {
        guard !cards.isEmpty else {
            return
        }

        let existingCards = (try? loadCachedCards(for: .all)) ?? []
        var cardsByKanji = Dictionary(existingCards.map { ($0.kanji, $0) }, uniquingKeysWith: { _, new in new })

        for card in cards {
            cardsByKanji[card.kanji] = card
        }

        try saveCachedCards(cardsByKanji.values.sorted { $0.kanji < $1.kanji }, for: .all)
    }

    private static func cacheURL(for deck: KanjiDeck) -> URL {
        cacheDirectoryURL()
            .appendingPathComponent("\(deck.rawValue).json")
    }

    private static func cacheDirectoryURL() -> URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return caches.appendingPathComponent("KanjiDeckCacheV2", isDirectory: true)
    }
}

private enum RemoteKanjiProvider {
    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 5
        configuration.timeoutIntervalForResource = 8
        return URLSession(configuration: configuration)
    }()

    static func loadKanjiList(deck: KanjiDeck) async throws -> [String] {
        let listURL = URL(string: "https://kanjiapi.dev/v1/kanji/\(deck.endpointPath)")!
        let (listData, _) = try await session.data(from: listURL)
        return try JSONDecoder().decode([String].self, from: listData)
    }

    static func loadCards(deck: KanjiDeck) async throws -> [KanjiCard] {
        let kanjiList = try await loadKanjiList(deck: deck)
        return try await loadCards(for: kanjiList)
    }

    static func loadCards(for kanjiList: [String]) async throws -> [KanjiCard] {
        var cards: [KanjiCard] = []
        var nextIndex = 0
        let maxConcurrentRequests = 16

        await withTaskGroup(of: KanjiCard?.self) { group in
            func enqueueNextCard() {
                guard nextIndex < kanjiList.count else {
                    return
                }

                let kanji = kanjiList[nextIndex]
                nextIndex += 1
                group.addTask {
                    try? await loadCard(for: kanji)
                }
            }

            for _ in 0..<min(maxConcurrentRequests, kanjiList.count) {
                enqueueNextCard()
            }

            for await card in group {
                if let card {
                    cards.append(card)
                }

                enqueueNextCard()
            }
        }

        return cards.sorted { $0.kanji < $1.kanji }
    }

    static func loadCardsStream(for kanjiList: [String]) -> AsyncStream<[KanjiCard]> {
        AsyncStream { continuation in
            let task = Task {
                var batch: [KanjiCard] = []
                var didYieldFirstCard = false
                var nextIndex = 0
                let maxConcurrentRequests = 8

                await withTaskGroup(of: KanjiCard?.self) { group in
                    func enqueueNextCard() {
                        guard nextIndex < kanjiList.count else {
                            return
                        }

                        let kanji = kanjiList[nextIndex]
                        nextIndex += 1
                        group.addTask {
                            try? await loadCard(for: kanji)
                        }
                    }

                    for _ in 0..<min(maxConcurrentRequests, kanjiList.count) {
                        enqueueNextCard()
                    }

                    for await card in group {
                        guard !Task.isCancelled else {
                            return
                        }

                        if let card {
                            if didYieldFirstCard {
                                batch.append(card)
                            } else {
                                continuation.yield([card])
                                didYieldFirstCard = true
                            }
                        }

                        if batch.count >= 8 {
                            continuation.yield(batch)
                            batch.removeAll(keepingCapacity: true)
                        }

                        enqueueNextCard()
                    }
                }

                if !batch.isEmpty {
                    continuation.yield(batch)
                }

                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private static func loadCard(for kanji: String) async throws -> KanjiCard {
        let detailURL = URL(string: "https://kanjiapi.dev/v1/kanji/\(kanji)")!
        let svgURL = URL(string: "https://raw.githubusercontent.com/KanjiVG/kanjivg/master/kanji/\(svgFileName(for: kanji))")!

        async let detailData = session.data(from: detailURL).0
        async let svgData = session.data(from: svgURL).0

        let detail = try JSONDecoder().decode(RemoteKanjiDetail.self, from: try await detailData)
        let svgText = String(decoding: try await svgData, as: UTF8.self)
        let strokes = SVGStrokeExtractor.strokes(from: svgText)

        guard !strokes.isEmpty else {
            throw RemoteKanjiError.missingStrokes
        }

        let translatedMeanings = RussianMeaningTranslator.translateLocally(detail.meanings)
        let loadedExamples = await loadExamples(for: kanji)

        return KanjiCard(
            kanji: detail.kanji,
            meanings: translatedMeanings,
            onyomi: detail.onReadings,
            kunyomi: detail.kunReadings,
            examples: loadedExamples,
            source: KanjiSource(
                name: "kanjiapi.dev + KanjiVG",
                file: svgFileName(for: kanji),
                license: "KanjiVG: Creative Commons Attribution-Share Alike 3.0"
            ),
            strokes: strokes,
            grade: detail.grade,
            jlpt: detail.jlpt
        )
    }

    private static func loadExamples(for kanji: String) async -> [KanjiExample] {
        do {
            let wordsURL = URL(string: "https://kanjiapi.dev/v1/words/\(kanji)")!
            let (data, _) = try await withTimeout(seconds: 3) {
                try await session.data(from: wordsURL)
            }
            let entries = try JSONDecoder().decode([RemoteWordEntry].self, from: data)
            var examples: [KanjiExample] = []

            for entry in entries.prefix(30) {
                let englishMeaning = entry.meanings.flatMap(\.glosses).prefix(2).joined(separator: ", ")
                let translatedMeaning = RussianMeaningTranslator.translateLocally([englishMeaning]).first ?? englishMeaning

                for variant in entry.variants where variant.written.contains(kanji) {
                    examples.append(KanjiExample(word: variant.written, reading: variant.pronounced, meaning: translatedMeaning))

                    if examples.count == 6 {
                        return examples
                    }
                }
            }

            return examples
        } catch {
            return []
        }
    }

    private static func withTimeout<Value>(seconds: UInt64, operation: @escaping () async throws -> Value) async throws -> Value {
        try await withThrowingTaskGroup(of: Value.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: seconds * 1_000_000_000)
                throw URLError(.timedOut)
            }

            guard let value = try await group.next() else {
                throw URLError(.timedOut)
            }

            group.cancelAll()
            return value
        }
    }

    private static func svgFileName(for kanji: String) -> String {
        guard let scalar = kanji.unicodeScalars.first else {
            return "00000.svg"
        }

        return String(format: "%05x.svg", scalar.value)
    }
}

private struct RemoteKanjiDetail: Decodable {
    let kanji: String
    let meanings: [String]
    let onReadings: [String]
    let kunReadings: [String]
    let grade: Int?
    let jlpt: Int?

    enum CodingKeys: String, CodingKey {
        case kanji
        case meanings
        case onReadings = "on_readings"
        case kunReadings = "kun_readings"
        case grade
        case jlpt
    }
}

private struct RemoteWordEntry: Decodable {
    let meanings: [RemoteWordMeaning]
    let variants: [RemoteWordVariant]
}

private struct RemoteWordMeaning: Decodable {
    let glosses: [String]
}

private struct RemoteWordVariant: Decodable {
    let pronounced: String
    let written: String
}

private enum RemoteKanjiError: Error {
    case missingStrokes
}

private enum RussianMeaningTranslator {
    private static let translations: [String: String] = [
        "above": "верх",
        "after": "после",
        "again": "снова",
        "air": "воздух",
        "animal": "животное",
        "art": "искусство",
        "back": "задняя сторона",
        "below": "ниже",
        "big": "большой",
        "birth": "рождение",
        "blue": "синий",
        "book": "книга",
        "child": "ребенок",
        "counter for long cylindrical things": "счетный суффикс для длинных цилиндрических предметов",
        "correct": "правильный",
        "day": "день",
        "decoration": "украшение",
        "descend": "спускаться",
        "down": "низ",
        "early": "ранний",
        "ear": "ухо",
        "eight": "восемь",
        "enter": "входить",
        "eye": "глаз",
        "fast": "быстрый",
        "female": "женщина",
        "fire": "огонь",
        "five": "пять",
        "figures": "символы",
        "flower": "цветок",
        "forest": "лес",
        "four": "четыре",
        "genuine": "настоящий",
        "give": "давать",
        "gold": "золото",
        "grass": "трава",
        "hand": "рука",
        "heaven": "небо",
        "hundred": "сто",
        "inferior": "низший",
        "inside": "внутри",
        "insert": "вставлять",
        "insect": "насекомое",
        "king": "король",
        "large": "большой",
        "left": "левый",
        "life": "жизнь",
        "literary radical (no. 67)": "литературный ключ N67",
        "literature": "литература",
        "little": "маленький",
        "low": "низкий",
        "magnate": "влиятельный человек",
        "main": "основной",
        "man": "мужчина",
        "moon": "луна",
        "mountain": "гора",
        "mouth": "рот",
        "name": "имя",
        "nine": "девять",
        "one": "один",
        "origin": "происхождение",
        "person": "человек",
        "plan": "план",
        "present": "настоящее время",
        "rain": "дождь",
        "red": "красный",
        "right": "правый",
        "real": "реальный",
        "river": "река",
        "rule": "правление",
        "school": "школа",
        "sentence": "предложение",
        "style": "стиль",
        "seven": "семь",
        "six": "шесть",
        "small": "маленький",
        "sound": "звук",
        "stone": "камень",
        "sun": "солнце",
        "ten": "десять",
        "three": "три",
        "tree": "дерево",
        "true": "истинный",
        "two": "два",
        "up": "верх",
        "village": "деревня",
        "water": "вода",
        "white": "белый",
        "year": "год"
    ]

    static func translateLocally(_ meanings: [String]) -> [String] {
        unique(dictionaryTranslation(for: meanings))
    }

    static func translate(_ meanings: [String]) async -> [String] {
        if let systemTranslation = try? await withTimeout(seconds: 4, operation: {
            try await translateWithSystem(meanings)
        }), !systemTranslation.isEmpty {
            return unique(systemTranslation)
        }

        return translateLocally(meanings)
    }

    private static func withTimeout<Value>(seconds: UInt64, operation: @escaping () async throws -> Value) async throws -> Value {
        try await withThrowingTaskGroup(of: Value.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: seconds * 1_000_000_000)
                throw URLError(.timedOut)
            }

            guard let value = try await group.next() else {
                throw URLError(.timedOut)
            }

            group.cancelAll()
            return value
        }
    }

    private static func translateWithSystem(_ meanings: [String]) async throws -> [String] {
        guard !meanings.isEmpty else {
            return []
        }

        let session = TranslationSession(
            installedSource: Locale.Language(identifier: "en"),
            target: Locale.Language(identifier: "ru")
        )
        let requests = meanings.map { TranslationSession.Request(sourceText: $0) }
        let responses = try await session.translations(from: requests)
        let translated = responses.map { $0.targetText.trimmingCharacters(in: .whitespacesAndNewlines) }

        guard translated.count == meanings.count else {
            return dictionaryTranslation(for: meanings)
        }

        return translated.enumerated().map { index, value in
            value.isEmpty || value.caseInsensitiveCompare(meanings[index]) == .orderedSame
                ? dictionaryTranslation(for: [meanings[index]]).first ?? value
                : value
        }
    }

    private static func dictionaryTranslation(for meanings: [String]) -> [String] {
        meanings.map { meaning in
            translations[meaning.lowercased()] ?? meaning
        }
    }

    private static func unique(_ meanings: [String]) -> [String] {
        Array(NSOrderedSet(array: meanings)).compactMap { $0 as? String }
    }
}

private enum SVGStrokeExtractor {
    static func strokes(from svgText: String) -> [KanjiStroke] {
        pathDataValues(in: svgText).enumerated().compactMap { index, pathData in
            guard let summary = summarize(pathData: pathData) else {
                return nil
            }

            return KanjiStroke(
                order: index + 1,
                pathData: pathData,
                start: [summary.start.x, summary.start.y],
                end: [summary.end.x, summary.end.y],
                axis: summary.axis
            )
        }
    }

    private static func pathDataValues(in svgText: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: #"<path[^>]*\sd=\"([^\"]+)\""#) else {
            return []
        }

        let range = NSRange(svgText.startIndex..<svgText.endIndex, in: svgText)
        return regex.matches(in: svgText, range: range).compactMap { match in
            guard let matchRange = Range(match.range(at: 1), in: svgText) else {
                return nil
            }

            return String(svgText[matchRange])
        }
    }

    private static func summarize(pathData: String) -> (start: CGPoint, end: CGPoint, axis: StrokeAxis)? {
        let points = points(in: pathData)
        guard let start = points.first, let end = points.last else {
            return nil
        }

        let box = points.dropFirst().reduce(CGRect(origin: start, size: .zero)) { box, point in
            box.union(CGRect(origin: point, size: .zero))
        }

        let axis: StrokeAxis
        if box.width > box.height * 1.5 {
            axis = .horizontal
        } else if box.height > box.width * 1.5 {
            axis = .vertical
        } else {
            axis = .corner
        }

        return (start, end, axis)
    }

    private static func points(in pathData: String) -> [CGPoint] {
        var points: [CGPoint] = []
        var current = CGPoint.zero

        for segment in segments(in: pathData) {
            let values = numbers(in: segment.arguments)

            switch segment.command {
            case "M", "L":
                for index in stride(from: 0, to: values.count - 1, by: 2) {
                    current = CGPoint(x: values[index], y: values[index + 1])
                    points.append(current)
                }
            case "m", "l":
                for index in stride(from: 0, to: values.count - 1, by: 2) {
                    current = CGPoint(x: current.x + values[index], y: current.y + values[index + 1])
                    points.append(current)
                }
            case "C":
                for index in stride(from: 0, to: values.count - 5, by: 6) {
                    points.append(CGPoint(x: values[index], y: values[index + 1]))
                    points.append(CGPoint(x: values[index + 2], y: values[index + 3]))
                    current = CGPoint(x: values[index + 4], y: values[index + 5])
                    points.append(current)
                }
            case "c":
                for index in stride(from: 0, to: values.count - 5, by: 6) {
                    points.append(CGPoint(x: current.x + values[index], y: current.y + values[index + 1]))
                    points.append(CGPoint(x: current.x + values[index + 2], y: current.y + values[index + 3]))
                    current = CGPoint(x: current.x + values[index + 4], y: current.y + values[index + 5])
                    points.append(current)
                }
            default:
                continue
            }
        }

        return points
    }

    private static func segments(in pathData: String) -> [(command: String, arguments: String)] {
        let characters = Array(pathData)
        var result: [(String, String)] = []
        var index = 0

        while index < characters.count {
            let command = characters[index]

            guard command.isLetter else {
                index += 1
                continue
            }

            let start = index + 1
            index = start

            while index < characters.count, !characters[index].isLetter {
                index += 1
            }

            result.append((String(command), String(characters[start..<index])))
        }

        return result
    }

    private static func numbers(in text: String) -> [Double] {
        var values: [Double] = []
        var token = ""
        var previous: Character?

        for character in text {
            let startsSignedNumber = (character == "-" || character == "+") && previous != nil && previous != "e" && previous != "E"

            if character == "," || character.isWhitespace || startsSignedNumber {
                appendToken(token, to: &values)
                token = startsSignedNumber ? String(character) : ""
            } else {
                token.append(character)
            }

            previous = character
        }

        appendToken(token, to: &values)
        return values
    }

    private static func appendToken(_ token: String, to values: inout [Double]) {
        guard !token.isEmpty, let value = Double(token) else {
            return
        }

        values.append(value)
    }
}
