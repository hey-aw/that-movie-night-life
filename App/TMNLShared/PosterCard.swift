import SwiftUI

struct PosterCard: View {
    let movie: Movie
    var width: CGFloat = 140
    var showMetadata: Bool = true
    var onTap: (() -> Void)?

    private var height: CGFloat { round(width * 1.5) }

    var body: some View {
        Button(action: { onTap?() }) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                posterImage
                if showMetadata {
                    metadataBlock
                }
            }
            .frame(width: width)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(movie.displayName)
    }

    private var posterImage: some View {
        AsyncImage(url: movie.posterURLValue) { image in
            image
                .resizable()
                .scaledToFill()
        } placeholder: {
            ZStack {
                RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous)
                    .fill(AppTheme.Colors.surface)
                ProgressView()
                    .tint(AppTheme.Colors.textTertiary)
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous))
    }

    private var metadataBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(movie.title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .lineLimit(2)

            HStack(spacing: AppTheme.Spacing.sm) {
                if let year = movie.year {
                    Text(String(year))
                }
                if let runtime = movie.runtimeMinutes {
                    Text("\(runtime)m")
                }
                if let rating = movie.aggregateRating {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(AppTheme.Colors.accent)
                        Text(rating, format: .number.precision(.fractionLength(1)))
                    }
                }
            }
            .font(.caption)
            .foregroundStyle(AppTheme.Colors.textTertiary)
        }
    }
}
