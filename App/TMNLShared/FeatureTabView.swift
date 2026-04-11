import SwiftUI

struct FeatureTabView: View {
    @Bindable var store: MovieNightStore
    @State private var selectedSection: CompanionSection = .cast

    enum CompanionSection: String, CaseIterable {
        case cast = "Cast"
        case places = "Places"
        case context = "Context"
        case notes = "Notes"
    }

    var body: some View {
        NavigationStack {
            Group {
                if let movie = store.featuredMovie {
                    activeCompanion(for: movie)
                } else {
                    emptyState
                }
            }
            .background(AppTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("Feature")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private func activeCompanion(for movie: Movie) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxl) {
                movieHeader(movie)

                Picker("Section", selection: $selectedSection) {
                    ForEach(CompanionSection.allCases, id: \.self) { section in
                        Text(section.rawValue).tag(section)
                    }
                }
                .pickerStyle(.segmented)

                sectionContent(for: movie)
            }
            .padding(.horizontal, AppTheme.Spacing.xl)
            .padding(.vertical, AppTheme.Spacing.xl)
        }
    }

    private func movieHeader(_ movie: Movie) -> some View {
        HStack(spacing: AppTheme.Spacing.md) {
            AsyncImage(url: movie.posterURLValue) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                RoundedRectangle(cornerRadius: AppTheme.Radius.sm, style: .continuous)
                    .fill(AppTheme.Colors.surfaceRaised)
            }
            .frame(width: 52, height: 78)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.sm, style: .continuous))

            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                Text(movie.displayName)
                    .font(.headline)
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                HStack(spacing: AppTheme.Spacing.sm) {
                    if let runtime = movie.runtimeMinutes {
                        Text("\(runtime) min")
                    }
                    if let rating = movie.aggregateRating {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(AppTheme.Colors.accent)
                            Text(rating, format: .number.precision(.fractionLength(1)))
                        }
                    }
                }
                .font(.tmnlCaption)
                .foregroundStyle(AppTheme.Colors.textSecondary)
            }
        }
    }

    @ViewBuilder
    private func sectionContent(for movie: Movie) -> some View {
        switch selectedSection {
        case .cast:
            companionPlaceholder(
                icon: "person.crop.circle",
                title: "Cast",
                detail: "Familiar faces and where you know them from."
            )
        case .places:
            companionPlaceholder(
                icon: "mappin.circle",
                title: "Filming Locations",
                detail: "Where this film was made."
            )
        case .context:
            companionPlaceholder(
                icon: "text.book.closed",
                title: "Context",
                detail: "Spoiler-safe background on the film, director, and era."
            )
        case .notes:
            companionPlaceholder(
                icon: "note.text",
                title: "Notes",
                detail: "Jot down standout moments, lines, or reactions."
            )
        }
    }

    private func companionPlaceholder(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: AppTheme.Spacing.lg) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(AppTheme.Colors.textTertiary)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, AppTheme.Spacing.md)
    }

    private var emptyState: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Spacer()

            Image(systemName: "film")
                .font(.system(size: 48, weight: .thin))
                .foregroundStyle(AppTheme.Colors.textTertiary)

            VStack(spacing: AppTheme.Spacing.sm) {
                Text("No movie playing")
                    .font(.tmnlDisplay)
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                Text("Lock a pick from the Tonight tab to unlock your spoiler-safe companion.")
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
