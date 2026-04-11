import SwiftUI

struct TonightTabView: View {
    @Bindable var store: MovieNightStore

    @State private var isStartNightPresented = false
    @State private var isFilterSheetPresented = false
    @State private var isImportPickerPresented = false
    @State private var selectedMovie: Movie?

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: AppTheme.Spacing.section) {
                    TonightHeroSection(
                        movie: store.featuredMovie,
                        hasCurrentSelection: store.hasCurrentSelection,
                        canSpin: store.canSpin,
                        startNight: { isStartNightPresented = true },
                        viewSelection: { movie in selectedMovie = movie },
                        spin: store.spin
                    )
                    TonightReelSection(
                        reelDigits: store.reelDigits,
                        lockedDigitCount: store.lockedDigitCount,
                        filterPrefix: store.filterPrefix,
                        narrowedCandidateCount: store.narrowedCandidateCount,
                        animationCaption: store.animationCaption,
                        hasCurrentSelection: store.hasCurrentSelection,
                        canSpin: store.canSpin,
                        currentMovie: store.currentMovie,
                        viewSelection: { movie in selectedMovie = movie },
                        spin: store.spin
                    )
                    TonightFiltersSection(
                        snapshot: TonightFilterSnapshot.build(
                            filterSettings: store.session.filterSettings,
                            catalogCount: store.catalog.count,
                            eligibleCount: store.eligibleMovies.count,
                            watchedCount: store.session.watchedSlugs.count,
                            historySections: store.historySections
                        )
                    )
                    TonightHistorySection(historySections: store.historySections)
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(.horizontal, AppTheme.Spacing.xl)
                .padding(.top, AppTheme.Spacing.lg)
                .padding(.bottom, AppTheme.Spacing.section + 44)
            }
            .background(AppTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("Tonight")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isImportPickerPresented = true
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isFilterSheetPresented = true
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .sheet(isPresented: $isStartNightPresented) {
                StartNightSheet(store: store)
            }
            .sheet(isPresented: $isFilterSheetPresented) {
                filterSheet
            }
            .fileImporter(
                isPresented: $isImportPickerPresented,
                allowedContentTypes: [.commaSeparatedText, .zip]
            ) { result in
                switch result {
                case .success(let url):
                    Task { await store.importWatched(from: url) }
                case .failure:
                    store.importStatus = "Import cancelled."
                }
            }
            .navigationDestination(item: $selectedMovie) { movie in
                ChosenFilmView(movie: movie, store: store)
            }
        }
    }

    private var filterSheet: some View {
        NavigationStack {
            Form {
                Section("Watched") {
                    Toggle("Exclude watched titles", isOn: Binding(
                        get: { store.session.filterSettings.excludeWatched },
                        set: { store.setExcludeWatched($0) }
                    ))
                }

                Section("Minimum Rating") {
                    Picker("Minimum rating", selection: Binding(
                        get: { store.session.filterSettings.minimumAverageRating },
                        set: { store.setMinimumAverageRating($0) }
                    )) {
                        ForEach(MinimumAverageRating.allCases, id: \.self) { rating in
                            Text(rating.title).tag(rating)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if !store.availableBuzzKillTags.isEmpty {
                    Section("Buzz Kills") {
                        ForEach(store.availableBuzzKillTags, id: \.rawValue) { tag in
                            Toggle("Exclude \(tag.rawValue.capitalized)", isOn: Binding(
                                get: { store.session.filterSettings.excludedBuzzKillTags.contains(tag) },
                                set: { _ in store.toggleBuzzKillTag(tag) }
                            ))
                        }
                    }
                }
            }
            .navigationTitle("Filters")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { isFilterSheetPresented = false }
                }
            }
        }
    }
}

private struct TonightHeroSection: View {
    let movie: Movie?
    let hasCurrentSelection: Bool
    let canSpin: Bool
    let startNight: () -> Void
    let viewSelection: (Movie) -> Void
    let spin: () -> Void

