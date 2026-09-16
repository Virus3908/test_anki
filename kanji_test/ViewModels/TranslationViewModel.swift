import Foundation

@MainActor
@Observable
final class TranslationViewModel {
    var retranslationKanjiMeaningKeys: Set<String> = []
    var retranslationKanjiExampleKeys: Set<String> = []
    var retranslationWordKeys: Set<String> = []
    var retranslationWordExampleKeys: Set<String> = []
    var wordMeaningTranslations: [String: String] = [:]
    var wordExampleTranslations: [String: [WordUsageExample]] = [:]
    var wordUsageExamples: [String: [WordUsageExample]] = [:]
    var loadingWordExampleKeys: Set<String> = []

    func loadSavedWordTranslations() {
        wordMeaningTranslations = TranslationRepository.loadWordTranslations()
        wordExampleTranslations = TranslationRepository.loadWordExampleTranslations()
    }
}
