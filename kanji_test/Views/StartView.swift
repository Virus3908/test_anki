import SwiftUI

struct StartView: View, StudyViewStyling {
    @Binding var practiceMode: PracticeMode
    let isLoading: Bool
    let onOpen: (StudyRoute) -> Void
    var practiceModeBinding: Binding<PracticeMode> { $practiceMode }
    var body: some View { startView() }
    var startSubtitle: String {
        switch practiceMode {
        case .kanji: return "Колоды кандзи с порядком черт и интервальным повторением."
        case .words: return "Слова из локального JMdict, сгруппированные в common-наборы."
        case .kana: return "Хирагана и катакана с просмотром карточек и тренировкой письма."
        }
    }
}
