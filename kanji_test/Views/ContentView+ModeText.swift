import SwiftUI

extension ContentView {
    var trainingTitle: String {
        switch practiceMode {
        case .kanji:
            return selectedDeck.title
        case .words:
            return "Слова: \(selectedWordDeck.title)"
        case .kana:
            return selectedKanaDeck.title
        }
    }

    var startSubtitle: String {
        switch practiceMode {
        case .kanji:
            return "Первый запуск скачает весь пакет из kanjiapi.dev и сохранит его в кэш."
        case .words:
            return "Слова берутся локально из JMdict и группируются common-наборами."
        case .kana:
            return "Хирагана и катакана с просмотром карточек и тренировкой письма."
        }
    }
}
