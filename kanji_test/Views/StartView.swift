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
    let ankiModel: AnkiLibraryViewModel
    @State var selectedSection: StartMenuSection = .kanji
    @State var hasSelectedInitialSection = false

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
