import Foundation

extension TranslationViewModel {
    func displayedWordMeaning(for card: WordStudyCard, language: MeaningLanguage) -> String {
        switch language {
        case .russian:
            return wordMeaningTranslations[card.id] ?? RussianMeaningTranslator.translateLocally([card.meaning]).first ?? card.meaning
        case .english:
            return card.meaning
        }
    }

    func translateWordMeaningIfNeeded(for card: WordStudyCard, language: MeaningLanguage) async {
        guard language == .russian, wordMeaningTranslations[card.id] == nil else {
            return
        }

        let translatedMeaning = await RussianMeaningTranslator.translate([card.meaning]).first ?? card.meaning
        guard wordMeaningTranslations[card.id] == nil else {
            return
        }

        wordMeaningTranslations[card.id] = translatedMeaning
        TranslationRepository.saveWordTranslation(translatedMeaning, for: card.id)
    }

    func retranslateWordMeaning(_ card: WordStudyCard, language: MeaningLanguage) {
        guard language == .russian, !retranslationWordKeys.contains(card.id) else {
            return
        }

        retranslationWordKeys.insert(card.id)

        Task { @MainActor in
            let translatedMeaning = await RussianMeaningTranslator.translate([card.meaning]).first ?? card.meaning
            wordMeaningTranslations[card.id] = translatedMeaning
            TranslationRepository.saveWordTranslation(translatedMeaning, for: card.id)
            retranslationWordKeys.remove(card.id)
        }
    }

}
