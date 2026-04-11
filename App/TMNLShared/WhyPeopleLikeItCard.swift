import SwiftUI

struct WhyPeopleLikeItCard: View {
    let appeal: MovieAppealSummary?

    @State private var isExpanded = false

    var body: some View {
        GlowCard(highlighted: appeal?.confidence == .high) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                header

                if let appeal {
                    summaryBody(appeal)
                } else {
                    unavailableBody
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard appeal?.isExpandable == true else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
            Label("Why People Like It", systemImage: "sparkles")
                .font(.tmnlTitle)
                .foregroundStyle(AppTheme.Colors.textPrimary)

            Spacer(minLength: AppTheme.Spacing.sm)

            if let confidenceLabel {
                confidenceChip(confidenceLabel)
            }

            if appeal?.isExpandable == true {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textTertiary)
            }
        }
    }

    private func summaryBody(_ appeal: MovieAppealSummary) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
            Text(appeal.summary)
                .font(.body)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if !appeal.collapsedAppealTags.isEmpty {
                DetailMetadataFlow(spacing: AppTheme.Spacing.sm) {
                    ForEach(appeal.collapsedAppealTags, id: \.self) { tag in
                        Text(tag)
                            .font(.tmnlCaption)
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                            .padding(.horizontal, AppTheme.Spacing.md)
                            .padding(.vertical, AppTheme.Spacing.sm)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(AppTheme.Colors.accentSubtle)
                            )
                            .overlay(
                                Capsule(style: .continuous)
                                    .strokeBorder(AppTheme.Colors.accent.opacity(0.2), lineWidth: 0.5)
                            )
                    }
                }
            }

            if isExpanded, appeal.isExpandable {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                    Divider()
                        .overlay(Color.white.opacity(0.06))

                    if let goodPickIf = appeal.goodPickIf, !goodPickIf.isEmpty {
                        guidanceRow(title: "Good pick if", value: goodPickIf)
                    }

                    if let maybeSkipIf = appeal.maybeSkipIf, !maybeSkipIf.isEmpty {
                        guidanceRow(title: "Maybe skip if", value: maybeSkipIf)
                    }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private var unavailableBody: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("No quick read on this one yet.")
                .font(.body.weight(.medium))
                .foregroundStyle(AppTheme.Colors.textPrimary)

            Text("You can still use ratings, genres, and companion info to help decide.")
                .font(.body)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func guidanceRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            Text(title)
                .font(.tmnlCaption)
                .foregroundStyle(AppTheme.Colors.accent)
                .textCase(.uppercase)

            Text(value)
                .font(.body)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func confidenceChip(_ label: String) -> some View {
        Text(label)
            .font(.tmnlMono)
            .foregroundStyle(AppTheme.Colors.accent)
            .padding(.horizontal, AppTheme.Spacing.sm)
            .padding(.vertical, AppTheme.Spacing.xs)
            .background(
                Capsule(style: .continuous)
                    .fill(AppTheme.Colors.accentSubtle)
            )
    }

    private var confidenceLabel: String? {
        switch appeal?.confidence {
        case .high:
            return "High Confidence"
        case .medium:
            return "Medium Confidence"
        case .low:
            return "Low Confidence"
        case nil:
            return nil
        }
    }
}
