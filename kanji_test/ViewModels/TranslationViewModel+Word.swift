import Foundation

extension TranslationViewModel {
    func displayedWordMeaning(for card: WordStudyCard, language: MeaningLanguage) -> String {
        guard language == .russian else { return card.meaning }
        return cached(.wordMeaning(card.id), source: [card.meaning])?.first ?? card.meaning
    }
    func translateWordMeaningIfNeeded(for card: WordStudyCard, language: MeaningLanguage) async {
        guard language == .russian else { return }
        let legacy = store.legacy.wordTranslations[card.id].map { [$0] }
        await translateAutomatically(.wordMeaning(card.id), texts: [card.meaning], source: [card.meaning], legacy: legacy)
    }
    func retranslateWordMeaning(_ card: WordStudyCard, language: MeaningLanguage) {
        guard language == .russian else { return }
        let key = TranslationBlockKey.wordMeaning(card.id)
        runManual(key, kind: .manualTranslation) { id in
            await self.translate(key, texts: [card.meaning], source: [card.meaning], manual: true, id: id)
        }
    }
}
