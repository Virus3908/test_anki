import Foundation

@MainActor
@Observable
final class TranslationViewModel {
    var translationKanjiMeaningKeys: Set<String> = []
    var translationKanjiExampleKeys: Set<String> = []
    var translationWordKeys: Set<String> = []
    var translationWordExampleKeys: Set<String> = []
    var retranslationKanjiMeaningKeys: Set<String> = []
    var retranslationKanjiExampleKeys: Set<String> = []
    var retranslationWordKeys: Set<String> = []
    var retranslationWordExampleKeys: Set<String> = []
    var reloadingKanjiExampleKeys: Set<String> = []
    var reloadingWordExampleKeys: Set<String> = []
    var kanjiUsageExamples: [String: [KanjiExample]] = [:]
    var kanjiExampleTranslations: [String: [KanjiExample]] = [:]
    var wordMeaningTranslations: [String: String] = [:]
    var wordExampleTranslations: [String: [WordUsageExample]] = [:]
    var wordUsageExamples: [String: [WordUsageExample]] = [:]
    var loadingWordExampleKeys: Set<String> = []

    func loadSavedWordTranslations() {
        wordMeaningTranslations = TranslationRepository.loadWordTranslations()
        wordExampleTranslations = TranslationRepository.loadWordExampleTranslations()
    }
}
