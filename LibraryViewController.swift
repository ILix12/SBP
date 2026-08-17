import UIKit

/// One simple table shows active songs, favourites and recent imports.
final class LibraryViewController: UITableViewController, UIDocumentPickerDelegate {
    private let library = SongLibraryViewModel()

    init() { super.init(style: .grouped) }
    required init?(coder: NSCoder) { fatalError("This app does not use storyboards.") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "OpenSongBook"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "SongCell")
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Song öffnen", style: .plain, target: self, action: #selector(openDocument))
        if #available(iOS 13.0, *) { tableView.backgroundColor = .systemGroupedBackground }
    }

    override func viewWillAppear(_ animated: Bool) { super.viewWillAppear(animated); tableView.reloadData() }

    @objc private func openDocument() {
        // The custom UTI is declared in Info.plist. Validation is repeated on import.
        let picker = UIDocumentPickerViewController(documentTypes: ["com.opensongbook.sbp"], in: .import)
        picker.delegate = self
        picker.allowsMultipleSelection = true
        present(picker, animated: true)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        var firstSong: Song?
        for url in urls {
            do { let songs = try library.open(url: url); if firstSong == nil { firstSong = songs.first } }
            catch { show(error) }
        }
        tableView.reloadData()
        if let song = firstSong { navigationController?.pushViewController(SongReaderViewController(song: song), animated: true) }
    }

    override func numberOfSections(in tableView: UITableView) -> Int { 3 }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section { case 0: return library.openSongs.count; case 1: return library.favorites.count; default: return library.recentSongs.count }
    }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section { case 0: return "Geöffnet"; case 1: return library.favorites.isEmpty ? nil : "Favoriten"; default: return library.recentSongs.isEmpty ? nil : "Zuletzt geöffnet" }
    }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SongCell", for: indexPath)
        let title: String; let detail: String; var favorite = false
        if indexPath.section == 0 { let song = library.openSongs[indexPath.row]; title = song.title; detail = song.artist }
        else { let stored = indexPath.section == 1 ? library.favorites[indexPath.row] : library.recentSongs[indexPath.row]; title = stored.displayName; detail = ""; favorite = stored.isFavorite }
        cell.textLabel?.text = title
        cell.detailTextLabel?.text = detail
        cell.accessoryType = favorite ? .detailButton : .disclosureIndicator
        return cell
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        do {
            if indexPath.section == 0 { navigationController?.pushViewController(SongReaderViewController(song: library.openSongs[indexPath.row]), animated: true); return }
            let item = indexPath.section == 1 ? library.favorites[indexPath.row] : library.recentSongs[indexPath.row]
            if let song = try library.reopen(item).first { tableView.reloadData(); navigationController?.pushViewController(SongReaderViewController(song: song), animated: true) }
        } catch { show(error) }
    }
    override func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        guard indexPath.section > 0 else { return }
        library.toggleFavorite(indexPath.section == 1 ? library.favorites[indexPath.row] : library.recentSongs[indexPath.row])
        tableView.reloadData()
    }

    private func show(_ error: Error) {
        let alert = UIAlertController(title: "Datei konnte nicht geöffnet werden", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default)); present(alert, animated: true)
    }
}
