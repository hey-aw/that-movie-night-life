import Foundation
import Observation

@MainActor
@Observable
final class StartNightViewModel {
    enum Step: Int, CaseIterable {
        case audience = 0
        case mode
        case shortlist
    }

    enum Audience: String, CaseIterable {
        case justMe = "Just Me"
        case meAndSomeone = "Me + Someone"
        case aRoom = "A Room"
    }

    enum SelectionMode: String, CaseIterable {
        case watchlistDraw = "Watchlist Draw"
        case under2Hours = "Under 2 Hours"
        case highlyRated = "Highly Rated"
        case wildCard = "Wild Card"
    }

    var currentStep: Step = .audience
    var selectedAudience: Audience?
    var selectedMode: SelectionMode?
    var shortlist: [Movie] = []
    var lockedPick: Movie?

    private let catalog: [Movie]
    private let eligibleMovies: [Movie]

    init(catalog: [Movie], eligibleMovies: [Movie]) {
        self.catalog = catalog
        self.eligibleMovies = eligibleMovies
    }

    var canAdvance: Bool {
        switch currentStep {
        case .audience:
            return selectedAudience != nil
        case .mode:
            return selectedMode != nil
        case .shortlist:
            return false
        }
    }

    var stepCount: Int { Step.allCases.count }
    var stepIndex: Int { currentStep.rawValue }

    func advance() {
        switch currentStep {
        case .audience:
            currentStep = .mode
        case .mode:
            generateShortlist()
            currentStep = .shortlist
        case .shortlist:
            break
        }
    }

    func goBack() {
        switch currentStep {
        case .audience:
            break
        case .mode:
            currentStep = .audience
        case .shortlist:
            currentStep = .mode
        }
    }

    func lockPick(_ movie: Movie) {
        lockedPick = movie
    }

    private func generateShortlist() {
        var pool = eligibleMovies
        switch selectedMode {
        case .under2Hours:
            pool = pool.filter { ($0.runtimeMinutes ?? 999) < 120 }
        case .highlyRated:
            pool = pool.filter { ($0.aggregateRating ?? 0) >= 3.5 }
        case .watchlistDraw, .wildCard, .none:
            break
        }
        shortlist = Array(pool.shuffled().prefix(7))
    }
}
