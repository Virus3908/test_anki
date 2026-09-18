import Foundation

public enum AnkiTemplateRenderer {
    public struct RenderedCard: Sendable {
        public let html: String
        public let warnings: [String]
    }

    public static func render(card: AnkiCard, note: AnkiNote, type: AnkiNoteType, deckName: String, answer: Bool) -> RenderedCard {
        guard let template = type.isCloze ? type.templates.first : type.templates.first(where: { $0.ordinal == card.ordinal }) else {
            return .init(html: "<p>Шаблон отсутствует</p>", warnings: ["Не найден шаблон карточки."])
        }
        var fields = Dictionary(uniqueKeysWithValues: zip(type.fields, note.fields))
        fields["Tags"] = escape(note.tags.joined(separator: " "))
        fields["Type"] = escape(type.name)
        fields["Deck"] = escape(deckName)
        fields["Subdeck"] = escape(deckName.components(separatedBy: "::").last ?? deckName)
        fields["Card"] = escape(template.name)
        fields["CardFlag"] = String(card.scheduling["flags", default: 0] & 7)
        fields["c\(card.ordinal + 1)"] = "1"
        var warnings = Set<String>()
        func expand(_ template: String, back: Bool) -> String {
            var cursor = template.startIndex
            func section(until closing: String? = nil, depth: Int = 0) -> String {
                guard depth < 64 else { warnings.insert("Слишком глубокая вложенность шаблона."); return "" }
                var output = ""
                while cursor < template.endIndex {
                    guard let open = template.range(of: "{{", range: cursor..<template.endIndex),
                          let close = template.range(of: "}}", range: open.upperBound..<template.endIndex) else {
                        output += template[cursor...]; cursor = template.endIndex; break
                    }
                    output += template[cursor..<open.lowerBound]
                    let token = String(template[open.upperBound..<close.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                    cursor = close.upperBound
                    if token == "/" + (closing ?? "") { return output }
                    if token.hasPrefix("#") || token.hasPrefix("^") {
                        let name = String(token.dropFirst())
                        let inner = section(until: name, depth: depth + 1)
                        let exists = !(fields[name] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        if exists != token.hasPrefix("^") { output += inner }
                    } else if !token.hasPrefix("/") {
                        let parts = token.components(separatedBy: ":")
                        let name = parts.last ?? token
                        guard var value = fields[name] else {
                            warnings.insert("Неизвестное поле или команда: \(token)")
                            continue
                        }
                        for filter in parts.dropLast().reversed() {
                            switch filter {
                            case "cloze": value = cloze(value, ordinal: card.ordinal + 1, answer: back)
                            case "text": value = value.replacingOccurrences(of: "<[^>]*>", with: "", options: .regularExpression)
                            case "hint": value = "<details><summary>\(escape(name))</summary>\(value)</details>"
                            case "type": value = back ? value : "<input aria-label='Ответ' placeholder='Введите ответ'>"
                            case "furigana": value = ruby(value, mode: 0)
                            case "kana": value = ruby(value, mode: 1)
                            case "kanji": value = ruby(value, mode: 2)
                            default: warnings.insert("Фильтр \(filter) сохранён, но не поддерживается просмотром.")
                            }
                        }
                        output += value
                    }
                }
                return output
            }
            return section()
        }
        let front = expand(template.question, back: false)
        fields["FrontSide"] = front
        let body = sounds(answer ? expand(template.answer, back: true) : front)
        if body.range(of: "<script", options: .caseInsensitive) != nil {
            warnings.insert("JavaScript шаблона сохранён, но отключён при просмотре.")
        }
        if body.contains("[latex]") || body.contains("\\(") || body.contains("\\[") {
            warnings.insert("Формулы сохранены; для отображения нужны готовые изображения из экспорта.")
        }
        // Untrusted templates can use local media, but cannot execute scripts or contact the network.
        let html = """
        <!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src 'self' file: data:; media-src 'self' file:; style-src 'unsafe-inline' 'self' file:; font-src 'self' file: data:; script-src 'none'; connect-src 'none'; frame-src 'none'; form-action 'none'; base-uri 'none'">
        <style>\(type.css)</style>
        <style>body{margin:0;padding:16px;overflow-wrap:anywhere}img,video{max-width:100%;height:auto}audio{max-width:100%}.cloze{font-weight:bold;color:#3575b8}input{font-size:18px;max-width:90%}</style>
        </head><body class="card card\(card.ordinal + 1)">\(body)</body></html>
        """
        return .init(html: html, warnings: warnings.sorted())
    }

    public static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;").replacingOccurrences(of: "'", with: "&#39;")
    }

    private static func sounds(_ html: String) -> String {
        replacing(html, pattern: #"\[sound:([^\]]+)\]"#) { match, source in
            let name = source.substring(with: match.range(at: 1))
            guard AnkiPackageParser.isSafeFilename(name) else { return "" }
            let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
            let url = name.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
            return "<audio controls preload='none' src='\(escape(url))'></audio>"
        }
    }

    private static func ruby(_ text: String, mode: Int) -> String {
        replacing(text, pattern: #"([^\s<>\[\]]+)\[([^\[\]]+)\]"#) { match, source in
            let base = source.substring(with: match.range(at: 1))
            let reading = source.substring(with: match.range(at: 2))
            return mode == 1 ? reading : mode == 2 ? base : "<ruby>\(base)<rt>\(reading)</rt></ruby>"
        }
    }

    private static func cloze(_ value: String, ordinal: Int, answer: Bool, depth: Int = 0) -> String {
        guard depth < 64 else { return value }
        var result = "", cursor = value.startIndex
        while let start = value.range(of: "{{c", range: cursor..<value.endIndex),
              let separator = value.range(of: "::", range: start.upperBound..<value.endIndex),
              let number = Int(value[start.upperBound..<separator.lowerBound]) {
            result += value[cursor..<start.lowerBound]
            var position = separator.upperBound
            var nesting = 1
            var end: Range<String.Index>?
            while position < value.endIndex {
                let opening = value.range(of: "{{", range: position..<value.endIndex)
                guard let closing = value.range(of: "}}", range: position..<value.endIndex) else { break }
                if let opening, opening.lowerBound < closing.lowerBound { nesting += 1; position = opening.upperBound }
                else { nesting -= 1; position = closing.upperBound; if nesting == 0 { end = closing; break } }
            }
            guard let end else { result += value[start.lowerBound...]; return result }
            let inner = String(value[separator.upperBound..<end.lowerBound])
            // A hint separator belongs to this cloze only when outside nested clozes.
            var hintIndex: Range<String.Index>?
            var level = 0, i = inner.startIndex
            while i < inner.endIndex {
                if inner[i...].hasPrefix("{{") { level += 1; i = inner.index(i, offsetBy: 2) }
                else if inner[i...].hasPrefix("}}") { level -= 1; i = inner.index(i, offsetBy: 2) }
                else if level == 0 && inner[i...].hasPrefix("::") { hintIndex = i..<inner.index(i, offsetBy: 2); break }
                else { i = inner.index(after: i) }
            }
            let content = hintIndex.map { String(inner[..<$0.lowerBound]) } ?? inner
            let revealed = cloze(content, ordinal: ordinal, answer: answer, depth: depth + 1)
            if number == ordinal {
                let hint = hintIndex.map { String(inner[$0.upperBound...]) } ?? "…"
                result += "<span class='cloze'>\(answer ? revealed : "[\(hint)]")</span>"
            } else { result += revealed }
            cursor = end.upperBound
        }
        result += value[cursor...]
        return result
    }

    private static func replacing(_ text: String, pattern: String, replacement: (NSTextCheckingResult, NSString) -> String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let source = text as NSString
        var output = text
        for match in regex.matches(in: text, range: NSRange(location: 0, length: source.length)).reversed() {
            if let range = Range(match.range, in: output) { output.replaceSubrange(range, with: replacement(match, source)) }
        }
        return output
    }
}
