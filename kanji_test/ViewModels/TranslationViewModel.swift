import Foundation

enum TranslationBlockKey: Hashable, Sendable {
    case kanjiMeaning(String)
    case kanjiExamples(String)
    case wordMeaning(String)
    case wordExamples(String)
}

@MainActor
@Observable
final class TranslationViewModel {
    var automaticTranslationBlocks: Set<TranslationBlockKey> = []
    var manualTranslationBlocks: Set<TranslationBlockKey> = []
    var automaticExampleLoadingBlocks: Set<TranslationBlockKey> = []
    var manualExampleReloadingBlocks: Set<TranslationBlockKey> = []
    var translatedTexts: [TranslationBlockKey: [String]] = [:]
    var kanjiUsageExamples: [String: [KanjiExample]] = [:]
    var kanjiExampleTranslations: [String: [KanjiExample]] = [:]
    var wordExampleTranslations: [String: [WordUsageExample]] = [:]
    var wordUsageExamples: [String: [WordUsageExample]] = [:]

    func loadSavedTranslations() {
        translatedTexts = TranslationRepository.loadWordTranslations().reduce(into: translatedTexts) { result, item in
            result[.wordMeaning(item.key)] = [item.value]
        }
        translatedTexts = TranslationRepository.loadKanjiMeaningTranslations().reduce(into: translatedTexts) { result, item in
            result[.kanjiMeaning(item.key)] = item.value
        }
        wordExampleTranslations = TranslationRepository.loadWordExampleTranslations()
    }

    func isAutomaticallyTranslating(_ key: TranslationBlockKey) -> Bool {
        automaticTranslationBlocks.contains(key)
    }

    func isManuallyTranslating(_ key: TranslationBlockKey) -> Bool {
        manualTranslationBlocks.contains(key)
    }

    func isAutomaticallyLoadingExamples(_ key: TranslationBlockKey) -> Bool {
        automaticExampleLoadingBlocks.contains(key)
    }

    func isManuallyReloadingExamples(_ key: TranslationBlockKey) -> Bool {
        manualExampleReloadingBlocks.contains(key)
    }
}
