import Foundation

/// The parsed, portable representation of one SongBookPro song.
struct Song: Identifiable, Codable, Equatable {
    var id: UUID
    var sourceURL: URL?
    var title: String
    var artist: String
    var key: String
    var tempo: String
    var capo: String
    var comment: String
    var lines: [SongLine]

    init(id: UUID = UUID(), sourceURL: URL? = nil, title: String = "Ohne Titel", artist: String = "", key: String = "", tempo: String = "", capo: String = "", comment: String = "", lines: [SongLine] = []) {
        self.id = id; self.sourceURL = sourceURL; self.title = title; self.artist = artist
        self.key = key; self.tempo = tempo; self.capo = capo; self.comment = comment; self.lines = lines
    }

    var searchableText: String { ([title, artist, key, comment] + lines.map(\.lyrics)).joined(separator: " ") }
    var allChords: [String] { Array(Set(lines.flatMap { $0.chords.map(\.name) })).sorted() }
}

/// A lyric line and chords positioned by their character offset in the original lyric text.
struct SongLine: Identifiable, Codable, Equatable {
    var id = UUID()
    var lyrics: String
    var chords: [PositionedChord]
    var isSection: Bool

    init(lyrics: String, chords: [PositionedChord] = [], isSection: Bool = false) {
        self.lyrics = lyrics; self.chords = chords; self.isSection = isSection
    }
}

struct PositionedChord: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var offset: Int
}

/// A compact stored reference. Files are re-parsed upon selection from the recent list.
struct StoredSong: Identifiable, Codable, Equatable {
    var id: UUID
    var bookmark: Data?
    var path: String
    var displayName: String
    var lastOpened: Date
    var isFavorite: Bool
}
