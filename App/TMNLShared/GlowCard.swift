import SwiftUI

struct GlowCard<Content: View>: View {
    var highlighted: Bool = false
    var padding: CGFloat = AppTheme.Spacing.lg
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous)
                    .fill(AppTheme.Colors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous)
                    .strokeBorder(
                        highlighted ? AppTheme.Colors.accent.opacity(0.4) : Color.white.opacity(0.06),
                        lineWidth: 0.5
                    )
            )
    }
}
