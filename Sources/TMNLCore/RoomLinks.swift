import Foundation

public enum RoomLinks {
    /// A link created and supplied by a participant in FaceTime; no call creation API.
    public static func faceTime(_ text: String) -> URL? {
        guard let url = URL(string: text), url.scheme == "https", url.host == "facetime.apple.com",
              url.user == nil, url.password == nil, url.port == nil, !url.path.isEmpty, url.path != "/" else { return nil }
        return url
    }
    /// Regional service search links, not claims about title availability or playback APIs.
    public static func watchSearch(title: String, region: String) -> [(name: String, url: URL)] {
        let country = region.lowercased()
        guard country.count == 2, country.allSatisfy({ $0.isASCII && $0.isLetter }) else { return [] }
        let justWatchCountry = country == "gb" ? "uk" : country
        var justWatch = URLComponents(string: "https://www.justwatch.com/\(justWatchCountry)/search")!
        justWatch.queryItems = [URLQueryItem(name: "q", value: title)]
        var apple = URLComponents(string: "https://tv.apple.com/\(country)/search")!
        apple.queryItems = [URLQueryItem(name: "term", value: title)]
        return [("JustWatch · \(region.uppercased())", justWatch.url!), ("Apple TV · \(region.uppercased())", apple.url!)]
    }
}
