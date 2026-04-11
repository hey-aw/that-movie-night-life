import SwiftUI

enum AppTheme {
    enum Colors {
        static let background = Color.black
        static let surface = Color(white: 0.09)
        static let surfaceRaised = Color(white: 0.14)

        static let accent = Color(red: 0.91, green: 0.72, blue: 0.22)
        static let accentSubtle = accent.opacity(0.12)

        static let textPrimary = Color.white
        static let textSecondary = Color(white: 0.55)
        static let textTertiary = Color(white: 0.32)

        static let danger = Color.red
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let section: CGFloat = 32
    }

    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
    }
}

extension Font {
    static let tmnlDisplay = Font.system(size: 28, weight: .bold, design: .serif)
    static let tmnlTitle = Font.title3.bold()
    static let tmnlBody = Font.body
    static let tmnlCaption = Font.caption.weight(.medium)
    static let tmnlMono = Font.system(.caption, design: .monospaced).weight(.semibold)
}

struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