    var body: some View {
        Group {
            if let movie, hasCurrentSelection {
                HStack(alignment: .top, spacing: AppTheme.Spacing.lg) {
                    AsyncImage(url: movie.posterURLValue) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous)
                            .fill(AppTheme.Colors.surfaceRaised)
                    }
                    .frame(width: 100, height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous))

                    VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                        Text("Tonight's Pick")
                            .font(.tmnlCaption)
                            .foregroundStyle(AppTheme.Colors.accent)
                            .textCase(.uppercase)

                        Text(movie.displayName)
                            .font(.tmnlDisplay)
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                            .multilineTextAlignment(.leading)

                        if !movie.genres.isEmpty {
                            Text(movie.genres.prefix(3).joined(separator: " \u{00B7} "))
                                .font(.tmnlCaption)
                                .foregroundStyle(AppTheme.Colors.textSecondary)
                        }

                        if let runtime = movie.runtimeMinutes {
                            Text("\(runtime) min")
                                .font(.tmnlCaption)
                                .foregroundStyle(AppTheme.Colors.textSecondary)
                        }

                        Spacer(minLength: 0)

                        Button("New Pick", action: spin)
                            .buttonStyle(.bordered)
                            .tint(AppTheme.Colors.accent)
                            .controlSize(.small)
                            .disabled(!canSpin)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(AppTheme.Spacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous)
                        .fill(AppTheme.Colors.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous)
                        .strokeBorder(AppTheme.Colors.accent.opacity(0.3), lineWidth: 0.5)
                )
                .contentShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous))
                .onTapGesture {
                    viewSelection(movie)
                }
            } else {
                VStack(spacing: AppTheme.Spacing.xxl) {
                    VStack(spacing: AppTheme.Spacing.sm) {
                        Text("What are we watching?")
                            .font(.tmnlDisplay)
                            .foregroundStyle(AppTheme.Colors.textPrimary)

                        Text("Start a night to find your pick.")
                            .font(.tmnlBody)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }

                    Button("Start a Night", action: startNight)
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.Colors.accent)
                        .controlSize(.large)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppTheme.Spacing.section)
            }
        }
    }
}

private struct TonightReelSection: View {
    let reelDigits: [String]
    let lockedDigitCount: Int
    let filterPrefix: String
    let narrowedCandidateCount: Int
    let animationCaption: String
    let hasCurrentSelection: Bool
    let canSpin: Bool
    let currentMovie: Movie?
    let viewSelection: (Movie) -> Void
    let spin: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
            HStack(spacing: 6) {
                ForEach(Array(reelDigits.enumerated()), id: \.offset) { index, digit in
                    Text(digit)
                        .font(.system(size: 36, weight: .heavy, design: .monospaced))
                        .foregroundStyle(
                            index < lockedDigitCount ? AppTheme.Colors.accent : AppTheme.Colors.textPrimary
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(
                            AppTheme.Colors.surface,
                            in: RoundedRectangle(cornerRadius: AppTheme.Radius.sm, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.Radius.sm, style: .continuous)
                                .strokeBorder(
                                    index < lockedDigitCount
                                        ? AppTheme.Colors.accent.opacity(0.5)
                                        : Color.white.opacity(0.08),
                                    lineWidth: 0.5
                                )
                        )
                }
            }

            HStack {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                    Text("\(filterPrefix) \u{00B7} \(narrowedCandidateCount) in play")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.Colors.textPrimary)

                    Text(animationCaption)
                        .font(.tmnlCaption)
                        .foregroundStyle(AppTheme.Colors.textTertiary)
                }

                Spacer()

                Button(action: primaryAction) {
                    Text(hasCurrentSelection ? "View Pick" : "Spin")
                        .font(.subheadline.bold())
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.Colors.accent)
                .disabled(!canSpin && !hasCurrentSelection)
            }
        }
    }

    private func primaryAction() {
        if hasCurrentSelection, let currentMovie {
            viewSelection(currentMovie)
        } else {
            spin()
        }
    }
}

private struct TonightFiltersSection: View {
    let snapshot: TonightFilterSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            Text("Filters")
                .font(.tmnlTitle)
                .foregroundStyle(AppTheme.Colors.textPrimary)

            FlowLayout(spacing: AppTheme.Spacing.sm) {
                ForEach(snapshot.filterPills, id: \.title) { pill in
                    QuickModeChip(title: pill.title, isActive: pill.isActive)
                }
            }

