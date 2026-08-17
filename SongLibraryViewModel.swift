import Foundation

/// Small UIKit-friendly library store. The view controller asks it for data and reloads.
final class SongLibraryViewModel {
    private(set) var recentSongs: [StoredSong] = []
    private(set) var openSongs: [Song] = []
    private let parser = SBPParser()
    private let storage = StorageManager()

    init() { recentSongs = storage.load() }
    var favorites: [StoredSong] { recentSongs.filter(\.isFavorite) }

    func open(url: URL) throws -> [Song] {
        guard url.pathExtension.lowercased() == "sbp" else { throw SBPLibraryError.wrongFileType }
        let accessing = url.startAccessingSecurityScopedResource(); defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        let songs = try parser.parseSongs(url: url)
        openSongs.removeAll { $0.sourceURL?.standardizedFileURL == url.standardizedFileURL }
        openSongs.append(contentsOf: songs)
        recentSongs = storage.record(url: url, favorites: recentSongs)
        return songs
    }

    func reopen(_ item: StoredSong) throws -> [Song] { guard let url = storage.resolve(item), FileManager.default.fileExists(atPath: url.path) else { throw SBPLibraryError.missingRecentFile }; return try open(url: url) }
    func toggleFavorite(_ item: StoredSong) { guard let index = recentSongs.firstIndex(of: item) else { return }; recentSongs[index].isFavorite.toggle(); storage.save(recentSongs) }
    func close(_ song: Song) { openSongs.removeAll { $0.id == song.id } }
}

enum SBPLibraryError: LocalizedError {
    case wrongFileType, missingRecentFile
    var errorDescription: String? { switch self { case .wrongFileType: return "Bitte wähle eine SongBookPro-Datei mit der Endung .sbp."; case .missingRecentFile: return "Die zuletzt geöffnete Datei ist nicht mehr verfügbar." } }
}
