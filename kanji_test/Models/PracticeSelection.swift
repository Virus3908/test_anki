import Foundation

enum PracticeSelection {
    case kanji([KanjiCard], guided: Bool)
    case words([WordStudyCard], guided: Bool)
    case kana(KanaDeck, [KanaStudyCard], guided: Bool)
}

