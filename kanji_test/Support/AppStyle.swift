import SwiftUI
import UIKit

let canonicalSize: CGFloat = 109

enum AppPalette {
    private static func dynamic(
        light: (CGFloat, CGFloat, CGFloat),
        dark: (CGFloat, CGFloat, CGFloat)
    ) -> Color {
        Color(UIColor { traits in
            let rgb = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)
        })
    }

    static let background = dynamic(
        light: (0.89, 0.92, 0.91),
        dark: (0.11, 0.13, 0.13)
    )
    static let surface = dynamic(
        light: (1.00, 0.99, 0.96),
        dark: (0.16, 0.19, 0.19)
    )
    static let text = dynamic(
        light: (0.12, 0.11, 0.09),
        dark: (0.93, 0.93, 0.91)
    )
    static let secondaryText = dynamic(
        light: (0.36, 0.33, 0.28),
        dark: (0.72, 0.72, 0.68)
    )
    static let mutedText = dynamic(
        light: (0.54, 0.50, 0.43),
        dark: (0.55, 0.55, 0.51)
    )
    static let border = dynamic(
        light: (0.58, 0.55, 0.48),
        dark: (0.36, 0.36, 0.34)
    )
    static let ink = dynamic(
        light: (0.12, 0.16, 0.17),
        dark: (0.90, 0.94, 0.94)
    )
    static let accent = dynamic(
        light: (0.14, 0.36, 0.39),
        dark: (0.35, 0.62, 0.65)
    )
    static let correction = dynamic(
        light: (0.74, 0.12, 0.14),
        dark: (0.87, 0.42, 0.44)
    )
    static let warning = dynamic(
        light: (0.78, 0.58, 0.10),
        dark: (0.84, 0.64, 0.30)
    )
    static let newCard = dynamic(
        light: (0.30, 0.44, 0.72),
        dark: (0.46, 0.60, 0.88)
    )
    static let expectedCorrection = dynamic(
        light: (1.00, 0.35, 0.32),
        dark: (1.00, 0.42, 0.38)
    )
    static let expectedWarning = dynamic(
        light: (0.96, 0.74, 0.22),
        dark: (0.96, 0.76, 0.30)
    )
    static let expectedCorrect = dynamic(
        light: (0.50, 0.52, 0.56),
        dark: (0.62, 0.64, 0.66)
    )
    static let success = dynamic(
        light: (0.18, 0.52, 0.24),
        dark: (0.42, 0.70, 0.48)
    )
}
