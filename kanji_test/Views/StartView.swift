import SwiftUI

enum StartMenuSection: String, CaseIterable, Identifiable {
    case kanji
    case words
    case kana
    case anki

    var id: Self { self }

    var title: String {
        switch self {
        case .kanji: "Кандзи"
        case .words: "Слова"
        case .kana: "Кана"
        case .anki: "Анки"
        }
    }

    var practiceMode: PracticeMode? {
        switch self {
        case .kanji: .kanji
        case .words: .words
        case .kana: .kana
        case .anki: .anki
        }
    }
}

struct StartView: View, StudyViewStyling {
    @Binding var practiceMode: PracticeMode
    let isLoading: Bool
    let onOpen: (StudyRoute) -> Void
    let settings: StudyPreferences
    let ankiModel: AnkiLibraryViewModel
    let coordinator: StudyCoordinator
    let translationState: TranslationViewModel
    let reviewStore: StudyProgressStore
    let onPractice: (PracticeSelection) -> Void
    @State var selectedSection: StartMenuSection = .kanji
    @State var hasSelectedInitialSection = false
    /// Открыт ли экран поиска (лупа рядом с заголовком).
    @State var isSearchPresented = false

    /// Что можно искать на активной вкладке: кандзи и слова — да,
    /// кана и Anki — пока нет.
    var searchScope: CardSearchViewModel.Scope? {
        switch selectedSection {
        case .kanji: .kanji
        case .words: .words
        case .kana, .anki: nil
        }
    }

    /// Лист поиска: вкладка кандзи ищет по всем кандзи, вкладка слов — по всем словам.
    func cardSearchSheet(scope: CardSearchViewModel.Scope) -> some View {
        CardSearchView(
            scope: scope,
            coordinator: coordinator,
            settings: settings,
            translationState: translationState,
            reviewStore: reviewStore,
            onPractice: onPractice
        )
    }

    var body: some View { startView() }
    var startSubtitle: String {
        switch selectedSection {
        case .kanji: return "Колоды кандзи с порядком черт и интервальным повторением."
        case .words: return "Слова из локального JMdict, сгруппированные в common-наборы."
        case .kana: return "Хирагана и катакана с просмотром карточек и тренировкой письма."
        case .anki: return "Импортируй колоды Anki с полями, картинками и звуком."
        }
    }
}
