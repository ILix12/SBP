import Foundation

enum SBPParserError: LocalizedError {
    case emptyFile
    case unreadableText
    case noSongs

    var errorDescription: String? {
        switch self { case .emptyFile: return "Die Datei ist leer."; case .unreadableText: return "Die Datei ist weder UTF-8 noch ISO-8859-1-kodiert."; case .noSongs: return "Die SongBookPro-Datei enthält keine lesbaren Songs." }
    }
}

/// A defensive parser for common SongBookPro/ChordPro-style SBP text. Malformed input
/// becomes plain lyrics; no line is force-unwrapped or indexed unsafely.
struct SBPParser {
    func parse(url: URL) throws -> Song {
        guard let first = (try parseSongs(url: url)).first else { throw SBPParserError.noSongs }
        return first
    }

    /// Parses plain ChordPro-like text and native SongBookPro ZIP set exports.
    func parseSongs(url: URL) throws -> [Song] {
        let data = try Data(contentsOf: url)
        guard !data.isEmpty else { throw SBPParserError.emptyFile }
        if data.starts(with: [0x50, 0x4B]) { return try parseSongBookProArchive(data, sourceURL: url) }
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else { throw SBPParserError.unreadableText }
        return [parse(text: text, sourceURL: url)]
    }

    private func parseSongBookProArchive(_ data: Data, sourceURL: URL) throws -> [Song] {
        let database = try SBPArchiveReader.dataFile(from: data)
        guard let text = String(data: database, encoding: .utf8) ?? String(data: database, encoding: .isoLatin1), let jsonStart = text.firstIndex(of: "{") else { throw SBPParserError.unreadableText }
        guard let object = try? JSONSerialization.jsonObject(with: Data(text[jsonStart...].utf8)), let root = object as? [String: Any], let rawSongs = value(named: "songs", in: root) as? [[String: Any]] else { throw SBPParserError.noSongs }
        let songs = rawSongs.compactMap { song(from: $0, sourceURL: sourceURL) }
        guard !songs.isEmpty else { throw SBPParserError.noSongs }
        return songs
    }

    private func song(from source: [String: Any], sourceURL: URL) -> Song? {
        if (value(named: "deleted", in: source) as? Bool) == true { return nil }
        guard let body = string(namedAnyOf: ["content", "body", "text", "lyrics", "songcontent", "chordpro", "data"], in: source), !body.isEmpty else { return nil }
        var song = parse(text: body, sourceURL: sourceURL)
        song.title = string(namedAnyOf: ["name", "title"], in: source) ?? song.title
        song.artist = string(namedAnyOf: ["author", "artist"], in: source) ?? song.artist
        song.key = string(namedAnyOf: ["key", "songkey"], in: source) ?? song.key
        song.capo = string(namedAnyOf: ["capo"], in: source) ?? song.capo
        song.tempo = string(namedAnyOf: ["tempo", "bpm"], in: source) ?? song.tempo
        return song
    }

    private func value(named name: String, in dictionary: [String: Any]) -> Any? { dictionary.first { $0.key.caseInsensitiveCompare(name) == .orderedSame }?.value }
    private func string(namedAnyOf names: [String], in dictionary: [String: Any]) -> String? {
        for name in names { if let value = value(named: name, in: dictionary) { if let text = value as? String { return text }; if let number = value as? NSNumber { return number.stringValue } } }
        return nil
    }

    func parse(text: String, sourceURL: URL? = nil) -> Song {
        var song = Song(sourceURL: sourceURL, title: sourceURL?.deletingPathExtension().lastPathComponent ?? "Ohne Titel")
        var body: [SongLine] = []
        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .newlines)
            if let metadata = metadata(in: line) {
                set(metadata.key, value: metadata.value, song: &song)
                continue
            }
            // Tag-shaped lines are directives, not lyrics. Unsupported directives are ignored.
            if (line.hasPrefix("{") && line.hasSuffix("}")) || line.hasPrefix("#") || isBracketedDirective(line) { continue }
            // Section names such as [Refrain] contain no chord; display them as headings.
            if let section = sectionName(in: line) { body.append(SongLine(lyrics: section, isSection: true)); continue }
            body.append(parseLyricLine(line))
        }
        song.lines = body
        return song
    }

    private func metadata(in line: String) -> (key: String, value: String)? {
        let candidates: [String]
        if line.hasPrefix("{") && line.hasSuffix("}") { candidates = [String(line.dropFirst().dropLast())] }
        else if line.hasPrefix("#") { candidates = [String(line.dropFirst())] }
        else { candidates = [line] }
        for candidate in candidates {
            guard let divider = candidate.firstIndex(where: { $0 == ":" || $0 == "=" }) else { continue }
            let key = candidate[..<divider].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let value = candidate[candidate.index(after: divider)...].trimmingCharacters(in: .whitespacesAndNewlines)
            if ["title", "titel", "t", "artist", "künstler", "artistname", "key", "tonart", "tempo", "bpm", "capo", "comment", "kommentar", "c"].contains(key) { return (key, value) }
        }
        return nil
    }

    private func set(_ key: String, value: String, song: inout Song) {
        switch key {
        case "title", "titel", "t": song.title = value.isEmpty ? song.title : value
        case "artist", "künstler", "artistname": song.artist = value
        case "key", "tonart": song.key = value
        case "tempo", "bpm": song.tempo = value
        case "capo": song.capo = value
        case "comment", "kommentar", "c": song.comment = value
        default: break // Future/unknown tags are intentionally ignored.
        }
    }

    private func sectionName(in line: String) -> String? {
        guard line.hasPrefix("["), line.hasSuffix("]") else { return nil }
        let value = String(line.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
        return isChord(value) ? nil : (value.isEmpty ? nil : value)
    }

    private func isBracketedDirective(_ line: String) -> Bool {
        guard line.hasPrefix("["), line.hasSuffix("]") else { return false }
        let value = line.dropFirst().dropLast()
        return value.contains(":") || value.contains("=")
    }

    private func parseLyricLine(_ line: String) -> SongLine {
        var output = ""; var chords: [PositionedChord] = []; var index = line.startIndex
        while index < line.endIndex {
            guard line[index] == "[", let closing = line[index...].firstIndex(of: "]") else { output.append(line[index]); index = line.index(after: index); continue }
            let candidate = String(line[line.index(after: index)..<closing]).trimmingCharacters(in: .whitespaces)
            if isChord(candidate) { chords.append(PositionedChord(name: candidate, offset: output.count)); index = line.index(after: closing) }
            else { output.append(line[index]); index = line.index(after: index) }
        }
        return SongLine(lyrics: output, chords: chords)
    }

    /// Accepts standard root notes plus common chord modifiers, while rejecting headings.
    private func isChord(_ text: String) -> Bool {
        let pattern = "^[A-G](#|b)?(m|maj7|maj|min|sus[24]?|dim|aug|add9|[579]|11|13|6|/[^ ]+)*$"
        return text.range(of: pattern, options: .regularExpression) != nil
    }
}
