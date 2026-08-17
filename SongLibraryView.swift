import SwiftUI

struct SongLibraryView: View {
    @EnvironmentObject private var library: SongLibraryViewModel
    @State private var showsPicker = false

    var body: some View {
        NavigationView {
            List {
                Section {
                    Button { showsPicker = true } label: { Label("Song öffnen", systemImage: "folder.badge.plus") }
                }
                if !library.openSongs.isEmpty {
                    Section("Geöffnet") {
                        ForEach(library.openSongs) { song in
                            Button { library.selectedSongID = song.id } label: {
                                HStack { VStack(alignment: .leading) { Text(song.title); if !song.artist.isEmpty { Text(song.artist).font(.caption).foregroundColor(.secondary) } }; Spacer(); if library.selectedSongID == song.id { Image(systemName: "checkmark") } }
                            }
                            .contextMenu { Button(role: .destructive) { library.close(song) } label: { Label("Schließen", systemImage: "xmark") } }
                        }
                    }
                }
                if !library.favorites.isEmpty {
                    Section("Favoriten") {
                        ForEach(library.favorites) { item in recentRow(item) }
                    }
                }
                if !library.recentSongs.isEmpty {
                    Section("Zuletzt geöffnet") {
                        ForEach(library.recentSongs) { item in recentRow(item) }
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("OpenSongBook")
            .sheet(isPresented: $showsPicker) { SongDocumentPicker(onPick: { library.open(url: $0); showsPicker = false }, onCancel: { showsPicker = false }) }
            .alert("Datei konnte nicht geöffnet werden", isPresented: Binding(get: { library.errorMessage != nil }, set: { if !$0 { library.errorMessage = nil } })) { Button("OK", role: .cancel) { library.errorMessage = nil } } message: { Text(library.errorMessage ?? "") }

            Group {
                if let song = library.selectedSong { SongReaderView(song: song) }
                else {
                    VStack(spacing: 12) {
                        Image(systemName: "music.note.list").font(.system(size: 48)).foregroundColor(.secondary)
                        Text("Kein Song geöffnet").font(.title2)
                        Text("Tippe auf „Song öffnen“, um eine .sbp-Datei auszuwählen.").foregroundColor(.secondary)
                    }
                }
            }
        }
        // Explicit type works on iPadOS 15, unlike the newer `.doubleColumn` shorthand.
        .navigationViewStyle(DoubleColumnNavigationViewStyle())
    }

    @ViewBuilder private func recentRow(_ item: StoredSong) -> some View {
        HStack {
            Button { library.reopen(item) } label: { Text(item.displayName).lineLimit(1) }
            Spacer()
            Button { library.toggleFavorite(item) } label: { Image(systemName: item.isFavorite ? "star.fill" : "star") }.buttonStyle(.borderless).accessibilityLabel(item.isFavorite ? "Aus Favoriten entfernen" : "Zu Favoriten hinzufügen")
        }
    }
}
