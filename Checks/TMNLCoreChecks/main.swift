import Foundation
import TMNLCore

@main
enum TMNLCoreChecks {
    static func main() throws {
        let catalog = try BundledMovieCatalog.load()
        guard !catalog.isEmpty else {
            throw NSError(domain: "TMNLCoreChecks", code: 1, userInfo: [NSLocalizedDescriptionKey: "Bundled catalog is empty"])
        }

        print("Loaded \(catalog.count) movies")
        print("First movie: #\(catalog.first!.number) \(catalog.first!.displayName)")
        print("Last movie: #\(catalog.last!.number) \(catalog.last!.displayName)")
    }
}
