import Foundation

enum WordDataLoader {
    private static let remotePageCount = 10
    private static let remoteBaseURL = URL(string: "https://www.manythings.org/japanese/words/goo/")!
    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 8
        configuration.timeoutIntervalForResource = 20
        return URLSession(configuration: configuration)
    }()

    static func loadWords() async -> [WordStudyCard] {
        await Task.yield()

        let entries = await loadDictionaryEntries()
        let kanjiCards = await loadKanjiCards(for: entries)
        let cardsByCharacter = Dictionary(kanjiCards.map { ($0.kanji, $0) }, uniquingKeysWith: { current, _ in current })
        let loadedWords = buildWords(from: entries, cardsByCharacter: cardsByCharacter)

        if !loadedWords.isEmpty {
            return loadedWords
        }

        return WordStudyCard.build(from: kanjiCards)
    }

    private static func loadDictionaryEntries() async -> [WordDictionaryEntry] {
        if let cachedEntries = loadCachedEntries(), !cachedEntries.isEmpty {
            return cachedEntries
        }

        if let remoteEntries = await loadRemoteEntries(), !remoteEntries.isEmpty {
            saveCachedEntries(remoteEntries)
            return remoteEntries
        }

        return loadBundledEntries()
    }

    private static func loadRemoteEntries() async -> [WordDictionaryEntry]? {
        do {
            var entries: [WordDictionaryEntry] = []
            var seen: Set<String> = []

            for page in 1...remotePageCount {
                let pageURL = remoteBaseURL.appendingPathComponent("\(page).html")
                let (data, response) = try await session.data(from: pageURL)
                if let httpResponse = response as? HTTPURLResponse, !(200..<300).contains(httpResponse.statusCode) {
                    throw URLError(.badServerResponse)
                }

                let html = String(decoding: data, as: UTF8.self)
                for entry in parseRemotePage(html) where seen.insert(entry.id).inserted {
                    entries.append(entry)
                }
            }

            return entries
        } catch {
            return nil
        }
    }

    private static func parseRemotePage(_ html: String) -> [WordDictionaryEntry] {
        let pattern = #"<dt>(.*?)<tt>\(\d+\)</tt></dt><dd>(.*?)<dd>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return []
        }

        let nsRange = NSRange(html.startIndex..<html.endIndex, in: html)
        return regex.matches(in: html, range: nsRange).compactMap { match in
            guard let headerRange = Range(match.range(at: 1), in: html),
                  let definitionRange = Range(match.range(at: 2), in: html) else {
                return nil
            }

            let header = String(html[headerRange])
            let definition = String(html[definitionRange])
            let reading = parseRemoteReading(from: header)
            let word = stripHTMLTags(from: header)
                .replacingOccurrences(of: #"\[[^\]]+\]"#, with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let meaning = cleanedDefinition(from: stripHTMLTags(from: definition))

            guard isUsableJapaneseWord(word), !meaning.isEmpty else {
                return nil
            }

            return WordDictionaryEntry(
                word: word,
                reading: reading ?? word,
                meaning: meaning
            )
        }
    }

    private static func parseRemoteReading(from header: String) -> String? {
        guard let range = header.range(of: #"<i>\[[^\]]+\]</i>"#, options: .regularExpression) else {
            return nil
        }

        return stripHTMLTags(from: String(header[range]))
            .trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func stripHTMLTags(from html: String) -> String {
        html
            .replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
    }

    private static func cleanedDefinition(from line: String) -> String {
        var result = line
            .replacingOccurrences(of: #"\(P\)"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"^\([^)]*\)\s*"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #";\s*\([^)]*\)"#, with: "; ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if result.count > 180 {
            let endIndex = result.index(result.startIndex, offsetBy: 180)
            result = String(result[..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return result
    }

    private static func loadKanjiCards(for entries: [WordDictionaryEntry]) async -> [KanjiCard] {
        var sourceCards = loadSourceKanjiCards()
        let knownCharacters = Set(sourceCards.map(\.kanji))
        let missingCharacters = Array(requiredKanjiCharacters(in: entries).subtracting(knownCharacters)).sorted()

        guard !missingCharacters.isEmpty else {
            return sourceCards
        }

        do {
            let remoteCards = try await RemoteKanjiProvider.loadCards(for: missingCharacters)
            if !remoteCards.isEmpty {
                KanjiDataLoader.cacheCards(remoteCards)
                sourceCards.append(contentsOf: remoteCards)
            }
        } catch {
            assertionFailure("Failed to load kanji for word deck: \(error)")
        }

        return sourceCards
    }

    private static func loadSourceKanjiCards() -> [KanjiCard] {
        let availableCards = KanjiDataLoader.loadAvailableCards(deck: .all)
        if !availableCards.isEmpty {
            return availableCards
        }

        let masterCards = KanjiDataLoader.loadBundledMasterCards()
        return masterCards.isEmpty ? KanjiDataLoader.loadLocalCards() : masterCards
    }

    private static func requiredKanjiCharacters(in entries: [WordDictionaryEntry]) -> Set<String> {
        Set(entries.flatMap { entry in
            entry.word.map(String.init).filter(isKanji)
        })
    }

    private static func loadBundledEntries() -> [WordDictionaryEntry] {
        guard let url = Bundle.main.url(forResource: "word-data", withExtension: "json") else {
            assertionFailure("word-data.json is missing from the app bundle.")
            return WordSeed.common
        }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([WordDictionaryEntry].self, from: data)
        } catch {
            assertionFailure("Failed to decode word-data.json: \(error)")
            return WordSeed.common
        }
    }

    private static func buildWords(
        from entries: [WordDictionaryEntry],
        cardsByCharacter: [String: KanjiCard]
    ) -> [WordStudyCard] {
        var seen: Set<String> = []

        return entries.compactMap { entry in
            guard seen.insert(entry.word).inserted else {
                return nil
            }

            let characterCards = entry.word.map(String.init).compactMap { character -> KanjiCard? in
                if let card = cardsByCharacter[character] {
                    return card
                }

                guard isKana(character) else {
                    return nil
                }

                return kanaCard(for: character)
            }

            guard characterCards.count == entry.word.count else {
                return nil
            }

            return WordStudyCard(
                word: entry.word,
                reading: entry.reading,
                meaning: entry.meaning,
                kanjiCards: characterCards
            )
        }
    }

    private static func loadCachedEntries() -> [WordDictionaryEntry]? {
        let url = cacheURL()
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([WordDictionaryEntry].self, from: data)
        } catch {
            return nil
        }
    }

    private static func saveCachedEntries(_ entries: [WordDictionaryEntry]) {
        do {
            let url = cacheURL()
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(entries)
            try data.write(to: url, options: .atomic)
        } catch {
            assertionFailure("Failed to cache remote word frequency entries: \(error)")
        }
    }

    private static func cacheURL() -> URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return caches
            .appendingPathComponent("WordFrequencyCache", isDirectory: true)
            .appendingPathComponent("goo-blog-frequency.json")
    }

    private static func kanaCard(for character: String) -> KanjiCard {
        KanjiCard(
            kanji: character,
            meanings: [],
            onyomi: [],
            kunyomi: [],
            examples: [],
            source: KanjiSource(name: "Kana", file: "local-kana", license: "App data"),
            strokes: KanaStrokePresets.strokes(for: character),
            translationState: "ru-system"
        )
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

    nonisolated private static func isUsableJapaneseWord(_ text: String) -> Bool {
        text.allSatisfy { character in
            let value = character.unicodeScalars.first.map { Int($0.value) } ?? 0
            return (0x3040...0x309F).contains(value)
                || (0x30A0...0x30FF).contains(value)
                || (0x4E00...0x9FFF).contains(value)
        }
    }
}
