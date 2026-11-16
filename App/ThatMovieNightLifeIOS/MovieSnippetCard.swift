import AppIntents
import SwiftUI

/// Card Siri shows when it answers with a film (Siri AI Developer Preview, iOS 27.3+).
@available(iOS 27.3, *)
extension MovieEntity: SnippetRepresentableEntity {
    static var snippet: some EntitySnippetContent<Self> {
        CardSnippet(supportedFamilies: [.standard]) { movie, _ in
            MovieSnippetCard(movie: movie)
        }
    }
}

/// Static, text-only view: snippets are archived ahead of time, so it avoids async poster loading.
struct MovieSnippetCard: View {
    let movie: MovieEntity

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text("#\(movie.listNumber)")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.accent)
                Spacer()
                if let rating = movie.letterboxdRating {
                    Label(String(format: "%.1f", rating), systemImage: "star.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.accent)
                }
            }

            Text(movie.displayName)
                .font(.system(.title3, design: .serif).weight(.bold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .lineLimit(2)

            if !movie.subtitle.isEmpty {
                Text(movie.subtitle)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .lineLimit(1)
            }

            if let pitch = movie.whyPeopleLikeIt ?? movie.tagline ?? movie.overview {
                Text(pitch)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Colors.textPrimary.opacity(0.9))
                    .lineLimit(4)
            }

            if !movie.appealTags.isEmpty {
                Text(movie.appealTags.prefix(3).joined(separator: " · "))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppTheme.Colors.accent)
                    .lineLimit(1)
            }
        }
        .padding(AppTheme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Colors.surface)
        .environment(\.colorScheme, .dark)
    }
}
