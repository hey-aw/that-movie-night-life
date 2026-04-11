import Foundation
import ZIPFoundation

public enum WatchedImportService {
    public static func importWatchedSlugs(from url: URL, movies: [Movie]) throws -> Set<String> {
        let fileName = url.lastPathComponent.lowercased()
        if fileName.hasSuffix(".zip") {
            return try importZipArchive(from: url, movies: movies)
        }

        let csvText = try String(contentsOf: url, encoding: .utf8)
        return resolveWatchedSlugs(csvText: csvText, movies: movies)
    }

    public static func resolveWatchedSlugs(csvText: String, movies: [Movie]) -> Set<String> {
        let rows = CSVParser.parse(text: csvText)
        let movieURLMap = Dictionary(uniqueKeysWithValues: movies.map { (normalizeLetterboxdURL($0.letterboxdURL), $0.slug) })
        let movieKeyMap = Dictionary(uniqueKeysWithValues: movies.map { (normalizeMovieKey(title: $0.title, year: $0.year), $0.slug) })

        var matched: Set<String> = []
        for row in rows {
            let rawURL =
                row["letterboxd uri"] ??
                row["letterboxd url"] ??
                row["letterboxd_url"] ??
                row["url"]

            let normalizedURL = normalizeLetterboxdURL(rawURL)
            if let normalizedURL, let slug = movieURLMap[normalizedURL] {
                matched.insert(slug)
                continue
            }

            guard let title = row["name"] ?? row["title"] ?? row["film"] ?? row["film name"] else {
                continue
            }

            let year = Int((row["year"] ?? row["released"] ?? row["release year"] ?? "").trimmingCharacters(in: .whitespaces))
            let key = normalizeMovieKey(title: title, year: year)
            if let slug = movieKeyMap[key] {
                matched.insert(slug)
            }
        }
        return matched
    }

    private static func importZipArchive(from url: URL, movies: [Movie]) throws -> Set<String> {
        let archive: Archive
        do {
            archive = try Archive(url: url, accessMode: .read)
        } catch {
            throw WatchedImportError.invalidArchive
        }

        let preferredNames = ["diary.csv", "watched.csv"]
        let entry = preferredNames.compactMap { name in archive[name] }.first
            ?? archive.first(where: { $0.path.lowercased().hasSuffix(".csv") })

        guard let entry else {
            throw WatchedImportError.csvNotFound
        }

        var data = Data()
        _ = try archive.extract(entry) { chunk in
            data.append(chunk)
        }
        guard let csvText = String(data: data, encoding: .utf8) else {
            throw WatchedImportError.unreadableCSV
        }
        return resolveWatchedSlugs(csvText: csvText, movies: movies)
    }
}

public enum WatchedImportError: Error, Equatable {
    case invalidArchive
    case csvNotFound
    case unreadableCSV
}

private enum CSVParser {
    static func parse(text: String) -> [[String: String]] {
        let rows = parseRows(text: text)
        guard let headerRow = rows.first else { return [] }
        let normalizedHeaders = headerRow.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }

        return rows.dropFirst().map { row in
            Dictionary(uniqueKeysWithValues: normalizedHeaders.enumerated().map { index, header in
                (header, row[safe: index]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
            })
        }
    }

    private static func parseRows(text: String) -> [[String]] {
        var rows: [[String]] = []
        var current = ""
        var quoted = false

        for character in text {
            if character == "\"" {
                quoted.toggle()
            }

            if (character == "\n" || character == "\r") && !quoted {
                if !current.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    rows.append(parseRow(current))
                }
                current = ""
                continue
            }

            current.append(character)
        }

        if !current.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            rows.append(parseRow(current))
        }

        return rows
    }

    private static func parseRow(_ line: String) -> [String] {
        var cells: [String] = []
        var current = ""
        var quoted = false
        var index = line.startIndex

        while index < line.endIndex {
            let character = line[index]
            if character == "\"" {
                let next = line.index(after: index)
                if quoted, next < line.endIndex, line[next] == "\"" {
                    current.append("\"")
                    index = line.index(after: next)
                    continue
                }
                quoted.toggle()
                index = next
                continue
            }

            if character == "," && !quoted {
                cells.append(current)
                current = ""
                index = line.index(after: index)
                continue
            }

            current.append(character)
            index = line.index(after: index)
        }

        cells.append(current)
        return cells
    }
}

private func normalizeLetterboxdURL(_ value: String?) -> String? {
    guard let value else { return nil }
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }

    let resolved = trimmed.hasPrefix("http")
        ? URL(string: trimmed)
        : URL(string: trimmed.hasPrefix("/") ? "https://letterboxd.com\(trimmed)" : "https://letterboxd.com/\(trimmed)")

    guard let resolved else {
        return nil
    }

    let normalizedPath = resolved.path.hasSuffix("/") ? resolved.path : "\(resolved.path)/"
    return "\(resolved.scheme ?? "https")://\(resolved.host ?? "letterboxd.com")\(normalizedPath)".lowercased()
}

private func normalizeMovieKey(title: String, year: Int?) -> String {
    let normalizedTitle = title
        .lowercased()
        .replacingOccurrences(of: "&", with: "and")
        .replacingOccurrences(of: "[^a-z0-9]+", with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
    let normalizedYear = year.map(String.init) ?? ""
    return "\(normalizedTitle)::\(normalizedYear)"
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
