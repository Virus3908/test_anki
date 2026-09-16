import Foundation

extension TranslationViewModel {
    func displayedWordMeaning(for card: WordStudyCard, language: MeaningLanguage) -> String {
        switch language {
        case .russian:
            return translatedTexts[.wordMeaning(card.id)]?.first
                ?? RussianMeaningTranslator.translateLocally([card.meaning]).first
                ?? card.meaning
        case .english:
            return card.meaning
        }
    }

    func translateWordMeaningIfNeeded(for card: WordStudyCard, language: MeaningLanguage) async {
        let key = TranslationBlockKey.wordMeaning(card.id)
        guard language == .russian,
              translatedTexts[key] == nil,
              !automaticTranslationBlocks.contains(key),
              !manualTranslationBlocks.contains(key) else {
            return
        }

        automaticTranslationBlocks.insert(key)
        defer { automaticTranslationBlocks.remove(key) }
        let translatedMeaning = await RussianMeaningTranslator.translateAutomatically([card.meaning]).first ?? card.meaning
        guard translatedTexts[key] == nil,
              !manualTranslationBlocks.contains(key),
              translatedMeaning.trimmingCharacters(in: .whitespacesAndNewlines)
                .caseInsensitiveCompare(card.meaning.trimmingCharacters(in: .whitespacesAndNewlines)) != .orderedSame else {
            return
        }

        translatedTexts[key] = [translatedMeaning]
        TranslationRepository.saveWordTranslation(translatedMeaning, for: card.id)
    }

    func retranslateWordMeaning(_ card: WordStudyCard, language: MeaningLanguage) {
        let key = TranslationBlockKey.wordMeaning(card.id)
        guard language == .russian,
              !manualTranslationBlocks.contains(key) else {
            return
        }

        manualTranslationBlocks.insert(key)

        Task { @MainActor in
            defer { manualTranslationBlocks.remove(key) }
            let translatedMeaning = await RussianMeaningTranslator.translateManual([card.meaning]).first ?? card.meaning
            translatedTexts[key] = [translatedMeaning]
            TranslationRepository.saveWordTranslation(translatedMeaning, for: card.id)
        }
    }

}
