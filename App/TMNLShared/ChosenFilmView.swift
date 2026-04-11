import SwiftUI

struct ChosenFilmView: View {
    let movie: Movie
    @Bindable var store: MovieNightStore

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                backdropHeader
                detailContent
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.bottom, AppTheme.Spacing.section + 44)
        }
        .background(AppTheme.Colors.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private var backdropHeader: some View {
        ZStack(alignment: .bottomLeading) {
            if let backdropURL = movie.backdropURL.flatMap(URL.init(string:)) {
                AsyncImage(url: backdropURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    posterFallback
                }
                .frame(maxWidth: .infinity, maxHeight: 300)
                .clipped()
            } else {
                posterFallback
            }

            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.3),
                    .init(color: AppTheme.Colors.background.opacity(0.6), location: 0.7),
                    .init(color: AppTheme.Colors.background, location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .frame(maxWidth: .infinity)
        .frame(height: 300)
        .clipped()
    }

    private var posterFallback: some View {
        AsyncImage(url: movie.posterURLValue) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            Rectangle().fill(AppTheme.Colors.surface)
        }
        .frame(maxWidth: .infinity, maxHeight: 300)
        .clipped()
    }

    private var detailContent: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xxl) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                Text(movie.displayName)
                    .font(.tmnlDisplay)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                DetailMetadataFlow(spacing: AppTheme.Spacing.md) {
                    if let year = movie.year {
                        metadataPill(String(year))
                    }
                    if let runtime = movie.runtimeMinutes {
                        metadataPill("\(runtime) min")
                    }
                    if let rating = movie.aggregateRating {
                        Label {
                            Text(rating, format: .number.precision(.fractionLength(1)))
                        } icon: {
                            Image(systemName: "star.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(AppTheme.Colors.accent)
                        }
                    }
                    if let cert = movie.certification, !cert.isEmpty {
                        metadataPill(cert)
                    }
                }
                .font(.tmnlCaption)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

                if !movie.genres.isEmpty {
                    Text(movie.genres.joined(separator: " \u{00B7} "))
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Colors.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let tagline = movie.tagline, !tagline.isEmpty {
                    Text(tagline)
                        .font(.subheadline.italic())
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .padding(.top, AppTheme.Spacing.xs)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let overview = movie.overview, !overview.isEmpty {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    Text("Overview")
                        .font(.tmnlTitle)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    Text(overview)
                        .font(.body)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if movie.director != nil || !movie.cast.isEmpty {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    if let director = movie.director, !director.isEmpty {
                        detailFactRow(label: "Director", value: director)
                    }
                    if !movie.cast.isEmpty {
                        detailFactRow(label: "Cast", value: movie.cast.joined(separator: ", "))
                    }
                }
            }

            if let url = movie.appleTVSearchURL {
                Link(destination: url) {
                    Label("Start Watching", systemImage: "play.fill")
                        .font(.body.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppTheme.Spacing.md)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.Colors.accent)
                .controlSize(.large)
            }

            linksSection
        }
        .padding(.horizontal, AppTheme.Spacing.xl)
        .padding(.top, AppTheme.Spacing.sm)
        .padding(.bottom, AppTheme.Spacing.section)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func metadataPill(_ text: String) -> some View {
        Text(text)
    }

    private func detailFactRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textTertiary)
                .textCase(.uppercase)
            Text(value)
                .font(.subheadline)
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var linksSection: some View {
        VStack(spacing: 0) {
            if let url = movie.letterboxdURLValue {
                Link(destination: url) {
                    HStack {
                        Image(systemName: "text.book.closed")
                            .frame(width: 24)
                        Text("Letterboxd")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundStyle(AppTheme.Colors.textTertiary)
                    }
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .padding(.vertical, AppTheme.Spacing.md)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct DetailMetadataFlow: Layout {
    var spacing: CGFloat = 8

    struct Cache {
        var proposalWidth: CGFloat?
        var sizes: [CGSize] = []
        var frames: [CGRect] = []
        var size: CGSize = .zero
    }

    func makeCache(subviews: Subviews) -> Cache {
        Cache()
    }

    func updateCache(_ cache: inout Cache, subviews: Subviews) {
        cache.sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        cache.frames = []
        cache.size = .zero
        cache.proposalWidth = nil
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
        layoutResult(proposal: proposal, subviews: subviews, cache: &cache).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
        let result = layoutResult(proposal: proposal, subviews: subviews, cache: &cache)
        for (index, subview) in subviews.enumerated() {
            guard index < result.frames.count else { continue }
            let frame = result.frames[index]
            subview.place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func layoutResult(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> (size: CGSize, frames: [CGRect]) {
        if cache.sizes.count != subviews.count {
            cache.sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        }
        if cache.frames.isEmpty || cache.proposalWidth != proposal.width {
            let result = computeLayout(proposal: proposal, sizes: cache.sizes)
            cache.proposalWidth = proposal.width
            cache.size = result.size
            cache.frames = result.frames
        }
        return (cache.size, cache.frames)
    }

    private func computeLayout(proposal: ProposedViewSize, sizes: [CGSize]) -> (size: CGSize, frames: [CGRect]) {
        let maxWidth = proposal.width ?? .greatestFiniteMagnitude
        var frames: [CGRect] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var usedWidth: CGFloat = 0

        for size in sizes {
            let nextX = currentX == 0 ? size.width : currentX + spacing + size.width
            if nextX > maxWidth, currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            let frame = CGRect(origin: CGPoint(x: currentX, y: currentY), size: size)
            frames.append(frame)
            usedWidth = max(usedWidth, frame.maxX)
            lineHeight = max(lineHeight, size.height)
            currentX = frame.maxX + spacing
        }

        return (
            CGSize(width: usedWidth, height: currentY + lineHeight),
            frames
        )
    }
}
