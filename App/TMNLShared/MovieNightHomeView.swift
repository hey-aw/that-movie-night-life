import SwiftUI
import UniformTypeIdentifiers

struct MovieNightHomeView: View {
    @Bindable var store: MovieNightStore

    @State private var isImportPickerPresented = false
    @State private var isFilterSheetPresented = false

    var body: some View {
#if os(tvOS)
        Group {
            switch store.platform {
            case .iOS:
                iosBody
            case .tvOS:
                tvBody
            }
        }
        .sheet(isPresented: $isImportPickerPresented) {
            TVImportSheet(store: store, isPresented: $isImportPickerPresented)
        }
#else
        Group {
            switch store.platform {
            case .iOS:
                iosBody
            case .tvOS:
                tvBody
            }
        }
        .fileImporter(
            isPresented: $isImportPickerPresented,
            allowedContentTypes: [.commaSeparatedText, .zip]
        ) { result in
            switch result {
            case .success(let url):
                Task {
                    await store.importWatched(from: url)
                }
            case .failure:
                store.importStatus = "Import cancelled."
            }
        }
#endif
    }

    private var iosBody: some View {
        NavigationStack {
            GeometryReader { proxy in
                let layout = TMNLIOSViewportLayout(viewportWidth: proxy.size.width)

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: layout.sectionSpacing) {
                        HomeIntroBlock(store: store)
                        HomeMetricsBlock(store: store, layout: layout)
                        HomeReelBlock(store: store, layout: layout)
                        HomeControlBlock(
                            store: store,
                            layout: layout,
                            isImportPickerPresented: $isImportPickerPresented
                        )
                        HomeFilterSummaryBlock(store: store, layout: layout)
                        HomeResultBlock(store: store, layout: layout)
                        HomeHistoryBlock(store: store)
                        HomeImportStatusBlock(
                            store: store,
                            isImportPickerPresented: $isImportPickerPresented
                        )
                    }
                    .frame(maxWidth: layout.contentMaxWidth, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, layout.horizontalPadding)
                    .padding(.top, 20)
                    .padding(.bottom, AppTheme.Spacing.section + 44)
                }
            }
            .navigationTitle("That Movie Night Life")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Import") {
                        isImportPickerPresented = true
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Filters") {
                        isFilterSheetPresented = true
                    }
                }
            }
            .sheet(isPresented: $isFilterSheetPresented) {
                NavigationStack {
                    FilterEditor(store: store)
                        .navigationTitle("Filters")
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Done") {
                                    isFilterSheetPresented = false
                                }
                            }
                        }
                }
            }
        }
    }

    private var tvBody: some View {
        ScrollView {
            HStack(alignment: .top, spacing: 40) {
                VStack(alignment: .leading, spacing: 24) {
                    introBlock()
                    metricsBlock()
                    FilterEditor(store: store)
                    importStatusBlock
                }
                .frame(maxWidth: 460, alignment: .leading)

                VStack(alignment: .leading, spacing: 24) {
                    reelBlock()
                    controlBlock()
                    resultBlock()
                    historyBlock
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(48)
        }
    }

    private func introBlock(layout: TMNLIOSViewportLayout? = nil) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("10,734 films. Let the good times roll.")
                .font(.caption)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            Text("That Movie Night Life")
                .font(store.platform == .tvOS ? .largeTitle.bold() : .title.bold())
            Text("Filter out watched titles and optional buzz kills, then spin the reel until only one winner remains.")
                .foregroundStyle(.secondary)
            if let loadingError = store.loadingError {
                Text(loadingError)
                    .foregroundStyle(.red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func metricsBlock(layout: TMNLIOSViewportLayout? = nil) -> some View {
        let cards = [
            HomeMetricItem(id: "films", label: "Films", value: "\(store.catalog.count)"),
            HomeMetricItem(id: "eligible", label: "Eligible", value: "\(store.eligibleMovies.count)"),
            HomeMetricItem(id: "watched", label: "Watched", value: "\(store.session.watchedSlugs.count)"),
            HomeMetricItem(id: "history", label: "History", value: "\(store.historySections.reduce(0) { $0 + $1.entries.count })")
        ]

        return Group {
            if let layout, store.platform == .iOS {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: layout.metricsColumnCount),
                    alignment: .leading,
                    spacing: 12
                ) {
                    ForEach(cards) { card in
                        MetricCard(label: card.label, value: card.value)
                    }
                }
            } else {
                HStack(spacing: 16) {
                    ForEach(cards) { card in
                        MetricCard(label: card.label, value: card.value)
                    }
                }
            }
        }
    }

    private func reelBlock(layout: TMNLIOSViewportLayout? = nil) -> some View {
        let digitWidth = store.platform == .tvOS ? 74 : (layout?.reelDigitWidth ?? 58)
        let digitHeight = store.platform == .tvOS ? 92 : (layout?.reelDigitHeight ?? 72)
        let digitSpacing = store.platform == .tvOS ? 10 : (layout?.reelDigitSpacing ?? 10)
        let digitFontSize = store.platform == .tvOS ? 60 : (layout?.reelDigitFontSize ?? 42)

        return VStack(alignment: .leading, spacing: 12) {
            Text("Random Film Number")
                .font(.caption)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)

            HStack(spacing: digitSpacing) {
                ForEach(Array(store.reelDigits.enumerated()), id: \.offset) { index, digit in
                    Text(digit)
                        .font(store.platform == .tvOS ? .system(size: digitFontSize, weight: .black, design: .rounded) : .system(size: digitFontSize, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .frame(width: digitWidth, height: digitHeight)
                        .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(index < store.lockedDigitCount ? Color.orange : Color.secondary.opacity(0.18), lineWidth: 2)
                        )
                }
            }

            Text("\(store.filterPrefix) • \(store.narrowedCandidateCount) in play")
                .font(.callout.weight(.semibold))
            Text(store.animationCaption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .background(Color.tmnlPanelBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func controlBlock(layout: TMNLIOSViewportLayout? = nil) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            let stacksVertically = layout?.stacksControlsVertically == true && store.platform == .iOS

            Group {
                if stacksVertically {
                    VStack(alignment: .leading, spacing: 10) {
                        controlButtons(fillWidth: true)
                    }
                } else {
                    HStack(spacing: 12) {
                        controlButtons(fillWidth: false)
                    }
                }
            }

            if store.platform == .tvOS {
                Button("Import Letterboxd Export") {
                    isImportPickerPresented = true
                }
                .buttonStyle(.bordered)
            }

            if store.eligibleMovies.isEmpty {
                Text("No films match the current filters. Relax the filters or import a different watched file.")
                    .foregroundStyle(.orange)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func controlButtons(fillWidth: Bool) -> some View {
        Button("Spin the Reel") {
            store.spin()
        }
        .buttonStyle(.borderedProminent)
        .disabled(!store.canSpin)
        .frame(maxWidth: fillWidth ? .infinity : nil, alignment: .leading)

        Button("Pick a Winner") {
            store.instantPick()
        }
        .buttonStyle(.bordered)
        .disabled(store.isSpinning || store.eligibleMovies.isEmpty)
        .frame(maxWidth: fillWidth ? .infinity : nil, alignment: .leading)

        Button("New Pick") {
            store.spin()
        }
        .buttonStyle(.bordered)
        .disabled(!store.canSpin)
        .frame(maxWidth: fillWidth ? .infinity : nil, alignment: .leading)
    }

    private func filterSummaryBlock(layout: TMNLIOSViewportLayout? = nil) -> some View {
        let pills = [
            (store.session.filterSettings.excludeWatched ? "Exclude Watched" : "Watched Allowed", store.session.filterSettings.excludeWatched),
            (store.session.filterSettings.minimumAverageRating.title, store.session.filterSettings.minimumAverageRating != .none)
        ] + store.session.filterSettings.excludedBuzzKillTags.sorted().map { ("No \($0.rawValue.capitalized)", true) }

        return VStack(alignment: .leading, spacing: 10) {
            Text("Current Filters")
                .font(.headline)

            if let layout, store.platform == .iOS {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: layout.isVeryCompact ? 132 : 150), spacing: 8, alignment: .leading)],
                    alignment: .leading,
                    spacing: 8
                ) {
                    ForEach(pills, id: \.0) { pill in
                        FilterPill(title: pill.0, active: pill.1)
                    }
                }
            } else {
                HStack(spacing: 8) {
                    ForEach(pills, id: \.0) { pill in
                        FilterPill(title: pill.0, active: pill.1)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func resultBlock(layout: TMNLIOSViewportLayout? = nil) -> some View {
        let stacksVertically = layout?.stacksResultVertically == true && store.platform == .iOS
        let posterWidth = store.platform == .tvOS ? 220 : (layout?.posterWidth ?? 140)
        let posterHeight = store.platform == .tvOS ? 330 : (layout?.posterHeight ?? 210)

        return VStack(alignment: .leading, spacing: 16) {
            Text(store.hasCurrentSelection ? "Tonight's Selection" : "Result")
                .font(.headline)

            if let movie = store.featuredMovie {
                Group {
                    if stacksVertically {
                        VStack(alignment: .leading, spacing: 16) {
                            posterView(for: movie, width: posterWidth, height: posterHeight)
                            resultDetails(for: movie)
                        }
                    } else {
                        HStack(alignment: .top, spacing: 18) {
                            posterView(for: movie, width: posterWidth, height: posterHeight)
                            resultDetails(for: movie)
                        }
                    }
                }
            } else {
                Text("Awaiting tonight's pick.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .background(Color.tmnlPanelBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func posterView(for movie: Movie, width: CGFloat, height: CGFloat) -> some View {
        AsyncImage(url: movie.posterURLValue) { image in
            image
                .resizable()
                .scaledToFill()
        } placeholder: {
            ZStack {
                RoundedRectangle(cornerRadius: 18).fill(.secondary.opacity(0.2))
                ProgressView()
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func resultDetails(for movie: Movie) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(movie.displayName)
                .font(store.platform == .tvOS ? .title.bold() : .title2.bold())
            Text("List #\(movie.number)")
                .foregroundStyle(.secondary)

            if let rating = movie.aggregateRating {
                Text("Letterboxd rating \(rating, format: .number.precision(.fractionLength(2)))")
                    .foregroundStyle(.secondary)
            }

            if !movie.genres.isEmpty {
                Text(movie.genres.joined(separator: " • "))
                    .foregroundStyle(.secondary)
            }

            actionBlock(for: movie)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func actionBlock(for movie: Movie) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            switch store.platform {
            case .iOS:
                if let url = movie.letterboxdURLValue {
                    Link("Open on Letterboxd", destination: url)
                }
                if let url = movie.watchURLValue {
                    Link("Where to Watch", destination: url)
                }
            case .tvOS:
                if let url = movie.appleTVSearchURL {
                    Link("Search in Apple TV", destination: url)
                }
                if let url = movie.letterboxdURLValue {
                    Link("Open on Letterboxd", destination: url)
                }
            }
        }
        .buttonStyle(.bordered)
    }

    private var historyBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Drawing History")
                .font(.headline)
            if store.historySections.isEmpty {
                Text("No pick yet today.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(store.historySections) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(dayLabel(for: section.dayKey))
                            .font(.subheadline.bold())
                        ForEach(section.entries) { entry in
                            HStack {
                                Text("#\(entry.number)")
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                                Text(entry.displayName)
                                Spacer()
                                if entry.skipped {
                                    Text("Skipped")
                                        .font(.caption.weight(.semibold))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(.orange.opacity(0.18), in: Capsule())
                                }
                            }
                            .font(.callout)
                        }
                    }
                    .padding(.bottom, 8)
                }
            }
        }
    }

    private var importStatusBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Import")
                .font(.headline)
            Text(store.importStatus)
                .foregroundStyle(.secondary)

            if store.platform == .iOS {
                Button("Choose Letterboxd Export") {
                    isImportPickerPresented = true
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func dayLabel(for dayKey: String) -> String {
        HomeDayLabelFormatter.label(for: dayKey)
    }
}

private struct HomeMetricItem: Identifiable {
    let id: String
    let label: String
    let value: String
}

private struct HomeIntroBlock: View {
    @Bindable var store: MovieNightStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("10,734 films. Let the good times roll.")
                .font(.caption)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            Text("That Movie Night Life")
                .font(store.platform == .tvOS ? .largeTitle.bold() : .title.bold())
            Text("Filter out watched titles and optional buzz kills, then spin the reel until only one winner remains.")
                .foregroundStyle(.secondary)
            if let loadingError = store.loadingError {
                Text(loadingError)
                    .foregroundStyle(.red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct HomeMetricsBlock: View {
    @Bindable var store: MovieNightStore
    let layout: TMNLIOSViewportLayout?

    private var cards: [HomeMetricItem] {
        [
            HomeMetricItem(id: "films", label: "Films", value: "\(store.catalog.count)"),
            HomeMetricItem(id: "eligible", label: "Eligible", value: "\(store.eligibleMovies.count)"),
            HomeMetricItem(id: "watched", label: "Watched", value: "\(store.session.watchedSlugs.count)"),
            HomeMetricItem(id: "history", label: "History", value: "\(store.historySections.reduce(0) { $0 + $1.entries.count })")
        ]
    }

    var body: some View {
        Group {
            if let layout, store.platform == .iOS {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: layout.metricsColumnCount),
                    alignment: .leading,
                    spacing: 12
                ) {
                    ForEach(cards) { card in
                        MetricCard(label: card.label, value: card.value)
                    }
                }
            } else {
                HStack(spacing: 16) {
                    ForEach(cards) { card in
                        MetricCard(label: card.label, value: card.value)
                    }
                }
            }
        }
    }
}

private struct HomeReelBlock: View {
    @Bindable var store: MovieNightStore
    let layout: TMNLIOSViewportLayout?

    var body: some View {
        let digitWidth = store.platform == .tvOS ? 74 : (layout?.reelDigitWidth ?? 58)
        let digitHeight = store.platform == .tvOS ? 92 : (layout?.reelDigitHeight ?? 72)
        let digitSpacing = store.platform == .tvOS ? 10 : (layout?.reelDigitSpacing ?? 10)
        let digitFontSize = store.platform == .tvOS ? 60 : (layout?.reelDigitFontSize ?? 42)

        VStack(alignment: .leading, spacing: 12) {
            Text("Random Film Number")
                .font(.caption)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)

            HStack(spacing: digitSpacing) {
                ForEach(Array(store.reelDigits.enumerated()), id: \.offset) { index, digit in
                    Text(digit)
                        .font(store.platform == .tvOS ? .system(size: digitFontSize, weight: .black, design: .rounded) : .system(size: digitFontSize, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .frame(width: digitWidth, height: digitHeight)
                        .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(index < store.lockedDigitCount ? Color.orange : Color.secondary.opacity(0.18), lineWidth: 2)
                        )
                }
            }

            Text("\(store.filterPrefix) • \(store.narrowedCandidateCount) in play")
                .font(.callout.weight(.semibold))
            Text(store.animationCaption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .background(Color.tmnlPanelBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct HomeControlBlock: View {
    @Bindable var store: MovieNightStore
    let layout: TMNLIOSViewportLayout?
    @Binding var isImportPickerPresented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            let stacksVertically = layout?.stacksControlsVertically == true && store.platform == .iOS

            Group {
                if stacksVertically {
                    VStack(alignment: .leading, spacing: 10) {
                        controlButtons(fillWidth: true)
                    }
                } else {
                    HStack(spacing: 12) {
                        controlButtons(fillWidth: false)
                    }
                }
            }

            if store.platform == .tvOS {
                Button("Import Letterboxd Export") {
                    isImportPickerPresented = true
                }
                .buttonStyle(.bordered)
            }

            if store.eligibleMovies.isEmpty {
                Text("No films match the current filters. Relax the filters or import a different watched file.")
                    .foregroundStyle(.orange)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func controlButtons(fillWidth: Bool) -> some View {
        Button("Spin the Reel") {
            store.spin()
        }
        .buttonStyle(.borderedProminent)
        .disabled(!store.canSpin)
        .frame(maxWidth: fillWidth ? .infinity : nil, alignment: .leading)

        Button("Pick a Winner") {
            store.instantPick()
        }
        .buttonStyle(.bordered)
        .disabled(store.isSpinning || store.eligibleMovies.isEmpty)
        .frame(maxWidth: fillWidth ? .infinity : nil, alignment: .leading)

        Button("New Pick") {
            store.spin()
        }
        .buttonStyle(.bordered)
        .disabled(!store.canSpin)
        .frame(maxWidth: fillWidth ? .infinity : nil, alignment: .leading)
    }
}

private struct HomeFilterSummaryBlock: View {
    @Bindable var store: MovieNightStore
    let layout: TMNLIOSViewportLayout?

    private var pills: [(String, Bool)] {
        [
            (store.session.filterSettings.excludeWatched ? "Exclude Watched" : "Watched Allowed", store.session.filterSettings.excludeWatched),
            (store.session.filterSettings.minimumAverageRating.title, store.session.filterSettings.minimumAverageRating != .none)
        ] + store.session.filterSettings.excludedBuzzKillTags.sorted().map { ("No \($0.rawValue.capitalized)", true) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Current Filters")
                .font(.headline)

            if let layout, store.platform == .iOS {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: layout.isVeryCompact ? 132 : 150), spacing: 8, alignment: .leading)],
                    alignment: .leading,
                    spacing: 8
                ) {
                    ForEach(Array(pills.enumerated()), id: \.offset) { _, pill in
                        FilterPill(title: pill.0, active: pill.1)
                    }
                }
            } else {
                HStack(spacing: 8) {
                    ForEach(Array(pills.enumerated()), id: \.offset) { _, pill in
                        FilterPill(title: pill.0, active: pill.1)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct HomeResultBlock: View {
    @Bindable var store: MovieNightStore
    let layout: TMNLIOSViewportLayout?

    var body: some View {
        let stacksVertically = layout?.stacksResultVertically == true && store.platform == .iOS
        let posterWidth = store.platform == .tvOS ? 220 : (layout?.posterWidth ?? 140)
        let posterHeight = store.platform == .tvOS ? 330 : (layout?.posterHeight ?? 210)

        return VStack(alignment: .leading, spacing: 16) {
            Text(store.hasCurrentSelection ? "Tonight's Selection" : "Result")
                .font(.headline)

            if let movie = store.featuredMovie {
                Group {
                    if stacksVertically {
                        VStack(alignment: .leading, spacing: 16) {
                            posterView(for: movie, width: posterWidth, height: posterHeight)
                            resultDetails(for: movie)
                        }
                    } else {
                        HStack(alignment: .top, spacing: 18) {
                            posterView(for: movie, width: posterWidth, height: posterHeight)
                            resultDetails(for: movie)
                        }
                    }
                }
            } else {
                Text("Awaiting tonight's pick.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .background(Color.tmnlPanelBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func posterView(for movie: Movie, width: CGFloat, height: CGFloat) -> some View {
        AsyncImage(url: movie.posterURLValue) { image in
            image
                .resizable()
                .scaledToFill()
        } placeholder: {
            ZStack {
                RoundedRectangle(cornerRadius: 18).fill(.secondary.opacity(0.2))
                ProgressView()
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func resultDetails(for movie: Movie) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(movie.displayName)
                .font(store.platform == .tvOS ? .title.bold() : .title2.bold())
            Text("List #\(movie.number)")
                .foregroundStyle(.secondary)

            if let rating = movie.aggregateRating {
                Text("Letterboxd rating \(rating, format: .number.precision(.fractionLength(2)))")
                    .foregroundStyle(.secondary)
            }

            if !movie.genres.isEmpty {
                Text(movie.genres.joined(separator: " • "))
                    .foregroundStyle(.secondary)
            }

            actionBlock(for: movie)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func actionBlock(for movie: Movie) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            switch store.platform {
            case .iOS:
                if let url = movie.letterboxdURLValue {
                    Link("Open on Letterboxd", destination: url)
                }
                if let url = movie.watchURLValue {
                    Link("Where to Watch", destination: url)
                }
            case .tvOS:
                if let url = movie.appleTVSearchURL {
                    Link("Search in Apple TV", destination: url)
                }
                if let url = movie.letterboxdURLValue {
                    Link("Open on Letterboxd", destination: url)
                }
            }
        }
        .buttonStyle(.bordered)
    }
}

private struct HomeHistoryBlock: View {
    @Bindable var store: MovieNightStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Drawing History")
                .font(.headline)
            if store.historySections.isEmpty {
                Text("No pick yet today.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(store.historySections) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(HomeDayLabelFormatter.label(for: section.dayKey))
                            .font(.subheadline.bold())
                        ForEach(section.entries) { entry in
                            HStack {
                                Text("#\(entry.number)")
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                                Text(entry.displayName)
                                Spacer()
                                if entry.skipped {
                                    Text("Skipped")
                                        .font(.caption.weight(.semibold))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(.orange.opacity(0.18), in: Capsule())
                                }
                            }
                            .font(.callout)
                        }
                    }
                    .padding(.bottom, 8)
                }
            }
        }
    }
}

private struct HomeImportStatusBlock: View {
    @Bindable var store: MovieNightStore
    @Binding var isImportPickerPresented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Import")
                .font(.headline)
            Text(store.importStatus)
                .foregroundStyle(.secondary)

            if store.platform == .iOS {
                Button("Choose Letterboxd Export") {
                    isImportPickerPresented = true
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

private enum HomeDayLabelFormatter {
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
        formatter.dateFormat = "EEE, MMM d, yyyy"
        formatter.timeZone = .current
        return formatter
    }()
}

private struct MetricCard: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.tmnlPanelBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct FilterPill: View {
    let title: String
    let active: Bool

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(active ? Color.orange.opacity(0.16) : Color.secondary.opacity(0.12), in: Capsule())
            .foregroundStyle(active ? Color.orange : Color.secondary)
    }
}

private struct FilterEditor: View {
    @Bindable var store: MovieNightStore

    var body: some View {
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
    }
}

private extension Color {
    static var tmnlPanelBackground: Color {
#if os(tvOS)
        Color.white.opacity(0.08)
#else
        Color(uiColor: .secondarySystemBackground)
#endif
    }
}

private extension View {
}

#if os(tvOS)
private struct TVImportSheet: View {
    @Bindable var store: MovieNightStore
    @Binding var isPresented: Bool

    @State private var remoteURLText = ""
    @State private var pastedCSVText = ""
    @State private var isImporting = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Import Letterboxd Export")
                            .font(.title2.bold())
                        Text("tvOS does not provide the iOS file importer. Paste watched.csv or diary.csv contents here, or enter a direct CSV or ZIP download URL.")
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Hosted CSV or ZIP URL")
                            .font(.headline)
                        TextField("https://example.com/watched.csv", text: $remoteURLText)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        Button("Import From URL") {
                            importFromURL()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(remoteImportURL == nil || isImporting)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Paste CSV Contents")
                            .font(.headline)
                        TextField("Paste watched.csv or diary.csv contents", text: $pastedCSVText, axis: .vertical)
                            .lineLimit(10...16)
                            .frame(minHeight: 220, alignment: .topLeading)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color.tmnlPanelBackground)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                            )
                        Button("Import Pasted CSV") {
                            importPastedCSV()
                        }
                        .buttonStyle(.bordered)
                        .disabled(trimmedPastedCSV.isEmpty || isImporting)
                    }

                    if isImporting {
                        ProgressView("Importing...")
                    }

                    Text(store.importStatus)
                        .foregroundStyle(.secondary)
                }
                .padding(40)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
    }

    private var trimmedPastedCSV: String {
        pastedCSVText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var remoteImportURL: URL? {
        let trimmed = remoteURLText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(string: trimmed)
    }

    private func importFromURL() {
        guard let remoteImportURL else { return }
        isImporting = true
        Task {
            await store.importWatched(fromRemoteResource: remoteImportURL)
            await MainActor.run {
                isImporting = false
            }
        }
    }

    private func importPastedCSV() {
        guard !trimmedPastedCSV.isEmpty else { return }
        isImporting = true
        Task {
            await store.importWatched(csvText: trimmedPastedCSV, sourceLabel: "pasted watched.csv")
            await MainActor.run {
                isImporting = false
            }
        }
    }
}
#endif
