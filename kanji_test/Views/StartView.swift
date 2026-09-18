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
        case .anki: nil
        }
    }
}

struct StartView: View, StudyViewStyling {
    @Binding var practiceMode: PracticeMode
    let isLoading: Bool
    let onOpen: (StudyRoute) -> Void
    @State var selectedSection: StartMenuSection = .kanji

    var body: some View { startView() }
    var startSubtitle: String {
        switch selectedSection {
        case .kanji: return "Колоды кандзи с порядком черт и интервальным повторением."
        case .words: return "Слова из локального JMdict, сгруппированные в common-наборы."
        case .kana: return "Хирагана и катакана с просмотром карточек и тренировкой письма."
        case .anki: return "Здесь появятся импортированные колоды Anki."
        }
    }
}
