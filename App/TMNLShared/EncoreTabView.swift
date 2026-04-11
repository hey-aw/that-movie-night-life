import SwiftUI

struct EncoreTabView: View {
    @Bindable var store: MovieNightStore
    @Binding var selectedTab: RootTab
    @State private var starRating: Int = 0
    @State private var quickTake: String = ""
    @FocusState private var isQuickTakeFocused: Bool

    var body: some View {
        NavigationStack {
            Group {
                if let movie = store.featuredMovie {
                    encoreContent(for: movie)
                } else {
                    emptyState
                }
            }
            .background(AppTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("Encore")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        isQuickTakeFocused = false
                    }
                }
            }
        }
    }

    private func encoreContent(for movie: Movie) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AppTheme.Spacing.xxl) {
                movieBanner(movie)

                VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                    Text("Rate It")
                        .font(.tmnlTitle)
                        .foregroundStyle(AppTheme.Colors.textPrimary)

                    StarRatingControl(rating: $starRating)
                }

                VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                    Text("Quick Take")
                        .font(.tmnlTitle)
                        .foregroundStyle(AppTheme.Colors.textPrimary)

                    TextField("What's your take?", text: $quickTake, axis: .vertical)
                        .lineLimit(3...6)
                        .focused($isQuickTakeFocused)
                        .font(.tmnlBody)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                        .padding(AppTheme.Spacing.md)
                        .background(AppTheme.Colors.surface, in: RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
                        )
                }

                actionsSection(movie)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.horizontal, AppTheme.Spacing.xl)
            .padding(.vertical, AppTheme.Spacing.xl)
            .padding(.bottom, AppTheme.Spacing.section + 44)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func movieBanner(_ movie: Movie) -> some View {
        HStack(spacing: AppTheme.Spacing.lg) {
            AsyncImage(url: movie.posterURLValue) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                RoundedRectangle(cornerRadius: AppTheme.Radius.sm, style: .continuous)
                    .fill(AppTheme.Colors.surfaceRaised)
            }
            .frame(width: 72, height: 108)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.sm, style: .continuous))

            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                Text("How was it?")
                    .font(.tmnlCaption)
                    .foregroundStyle(AppTheme.Colors.accent)
                    .textCase(.uppercase)

                Text(movie.displayName)
                    .font(.tmnlTitle)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func actionsSection(_ movie: Movie) -> some View {
        VStack(spacing: 0) {
            if let url = movie.letterboxdReviewURLValue {
                actionRow(icon: "arrow.up.forward.square", title: "Log to Letterboxd", url: url)
                Divider().overlay(Color.white.opacity(0.04))
            }
            actionButtonRow(icon: "sparkles", title: "Pick Another Movie") {
                isQuickTakeFocused = false
                selectedTab = .tonight
            }
            Divider().overlay(Color.white.opacity(0.04))
            actionButtonRow(icon: "books.vertical", title: "Adjust Filters or Imports") {
                isQuickTakeFocused = false
                selectedTab = .library
            }
        }
    }

    @ViewBuilder
    private func actionRow(icon: String, title: String, url: URL? = nil) -> some View {
        let content = HStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(AppTheme.Colors.accent)
                .frame(width: 24)

            Text(title)
                .font(.body)
                .foregroundStyle(AppTheme.Colors.textPrimary)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(AppTheme.Colors.textTertiary)
        }
        .padding(.vertical, AppTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)

        if let url {
            Link(destination: url) { content }
        } else {
            Button { } label: { content }
        }
    }

    private func actionButtonRow(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: AppTheme.Spacing.md) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(AppTheme.Colors.accent)
                    .frame(width: 24)

                Text(title)
                    .font(.body)
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.Colors.textTertiary)
            }
            .padding(.vertical, AppTheme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var emptyState: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Spacer()

            Image(systemName: "hands.clap")
                .font(.system(size: 48, weight: .thin))
                .foregroundStyle(AppTheme.Colors.textTertiary)

            VStack(spacing: AppTheme.Spacing.sm) {
                Text("The credits haven't rolled yet")
                    .font(.tmnlDisplay)
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                Text("After you watch tonight's pick, come back here to rate, react, and recommend.")
                    .font(.tmnlBody)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, AppTheme.Spacing.section)

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