            HStack(spacing: 0) {
                metric(label: "Films", value: "\(snapshot.catalogCount)")
                metric(label: "Eligible", value: "\(snapshot.eligibleCount)")
                metric(label: "Watched", value: "\(snapshot.watchedCount)")
            }
        }
    }

    private func metric(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(AppTheme.Colors.textTertiary)
                .textCase(.uppercase)
            Text(value)
                .font(.headline.monospacedDigit())
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .fixedSize()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct TonightHistorySection: View {
    let historySections: [MovieNightHistorySection]

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            Text("History")
                .font(.tmnlTitle)
                .foregroundStyle(AppTheme.Colors.textPrimary)

            if historySections.isEmpty {
                Text("No picks yet.")
                    .font(.tmnlBody)
                    .foregroundStyle(AppTheme.Colors.textTertiary)
            } else {
                LazyVStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                    ForEach(historySections) { section in
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                            Text(TonightDayLabelFormatter.label(for: section.dayKey))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.Colors.textTertiary)
                                .textCase(.uppercase)

                            ForEach(section.entries) { entry in
                                HStack(spacing: AppTheme.Spacing.sm) {
                                    Text("#\(entry.number)")
                                        .font(.tmnlMono)
                                        .foregroundStyle(AppTheme.Colors.textTertiary)
                                        .fixedSize()

                                    Text(entry.displayName)
                                        .font(.subheadline)
                                        .foregroundStyle(AppTheme.Colors.textPrimary)

                                    Spacer()

                                    if entry.skipped {
                                        Text("Skipped")
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(AppTheme.Colors.accent)
                                    }
                                }
                                .padding(.vertical, AppTheme.Spacing.sm)
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct TonightFilterSnapshot {
    let filterPills: [(title: String, isActive: Bool)]
    let catalogCount: Int
    let eligibleCount: Int
    let watchedCount: Int

    static func build(
        filterSettings: MovieFilterSettings,
        catalogCount: Int,
        eligibleCount: Int,
        watchedCount: Int,
        historySections _: [MovieNightHistorySection]
    ) -> TonightFilterSnapshot {
        let filterPills = [
            (
                title: filterSettings.excludeWatched ? "Exclude Watched" : "Watched Allowed",
                isActive: filterSettings.excludeWatched
            ),
            (
                title: filterSettings.minimumAverageRating.title,
                isActive: filterSettings.minimumAverageRating != .none
            )
        ] + filterSettings.excludedBuzzKillTags.sorted().map {
            (title: "No \($0.rawValue.capitalized)", isActive: true)
        }

        return TonightFilterSnapshot(
            filterPills: filterPills,
            catalogCount: catalogCount,
            eligibleCount: eligibleCount,
            watchedCount: watchedCount
        )
    }
}

private enum TonightDayLabelFormatter {
    static func label(for dayKey: String) -> String {
        guard let date = parseFormatter.date(from: dayKey) else {
            return dayKey
        }
        return displayFormatter.string(from: date)
    }

    private static let parseFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter
    }()

    private static let displayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        formatter.timeZone = .current
        return formatter
    }()
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    struct LayoutResult {
        let positions: [CGPoint]
        let size: CGSize
    }

    struct Cache {
        var proposalWidth: CGFloat?
        var sizes: [CGSize] = []
        var result: LayoutResult?
    }

    func makeCache(subviews: Subviews) -> Cache {
        Cache()
    }

    func updateCache(_ cache: inout Cache, subviews: Subviews) {
        cache.sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        cache.result = nil
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
        layoutResult(for: proposal, subviews: subviews, cache: &cache).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
        let result = layoutResult(for: proposal, subviews: subviews, cache: &cache)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func layoutResult(for proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> LayoutResult {
        let proposalWidth = proposal.width
        if cache.sizes.count != subviews.count {
            cache.sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        }
        if cache.result == nil || cache.proposalWidth != proposalWidth {
            cache.proposalWidth = proposalWidth
            cache.result = computeLayout(proposal: proposal, sizes: cache.sizes)
        }
        return cache.result ?? LayoutResult(positions: [], size: .zero)
    }

    private func computeLayout(proposal: ProposedViewSize, sizes: [CGSize]) -> LayoutResult {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for size in sizes {
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            totalHeight = y + rowHeight
        }

        return LayoutResult(positions: positions, size: CGSize(width: maxWidth, height: totalHeight))
    }
}
