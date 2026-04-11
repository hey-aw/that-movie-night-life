import SwiftUI

struct QuickModeChip: View {
    let title: String
    var isActive: Bool = false
    var action: (() -> Void)?

    var body: some View {
        if let action {
            Button(action: action) {
                chipLabel
            }
            .buttonStyle(.plain)
        } else {
            chipLabel
        }
    }

    private var chipLabel: some View {
        Text(title)
            .font(.caption.weight(.medium))
            .foregroundStyle(isActive ? AppTheme.Colors.accent : AppTheme.Colors.textTertiary)
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isActive ? AppTheme.Colors.accentSubtle : AppTheme.Colors.surface)
            )
            .overlay(
                Capsule()
                    .strokeBorder(
                        isActive ? AppTheme.Colors.accent.opacity(0.3) : Color.white.opacity(0.06),
                        lineWidth: 0.5
                    )
            )
    }
}
