import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class MovieNightStore {
    enum PlatformStyle {
        case iOS
        case tvOS
    }

    let platform: PlatformStyle

    private(set) var catalog: [Movie] = []
    private(set) var availableBuzzKillTags: [BuzzKillTag] = []
    private(set) var eligibleMovies: [Movie] = []
    private(set) var currentMovie: Movie?
    private(set) var latestHistoryMovie: Movie?
    private(set) var featuredMovie: Movie?
    private(set) var historySections: [MovieNightHistorySection] = []
    var session: MovieNightSession
    var isSpinning = false
    var reelDigits: [String] = Array(repeating: "0", count: 5)
    var lockedDigitCount = 0
    var narrowedCandidateCount = 0
    var animationCaption = "Pull the handle to start narrowing the field."
    var importStatus = "Bring in your Letterboxd export to exclude watched titles."
    var loadingError: String?

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private var midnightResetTask: Task<Void, Never>?
    @ObservationIgnored private var moviesByNumber: [Int: Movie] = [:]
    @ObservationIgnored private var moviesBySlug: [String: Movie] = [:]

    private static let sessionDefaultsKey = "tmnl.session"

    init(
        platform: PlatformStyle,
        defaults: UserDefaults = .standard,
        calendar: Calendar = .current
    ) {
        self.platform = platform
        self.defaults = defaults
        self.calendar = calendar
        self.session = Self.loadSession(defaults: defaults, calendar: calendar)
        loadCatalog()
        normalizeForToday()
        applyDemoSelectionIfNeeded()
        refreshReel()
        scheduleMidnightReset()
    }

    deinit {
        midnightResetTask?.cancel()
    }

    var hasCurrentSelection: Bool {
        currentMovie != nil
    }

    var canSpin: Bool {
        !eligibleMovies.isEmpty && !isSpinning
    }

    var filterPrefix: String {
        let prefix = reelDigits.prefix(lockedDigitCount).joined()
        return prefix + String(repeating: "_", count: max(0, 5 - lockedDigitCount))
    }

    func sceneDidBecomeActive() {
        normalizeForToday()
        refreshReel()
        scheduleMidnightReset()
    }

    func setExcludeWatched(_ enabled: Bool) {
        session.filterSettings.excludeWatched = enabled
        handleEligibilityChange()
    }

    func setMinimumAverageRating(_ value: MinimumAverageRating) {
        session.filterSettings.minimumAverageRating = value
        handleEligibilityChange()
    }

    func toggleBuzzKillTag(_ tag: BuzzKillTag) {
        if session.filterSettings.excludedBuzzKillTags.contains(tag) {
            session.filterSettings.excludedBuzzKillTags.remove(tag)
        } else {
            session.filterSettings.excludedBuzzKillTags.insert(tag)
        }
        handleEligibilityChange()
    }

    func spin() {
        guard let movie = eligibleMovies.randomElement() else {
            return
        }
        Task {
            await animateSelection(movie, persistSelection: true)
        }
    }

    func recordSelectionFromSheet(_ movie: Movie) {
        recordSelection(movie)
        reelDigits = digits(for: movie)
        lockedDigitCount = 5
        animationCaption = "List #\(movie.number) is tonight's winner. \(movie.displayName) locked in."
    }

    func instantPick() {
        guard let movie = eligibleMovies.randomElement() else {
            return
        }
        recordSelection(movie)
        reelDigits = digits(for: movie)
        lockedDigitCount = 5
        animationCaption = "List #\(movie.number) jumps straight to the front. \(movie.displayName) is tonight's winner."
    }

    func importWatched(from url: URL) async {
        do {
            let watched = try WatchedImportService.importWatchedSlugs(from: url, movies: catalog)
            session.watchedSlugs = watched
            importStatus = "\(watched.count) watched title\(watched.count == 1 ? "" : "s") imported from \(url.lastPathComponent)."
            handleEligibilityChange()
        } catch {
            importStatus = "Could not import \(url.lastPathComponent). Use the full Letterboxd ZIP, watched.csv, or diary.csv."
        }
    }

    func importWatched(csvText: String, sourceLabel: String) async {
        let watched = WatchedImportService.resolveWatchedSlugs(csvText: csvText, movies: catalog)
        session.watchedSlugs = watched
        importStatus = "\(watched.count) watched title\(watched.count == 1 ? "" : "s") imported from \(sourceLabel)."
        handleEligibilityChange()
    }

    func importWatched(fromRemoteResource remoteURL: URL) async {
        do {
            let (data, response) = try await URLSession.shared.data(from: remoteURL)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode)
            else {
                importStatus = "Could not download the import file. Use a direct CSV or ZIP link."
                return
            }

            let fileName = inferredImportFileName(from: remoteURL, response: httpResponse)
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension((fileName as NSString).pathExtension.isEmpty ? "csv" : (fileName as NSString).pathExtension)
            try data.write(to: tempURL, options: .atomic)
            await importWatched(from: tempURL)
            try? FileManager.default.removeItem(at: tempURL)
        } catch {
            importStatus = "Could not download the import file. Use a direct CSV or ZIP link."
        }
    }

    private func loadCatalog() {
        do {
            catalog = try BundledMovieCatalog.load()
            loadingError = nil
        } catch {
            catalog = []
            loadingError = "Movie data is missing. Run the catalog build script to generate the bundled resources."
        }
        rebuildCatalogIndexes()
        recomputeDerivedState()
    }

    private func handleEligibilityChange() {
        let eligibleMovies = session.eligibleMovies(from: catalog)
        if let currentMovieNumber = session.dailySelection.currentMovieNumber,
           !eligibleMovies.contains(where: { $0.number == currentMovieNumber })
        {
            session.dailySelection.currentMovieNumber = nil
            session.dailySelection.replayMovieNumber = nil
        }
        persistSession()
        recomputeDerivedState()
        refreshReel()
    }

    private func refreshReel() {
        if let currentMovie {
            reelDigits = digits(for: currentMovie)
            lockedDigitCount = 5
            animationCaption = "Film #\(currentMovie.number) is tonight's winner."
        } else if let latestHistoryMovie {
            reelDigits = digits(for: latestHistoryMovie)
            lockedDigitCount = 5
            animationCaption = "Last pick: \(latestHistoryMovie.displayName). Spin the reel to choose tonight's winner."
        } else {
            reelDigits = Array(repeating: "0", count: 5)
            lockedDigitCount = 0
            animationCaption = "Nothing is in play yet tonight. Spin the reel to crown a winner."
        }
        updateNarrowedCandidateCount()
    }

    private func recordSelection(_ movie: Movie) {
        session.recordSelection(movie, at: Date(), calendar: calendar)
        persistSession()
        recomputeDerivedState()
        refreshReel()
    }

    private func animateSelection(_ movie: Movie, persistSelection: Bool) async {
        guard !isSpinning else { return }
        guard !eligibleMovies.isEmpty else {
            animationCaption = "No films match the current filters."
            return
        }

        isSpinning = true
        lockedDigitCount = 0
        reelDigits = (0..<5).map { _ in String(Int.random(in: 0...9)) }
        updateNarrowedCandidateCount()
        animationCaption = "The reel is spinning. Every digit cuts the field and leaves fewer films in play."

        let finalDigits = digits(for: movie)
        for index in 0..<5 {
            try? await Task.sleep(for: .milliseconds(260))
            reelDigits[index] = finalDigits[index]
            for unlockedIndex in (index + 1)..<5 {
                reelDigits[unlockedIndex] = String(Int.random(in: 0...9))
            }
            lockedDigitCount = index + 1
            let narrowedCount = MovieNightReelMetrics.narrowedCandidateCount(
                eligibleMovies: eligibleMovies,
                reelDigits: reelDigits,
                lockedDigitCount: lockedDigitCount
            )
            narrowedCandidateCount = narrowedCount
            animationCaption = narrowedCount == 1
                ? "One film remains in play. Tonight's winner is locked in."
                : "\(narrowedCount) film\(narrowedCount == 1 ? "" : "s") are still in play for prefix \(filterPrefix)."
        }

        isSpinning = false
        if persistSelection {
            recordSelection(movie)
        } else {
            refreshReel()
        }
        animationCaption = "List #\(movie.number) wins the draw. \(movie.displayName) is tonight's winner."
    }

    private func normalizeForToday() {
        let before = session
        session.normalize(on: Date(), calendar: calendar)
        if session != before {
            persistSession()
            recomputeDerivedState()
        }
    }

    private func applyDemoSelectionIfNeeded() {
#if DEBUG
        guard let slug = ProcessInfo.processInfo.environment["TMNL_DEMO_MOVIE_SLUG"],
              let movie = moviesBySlug[slug]
        else {
            return
        }

        let dayKey = MovieNightSession.dayKey(for: Date(), calendar: calendar)
        session.dailySelection = DailySelectionState(
            dayKey: dayKey,
            currentMovieNumber: movie.number,
            replayMovieNumber: movie.number
        )
        persistSession()
        recomputeDerivedState()
#endif
    }

    private func scheduleMidnightReset() {
        midnightResetTask?.cancel()
        let now = Date()
        let dayStart = calendar.startOfDay(for: now)
        guard let nextMidnight = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            return
        }
        let sleepDuration = nextMidnight.timeIntervalSince(now) + 1
        midnightResetTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(sleepDuration))
            guard let self else { return }
            self.normalizeForToday()
            self.refreshReel()
            self.scheduleMidnightReset()
        }
    }

    private func persistSession() {
        if let data = try? JSONEncoder().encode(session) {
            defaults.set(data, forKey: Self.sessionDefaultsKey)
        }
    }

    private func digits(for movie: Movie) -> [String] {
        paddedNumber(for: movie).map(String.init)
    }

    private func paddedNumber(for movie: Movie) -> String {
        String(format: "%05d", movie.number)
    }

    private func rebuildCatalogIndexes() {
        moviesByNumber = Dictionary(uniqueKeysWithValues: catalog.map { ($0.number, $0) })
        moviesBySlug = Dictionary(
            catalog.map { ($0.slug, $0) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    private func recomputeDerivedState() {
        let derivedState = MovieNightDerivedState.build(
            catalog: catalog,
            session: session,
            moviesByNumber: moviesByNumber,
            moviesBySlug: moviesBySlug
        )
        availableBuzzKillTags = derivedState.availableBuzzKillTags
        eligibleMovies = derivedState.eligibleMovies
        currentMovie = derivedState.currentMovie
        latestHistoryMovie = derivedState.latestHistoryMovie
        featuredMovie = derivedState.featuredMovie
        historySections = derivedState.historySections
        updateNarrowedCandidateCount()
    }

    private func updateNarrowedCandidateCount() {
        narrowedCandidateCount = MovieNightReelMetrics.narrowedCandidateCount(
            eligibleMovies: eligibleMovies,
            reelDigits: reelDigits,
            lockedDigitCount: lockedDigitCount
        )
    }

    private func inferredImportFileName(from url: URL, response: HTTPURLResponse) -> String {
        if let contentDisposition = response.value(forHTTPHeaderField: "Content-Disposition"),
           let range = contentDisposition.range(of: "filename=", options: .caseInsensitive)
        {
            let rawName = contentDisposition[range.upperBound...]
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"' "))
            if !rawName.isEmpty {
                return rawName
            }
        }

        let lastPathComponent = url.lastPathComponent
        if !lastPathComponent.isEmpty {
            return lastPathComponent
        }

        return "letterboxd-import.csv"
    }

    private static func loadSession(defaults: UserDefaults, calendar: Calendar) -> MovieNightSession {
        guard let data = defaults.data(forKey: sessionDefaultsKey),
              let session = try? JSONDecoder().decode(MovieNightSession.self, from: data)
        else {
            return MovieNightSession(
                filterSettings: .default,
                watchedSlugs: [],
                dailySelection: DailySelectionState(dayKey: MovieNightSession.dayKey(for: Date(), calendar: calendar)),
                historyByDay: [:]
            )
        }
        return session
    }
}
