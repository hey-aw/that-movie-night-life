import Testing
@testable import TMNLCore

struct MovieTests {
    @Test
    func letterboxdReviewURLPrefersWatchURL() {
        let movie = fixtureMovie(
            number: 1,
            slug: "the-fan-1982",
            title: "The Fan",
            year: 1982
        )

        #expect(movie.letterboxdReviewURLValue?.absoluteString == "https://letterboxd.com/film/the-fan-1982/watch/")
    }

    @Test
    func letterboxdReviewURLFallsBackToFilmPage() {
        let movie = Movie(
            number: 1,
            slug: "the-fan-1982",
            title: "The Fan",
            year: 1982,
            displayName: "The Fan (1982)",
            letterboxdURL: "https://letterboxd.com/film/the-fan-1982/",
            watchURL: "not a valid url",
            posterURL: nil,
            aggregateRating: nil,
            ratingCount: nil,
            genres: [],
            tmdbMovieID: nil,
            runtimeMinutes: nil,
            certification: nil,
            backdropURL: nil
        )

        #expect(movie.letterboxdReviewURLValue?.absoluteString == "https://letterboxd.com/film/the-fan-1982/")
    }
}
