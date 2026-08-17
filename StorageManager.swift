import Foundation

/// Persists recent-file security bookmarks and favorite state in UserDefaults.
final class StorageManager {
    private let key = "OpenSongBook.StoredSongs.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func load() -> [StoredSong] {
        guard let data = defaults.data(forKey: key), let songs = try? JSONDecoder().decode([StoredSong].self, from: data) else { return [] }
        return songs.sorted { $0.lastOpened > $1.lastOpened }
    }

    func save(_ songs: [StoredSong]) {
        guard let data = try? JSONEncoder().encode(songs) else { return }
        defaults.set(data, forKey: key)
    }

    func record(url: URL, favorites: [StoredSong]) -> [StoredSong] {
        let bookmark = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        var items = favorites.filter { $0.path != url.path }
        let old = favorites.first { $0.path == url.path }
        items.insert(StoredSong(id: old?.id ?? UUID(), bookmark: bookmark, path: url.path, displayName: url.deletingPathExtension().lastPathComponent, lastOpened: Date(), isFavorite: old?.isFavorite ?? false), at: 0)
        let capped = Array(items.prefix(30)); save(capped); return capped
    }

    func resolve(_ item: StoredSong) -> URL? {
        if let bookmark = item.bookmark {
            var stale = false
            if let url = try? URL(resolvingBookmarkData: bookmark, options: [], relativeTo: nil, bookmarkDataIsStale: &stale) { return url }
        }
        return URL(fileURLWithPath: item.path)
    }
}
