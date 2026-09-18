import Foundation
import SwiftSoup

public enum AnkiContentParser {
    /// Replaces text nodes only: translations cannot become HTML, change media paths or run scripts.
    public static func replacingTexts(in html: String, translations: [String: String]) throws -> String {
        let document = try SwiftSoup.parse(html)
        func visit(_ node: Node, depth: Int) {
            guard depth < 128 else { return }
            if let text = node as? TextNode {
                let raw = text.getWholeText()
                let normalized = raw.replacingOccurrences(of: #"[\t\r\n ]+"#, with: " ", options: .regularExpression)
                if let translated = translations[raw] ?? translations[normalized] { _ = text.text(translated) }
            } else if let element = node as? Element {
                guard !["script", "style"].contains(element.tagName()) else { return }
                for child in element.getChildNodes() { visit(child, depth: depth + 1) }
            }
        }
        if let body = document.body() { visit(body, depth: 0) }
        return try document.outerHtml()
    }
    public static func parsePreservingSource(_ html: String) -> AnkiContent {
        do { return try parse(html) }
        catch { return .init(blocks: [], warnings: ["Не удалось разобрать разметку. Оригинал доступен в режиме «Шаблон Anki»."]) }
    }
    /// DOM parsing decodes entities, handles malformed HTML, and keeps media in reading order.
    public static func parse(_ html: String) throws -> AnkiContent {
        let document = try SwiftSoup.parse(html)
        guard let body = document.body() else { return .init(blocks: [], warnings: []) }
        var builder = Builder()
        // Common templates hide supplementary fields with class selectors. Respect those rules
        // so a native question does not accidentally expose a hidden answer.
        let styles = try document.select("style").array().map { try $0.html() }.joined(separator: "\n")
        let rules = try NSRegularExpression(pattern: #"([^{}]+)\{([^{}]*)\}"#)
        let source = styles as NSString
        for match in rules.matches(in: styles, range: NSRange(location: 0, length: source.length)) {
            let declarations = source.substring(with: match.range(at: 2)).lowercased()
                .replacingOccurrences(of: #"\s+"#, with: "", options: .regularExpression)
            guard declarations.contains("display:none") || declarations.contains("visibility:hidden") else { continue }
            let selector = source.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
            do {
                for hidden in try document.select(selector).array() { try hidden.attr("hidden", "") }
            } catch { builder.warnings.insert("Часть правил видимости доступна только в шаблоне Anki.") }
        }
        try builder.visit(body, style: AnkiTextRun(text: ""), depth: 0)
        builder.flush()
        return .init(blocks: builder.blocks, warnings: builder.warnings.sorted())
    }

    private struct Builder {
        var blocks: [AnkiContentBlock] = []
        var runs: [AnkiTextRun] = []
        var warnings = Set<String>()
        var visited = 0

        mutating func flush() {
            if !runs.map(\.text).joined().trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                blocks.append(.init(kind: .text, runs: runs))
            }
            runs = []
        }

        mutating func append(_ text: String, style: AnkiTextRun) {
            var run = style
            run.text = text
            if !text.isEmpty { runs.append(run) }
        }

        mutating func media(_ source: String, kind: AnkiContentBlock.Kind, label: String = "") {
            flush()
            // Anki's [sound:] names are literal; HTML URLs are decoded before calling this method.
            guard AnkiPackageParser.isSafeFilename(source), !source.hasPrefix("//") else {
                warnings.insert("Встроенное или внешнее медиа не отображается в обычном виде.")
                if !label.isEmpty { append(label, style: AnkiTextRun(text: "")); flush() }
                return
            }
            blocks.append(.init(kind: kind, filename: source, label: label))
        }

        mutating func text(_ value: String, style: AnkiTextRun, preserveWhitespace: Bool) {
            let source = value as NSString
            let regex = try? NSRegularExpression(pattern: #"\[sound:([^\]]+)\]"#)
            let matches = regex?.matches(in: value, range: NSRange(location: 0, length: source.length)) ?? []
            var offset = 0
            func normalized(_ string: String) -> String {
                preserveWhitespace ? string : string.replacingOccurrences(of: #"[\t\r\n ]+"#, with: " ", options: .regularExpression)
            }
            for match in matches {
                append(normalized(source.substring(with: NSRange(location: offset, length: match.range.location - offset))), style: style)
                media(source.substring(with: match.range(at: 1)), kind: .audio)
                offset = NSMaxRange(match.range)
            }
            append(normalized(source.substring(from: offset)), style: style)
        }

        mutating func visit(_ node: Node, style: AnkiTextRun, depth: Int, preserveWhitespace: Bool = false) throws {
            visited += 1
            guard depth < 128, visited < 100_000 else { throw AnkiImportError.invalid("слишком сложная разметка поля") }
            if let textNode = node as? TextNode {
                text(textNode.getWholeText(), style: style, preserveWhitespace: preserveWhitespace)
                return
            }
            guard let element = node as? Element else { return }
            let tag = element.tagName().lowercased()
            if ["script", "style", "iframe", "object", "embed"].contains(tag) {
                warnings.insert("Скрипты и встроенные объекты не отображаются в обычном виде.")
                return
            }
            if element.hasAttr("hidden") { return }
            var nextStyle = style
            if ["b", "strong", "h1", "h2", "h3", "h4", "h5", "h6", "th"].contains(tag) { nextStyle.bold = true }
            if ["i", "em"].contains(tag) { nextStyle.italic = true }
            if tag == "u" { nextStyle.underline = true }
            if ["s", "strike", "del"].contains(tag) { nextStyle.strikethrough = true }
            if element.hasClass("cloze") { nextStyle.cloze = true }
            let inlineCSS = try element.attr("style").lowercased().replacingOccurrences(of: " ", with: "")
            if inlineCSS.contains("display:none") || inlineCSS.contains("visibility:hidden") { return }
            if inlineCSS.contains("font-weight:bold") || inlineCSS.contains("font-weight:700") { nextStyle.bold = true }
            if inlineCSS.contains("font-style:italic") { nextStyle.italic = true }
            switch tag {
            case "br": append("\n", style: nextStyle); return
            case "hr": flush(); blocks.append(.init(kind: .divider)); return
            case "img", "audio", "video":
                var source = try element.attr("src")
                if source.isEmpty { source = try element.select("source").first()?.attr("src") ?? "" }
                let kind: AnkiContentBlock.Kind = tag == "img" ? .image : tag == "audio" ? .audio : .video
                media(source.removingPercentEncoding ?? source, kind: kind, label: try element.attr("alt"))
                return
            case "input":
                flush(); blocks.append(.init(kind: .input, label: try element.attr("placeholder"))); return
            case "details":
                flush()
                var nested = Builder()
                for child in element.getChildNodes() {
                    if let child = child as? Element, child.tagName() == "summary" { continue }
                    try nested.visit(child, style: nextStyle, depth: depth + 1)
                }
                nested.flush()
                warnings.formUnion(nested.warnings)
                let label = try element.select("summary").first()?.text() ?? "Подсказка"
                blocks.append(.init(kind: .hint, label: label, children: nested.blocks))
                return
            case "ruby":
                for child in element.getChildNodes() {
                    if let child = child as? Element, ["rt", "rp"].contains(child.tagName()) { continue }
                    try visit(child, style: nextStyle, depth: depth + 1)
                }
                let reading = try element.select("rt").text()
                if !reading.isEmpty { append(" (\(reading))", style: nextStyle) }
                return
            default: break
            }
            let paragraph = ["p", "div", "section", "article", "blockquote", "li", "ul", "ol", "h1", "h2", "h3", "h4", "h5", "h6", "pre", "tr"].contains(tag)
            if paragraph { flush() }
            if tag == "li" { append("• ", style: nextStyle) }
            if tag == "td" || tag == "th", !runs.isEmpty { append("  |  ", style: nextStyle) }
            for child in element.getChildNodes() {
                try visit(child, style: nextStyle, depth: depth + 1, preserveWhitespace: preserveWhitespace || tag == "pre")
            }
            if paragraph { flush() }
        }
    }
}

public extension AnkiCollection {
    /// Existing collections gain the native projection without replacing their original fields.
    @discardableResult
    mutating func prepareNativeFields() -> Bool {
        var changed = false
        for index in notes.indices where notes[index].parsedFields == nil {
            notes[index].parsedFields = notes[index].fields.map(AnkiContentParser.parsePreservingSource)
            changed = true
        }
        return changed
    }
}
