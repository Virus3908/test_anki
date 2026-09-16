import Foundation
import SwiftUI

enum StrokeFeedbackSeverity {
    case info
    case good
    case minor
    case major
    case missing
    case extra

    var textColor: Color {
        switch self {
        case .info:
            return AppPalette.secondaryText
        case .good:
            return AppPalette.success
        case .minor:
            return AppPalette.warning
        case .major, .missing, .extra:
            return AppPalette.correction
        }
    }

    var actualStrokeColor: Color {
        switch self {
        case .good, .info:
            return AppPalette.ink
        case .minor:
            return AppPalette.warning
        case .major, .missing, .extra:
            return AppPalette.correction
        }
    }

    var expectedStrokeColor: Color {
        switch self {
        case .good, .info:
            return AppPalette.expectedCorrect
        case .minor:
            return AppPalette.expectedWarning
        case .major, .missing, .extra:
            return AppPalette.expectedCorrection
        }
    }

    var requiresCorrectionOverlay: Bool {
        switch self {
        case .minor, .major, .missing:
            return true
        case .info, .good, .extra:
            return false
        }
    }
}

struct StrokeFeedback: Identifiable {
    let id = UUID()
    let strokeIndex: Int?
    let severity: StrokeFeedbackSeverity
    let message: String
}
