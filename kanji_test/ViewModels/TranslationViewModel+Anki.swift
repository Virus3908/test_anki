import Foundation
import NaturalLanguage
import AnkiImport

extension TranslationViewModel {
    nonisolated static func ankiEnglishTexts(in content: AnkiContent) -> [String] {
        var seen = Set<String>()
        return content.textRuns.filter { text in
            guard seen.insert(text).inserted, text.unicodeScalars.contains(where: { CharacterSet.letters.contains($0) }) else { return false }
            let recognizer = NLLanguageRecognizer()
            recognizer.processString(text)
            return recognizer.dominantLanguage == .english
        }
    }

    func translateAnkiIfNeeded(key: TranslationBlockKey, texts: [String], language: MeaningLanguage) async {
        guard language == .russian, !texts.isEmpty else { return }
        await translateAutomatically(key, texts: texts, source: texts)
    }

    func retranslateAnki(key: TranslationBlockKey, texts: [String]) {
        guard !texts.isEmpty else { return }
        runManual(key, kind: .manualTranslation) { id in
            await self.translate(key, texts: texts, source: texts, manual: true, id: id)
        }
    }
}
