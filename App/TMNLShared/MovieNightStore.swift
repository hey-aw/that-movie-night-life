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
    private(set) var spinPool: [Movie] = []
    private(set) var currentMovie: Movie?
    private(set) var latestHistoryMovie: Movie?
    private(set) var featuredMovie: Movie?
    private(set) var historySections: [MovieNightHistorySection] = []
    private(set) var rooms: [Room] = []
    private(set) var activeRoomID: UUID?
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
    @ObservationIgnored private var moviesByTitleID: [String: Movie] = [:]
    @ObservationIgnored private var roomRepository: RoomRepositoryProtocol

    private static let sessionDefaultsKey = "tmnl.session"

    init(
        platform: PlatformStyle,
        defaults: UserDefaults = .standard,
        calendar: Calendar = .current,
        roomRepository: RoomRepositoryProtocol = UserDefaultsRoomRepository()
    ) {
        self.platform = platform
        self.defaults = defaults
        self.calendar = calendar
        self.roomRepository = roomRepository
        self.session = Self.loadSession(defaults: defaults, calendar: calendar)
        loadCatalog()
        loadRoomState()
        normalizeForToday()
        applyDemoSelectionIfNeeded()
        recomputeDerivedState()
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
        !currentSpinPool.isEmpty && !isSpinning
    }

    var filterPrefix: String {
        let prefix = reelDigits.prefix(lockedDigitCount).joined()
        return prefix + String(repeating: "_", count: max(0, 5 - lockedDigitCount))
    }

    var activeRoom: Room? {
        rooms.first(where: { $0.id == activeRoomID })
    }

    var hasActiveRoomCurrentPick: Bool {
        activeRoom?.currentPick != nil
    }

    var activeRoomCurrentPickMovie: Movie? {
        guard let activeRoomID else { return nil }
        return currentPickMovie(for: activeRoomID)
    }

    func room(for id: UUID) -> Room? {
        rooms.first(where: { $0.id == id })
    }

    func currentPickMovie(for roomID: UUID) -> Movie? {
        guard let room = room(for: roomID), let pick = room.currentPick else {
            return nil
        }
        return moviesByTitleID[pick.titleID]
    }

    func roomCandidateCount(for roomID: UUID) -> Int {
        guard let room = room(for: roomID) else { return 0 }
        return roomCandidateTitleIDs(for: room).count
    }

    func roomCode(for room: Room) -> String {
        String(room.id.uuidString.replacingOccurrences(of: "-", with: "").prefix(8)).uppercased()
    }

    func roomInviteLink(for room: Room) -> String {
        "tmnlnight://room/\(roomCode(for: room))"
    }

    func sceneDidBecomeActive() {
        normalizeForToday()
        recomputeDerivedState()
        refreshReel()
        scheduleMidnightReset()
    }

    func activateRoom(_ roomID: UUID) {
        guard room(for: roomID) != nil else { return }
        activeRoomID = roomID
        persistRoomState()
        refreshRoomCurrentSelection()
    }

    func setSelectionMode(_ mode: RoomSelectionMode, for roomID: UUID) {
        mutateRoom(roomID) { room in
            room.setSelectionMode(mode)
        }
    }

    func makeNewPick(for roomID: UUID) {
        activateRoom(roomID)
        instantPick()
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
        guard let movie = selectedMovieForSpin() else {
            animationCaption = activeRoom == nil
                ? "No films match the current filters."
                : "No films match the active room filters."
            return
        }
        Task {
            await animateSelection(movie, persistSelection: activeRoom == nil)
        }
    }

    func recordSelectionFromSheet(_ movie: Movie) {
        if activeRoom != nil {
            setCurrentRoomPick(movie)
        } else {
            recordSelection(movie)
        }
        reelDigits = digits(for: movie)
        lockedDigitCount = 5
        animationCaption = "List #\(movie.number) is tonight's winner. \(movie.displayName) locked in."
    }

    func instantPick() {
        guard let movie = selectedMovieForSpin() else {
            return
        }

        if activeRoom != nil {
            setCurrentRoomPick(movie)
        } else {
            recordSelection(movie)
        }
        reelDigits = digits(for: movie)
        lockedDigitCount = 5
        animationCaption = "List #\(movie.number) jumps straight to the front. \(movie.displayName) is tonight's winner."
    }

    func markCurrentPick(as disposition: RoomHistoryDisposition) {
        guard let roomID = activeRoomID,
              let roomIndex = roomIndex(for: roomID),
              let pick = rooms[roomIndex].currentPick,
              let movie = moviesByTitleID[pick.titleID]
        else {
            clearActiveRoomPick()
            return
        }

        let entry = RoomSelectionEngine.resolvedHistoryEntry(
            from: movie,
            pickedAt: pick.pickedAt,
            resolvedAt: Date(),
            disposition: disposition
        )

        rooms[roomIndex].appendHistory(entry)
        rooms[roomIndex].setCurrentPick(nil)

        if disposition == .watched || disposition == .seen {
            session.watchedSlugs.insert(movie.slug)
            session.recordSelection(movie, at: Date(), calendar: calendar)
        }

        persistSession()
        persistRoomState()
        recomputeDerivedState()
        refreshReel()
    }

    func markCurrentPickAsWatched() {
        markCurrentPick(as: .watched)
    }

    func markCurrentPickAsSeen() {
        markCurrentPick(as: .seen)
    }

    func markCurrentPickAsNotInterested() {
        markCurrentPick(as: .passed)
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

    private func loadRoomState() {
        do {
            if let saved = try roomRepository.loadState() {
                rooms = saved.rooms
                activeRoomID = saved.activeRoomID
            } else {
                rooms = roomRepository.seededRooms(using: catalog)
                activeRoomID = rooms.first?.id
                persistRoomState()
            }
        } catch {
            rooms = roomRepository.seededRooms(using: catalog)
            activeRoomID = rooms.first?.id
        }

        if refreshSeededRoomTemplates() {
            persistRoomState()
        }

        if rooms.isEmpty {
            activeRoomID = nil
        } else if activeRoomID == nil || activeRoom == nil {
            activeRoomID = rooms.first?.id
        }
    }

    private func refreshSeededRoomTemplates() -> Bool {
        let seededRooms = roomRepository.seededRooms(using: catalog)
        var didChange = false

        for seededRoom in seededRooms {
            guard let templateID = seededRoom.templateID,
                  let index = rooms.firstIndex(where: { $0.templateID == templateID })
            else {
                continue
            }

            if rooms[index].source != seededRoom.source || rooms[index].name != seededRoom.name {
                rooms[index].name = seededRoom.name
                rooms[index].source = seededRoom.source
                rooms[index].updatedAt = Date()
                didChange = true
            }
        }

        return didChange
    }

    private func handleEligibilityChange() {
        let eligibleMovies = session.eligibleMovies(from: catalog)
        if let currentMovieNumber = session.dailySelection.currentMovieNumber,
           !eligibleMovies.contains(where: { $0.number == currentMovieNumber })
        {
            session.dailySelection.currentMovieNumber = nil
            session.dailySelection.replayMovieNumber = nil
        }
        clearActiveRoomPickIfInvalid()
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
            animationCaption = activeRoom == nil
                ? "Nothing is in play yet tonight. Spin the reel to crown a winner."
                : "No room pick yet. Pull a new pick from the active room."
        }
        updateNarrowedCandidateCount()
    }

    private func recordSelection(_ movie: Movie) {
        session.recordSelection(movie, at: Date(), calendar: calendar)
        session.advanceRoulette(afterSelecting: movie, in: catalog)
        persistSession()
        recomputeDerivedState()
        refreshReel()
    }

    private func animateSelection(_ movie: Movie, persistSelection: Bool) async {
        guard !isSpinning else { return }
        guard !currentSpinPool.isEmpty else {
            animationCaption = "No films match the current filters."
            return
        }

        isSpinning = true
        lockedDigitCount = 0
        reelDigits = (0..<5).map { _ in String(Int.random(in: 0...9)) }
        updateNarrowedCandidateCount()
        animationCaption = "The reel is spinning. Every digit cuts the field and leaves fewer films in play."

        let finalDigits = digits(for: movie)
        let animationPool = currentSpinPool
        for index in 0..<5 {
            try? await Task.sleep(for: .milliseconds(260))
            reelDigits[index] = finalDigits[index]
            for unlockedIndex in (index + 1)..<5 {
                reelDigits[unlockedIndex] = String(Int.random(in: 0...9))
            }
            lockedDigitCount = index + 1
            let narrowedCount = MovieNightReelMetrics.narrowedCandidateCount(
                eligibleMovies: animationPool,
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
            setCurrentRoomPick(movie)
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

    private func persistRoomState() {
        let state = PersistedRoomState(activeRoomID: activeRoomID, rooms: rooms)
        try? roomRepository.saveState(state)
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
        moviesByTitleID = Dictionary(
            catalog.map { ($0.titleID, $0) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    private func recomputeDerivedState() {
        let previousRouletteState = session.rouletteState
        session.normalizeRoulette(in: catalog)
        let derivedState = MovieNightDerivedState.build(
            catalog: catalog,
            session: session,
            moviesByNumber: moviesByNumber,
            moviesBySlug: moviesBySlug
        )
        if session.rouletteState != previousRouletteState {
            persistSession()
        }
        availableBuzzKillTags = derivedState.availableBuzzKillTags
        eligibleMovies = derivedState.eligibleMovies
        spinPool = roomCandidates()
        latestHistoryMovie = derivedState.latestHistoryMovie

        let roomCurrentMovie = activeRoomCurrentPickMovie
        currentMovie = roomCurrentMovie ?? derivedState.currentMovie
        featuredMovie = currentMovie ?? latestHistoryMovie
        historySections = derivedState.historySections
        updateNarrowedCandidateCount()
    }

    private func updateNarrowedCandidateCount() {
        if currentMovie != nil {
            narrowedCandidateCount = 1
            return
        }
        narrowedCandidateCount = MovieNightReelMetrics.narrowedCandidateCount(
            eligibleMovies: currentSpinPool,
            reelDigits: reelDigits,
            lockedDigitCount: lockedDigitCount
        )
    }

    private var currentSpinPool: [Movie] {
        if activeRoom != nil {
            return spinPool
        }
        return spinPool.isEmpty ? eligibleMovies : spinPool
    }

    private func selectedMovieForSpin() -> Movie? {
        guard let room = activeRoom else {
            return currentSpinPool.randomElement()
        }

        let candidates = roomCandidateTitleIDs(for: room)
        guard let titleID = RoomSelectionEngine.pick(from: room, candidates: candidates) else {
            return nil
        }
        return moviesByTitleID[titleID]
    }

    private func refreshRoomCurrentSelection() {
        clearActiveRoomPickIfInvalid()
        recomputeDerivedState()
        refreshReel()
    }

    private func clearActiveRoomPick() {
        guard let roomIndex = roomIndex(for: activeRoomID) else { return }
        rooms[roomIndex].setCurrentPick(nil)
        persistRoomState()
        refreshRoomCurrentSelection()
    }

    private func clearActiveRoomPickIfInvalid() {
        guard let roomIndex = roomIndex(for: activeRoomID),
              let pick = rooms[roomIndex].currentPick
        else {
            return
        }

        guard let movie = moviesByTitleID[pick.titleID],
              rooms[roomIndex].source.list.orderedTitleIDs.contains(pick.titleID),
              passesRoomFilters(movie)
        else {
            rooms[roomIndex].setCurrentPick(nil)
            persistRoomState()
            return
        }
    }

    private func setCurrentRoomPick(_ movie: Movie) {
        guard let roomIndex = roomIndex(for: activeRoomID) else { return }

        rooms[roomIndex].setCurrentPick(RoomCurrentPick(
            titleID: movie.titleID,
            slug: movie.slug,
            number: movie.number,
            displayName: movie.displayName,
            pickedAt: Date()
        ))
        persistRoomState()
        recomputeDerivedState()
        refreshReel()
    }

    private func mutateRoom(_ roomID: UUID, mutate: (inout Room) -> Void) {
        guard let index = roomIndex(for: roomID) else { return }
        mutate(&rooms[index])
        rooms[index].updatedAt = Date()
        persistRoomState()
        if roomID == activeRoomID {
            refreshRoomCurrentSelection()
        }
    }

    private func roomIndex(for roomID: UUID?) -> Int? {
        guard let roomID else { return nil }
        return rooms.firstIndex { $0.id == roomID }
    }

    private func passesRoomFilters(_ movie: Movie) -> Bool {
        if session.filterSettings.excludeWatched && session.watchedSlugs.contains(movie.slug) {
            return false
        }

        if let threshold = session.filterSettings.minimumAverageRating.threshold {
            guard let aggregateRating = movie.aggregateRating, aggregateRating >= threshold else {
                return false
            }
        }

        if !session.filterSettings.excludedBuzzKillTags.isDisjoint(with: movie.buzzKillTags) {
            return false
        }

        return true
    }

    private func roomCandidateTitleIDs(for room: Room) -> [String] {
        RoomSelectionEngine.candidateTitleIDs(
            for: room,
            catalogByTitleID: moviesByTitleID,
            excludeTitleIDs: [],
            eligibleByFilters: passesRoomFilters
        )
    }

    private func roomCandidates() -> [Movie] {
        guard let room = activeRoom else {
            return eligibleMovies
        }
        return roomCandidateTitleIDs(for: room).compactMap { moviesByTitleID[$0] }
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
