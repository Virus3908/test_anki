import Foundation

extension TranslationViewModel {
    nonisolated static func grammarEnglishTexts(_ rule: GrammarRule) -> [String] {
        var seen = Set<String>()
        // Translate source English only. `displayedExplanation` may be an authored Russian
        // localization, so using it here could overwrite the text the lesson presents.
        let supplementTexts = rule.supplement.map { supplement in
            [supplement.summary] + supplement.structure + supplement.pitfalls + supplement.examples.map(\.en)
        } ?? []
        let texts = [rule.meaning, rule.formation, rule.notes ?? "", rule.teaching?.example.en ?? ""] + rule.examples.map(\.en)
            + supplementTexts
            + (rule.exercises ?? []).flatMap { [$0.cueEN ?? "", $0.explanationEN ?? ""] }
        return texts.filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    func displayedGrammarText(_ text: String, rule: GrammarRule, language: MeaningLanguage) -> String {
        guard language == .russian else { return text }
        let source = Self.grammarEnglishTexts(rule)
        guard let index = source.firstIndex(of: text),
              let translated = cached(.grammarContent(rule.id), source: source),
              translated.indices.contains(index) else { return text }
        return GrammarTranslationProjection.restore(translated[index], original: text)
    }

    func translateGrammarIfNeeded(_ rule: GrammarRule, language: MeaningLanguage) async {
        guard language == .russian else { return }
        let source = Self.grammarEnglishTexts(rule)
        await translateAutomatically(.grammarContent(rule.id),
            texts: source.map { GrammarTranslationProjection.protect($0).text }, source: source)
    }

    func retranslateGrammar(_ rule: GrammarRule) {
        let key = TranslationBlockKey.grammarContent(rule.id)
        let source = Self.grammarEnglishTexts(rule)
        runManual(key, kind: .manualTranslation) { id in
            await self.translate(key, texts: source.map { GrammarTranslationProjection.protect($0).text },
                                 source: source, manual: true, id: id)
        }
    }
}

/// Protect the exact Japanese grammar notation from the English-to-Russian model.
/// A missing/corrupt placeholder falls back to the original, never a changed formula.
nonisolated enum GrammarTranslationProjection {
    static func protect(_ source: String) -> (text: String, tokens: [(String, String)]) {
        guard let regex = try? NSRegularExpression(pattern: "[\\p{Han}\\p{Hiragana}\\p{Katakana}々〜]+") else {
            return (source, [])
        }
        let matches = regex.matches(in: source, range: NSRange(source.startIndex..., in: source))
        let tokens = matches.enumerated().compactMap { index, match -> (String, String)? in
            guard let range = Range(match.range, in: source) else { return nil }
            return ("JPG\(index)TOKEN", String(source[range]))
        }
        var text = source
        for (match, token) in zip(matches, tokens).reversed() {
            if let range = Range(match.range, in: text) { text.replaceSubrange(range, with: token.0) }
        }
        return (text, tokens)
    }
    static func restore(_ translated: String, original: String) -> String {
        var text = translated
        for (token, japanese) in protect(original).tokens {
            guard text.components(separatedBy: token).count == 2 else { return original }
            text = text.replacingOccurrences(of: token, with: japanese)
        }
        return text
    }
}
