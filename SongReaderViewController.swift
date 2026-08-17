import UIKit

/// UIKit reader for iPadOS 12. Each table row contains one chord line and lyric line.
final class SongReaderViewController: UITableViewController {
    private let song: Song
    private let autoScroll = AutoScrollManager()
    private var transposition = 0
    private var fontSize: CGFloat = 24
    private var visibleLines: [SongLine] { song.lines }

    init(song: Song) { self.song = song; super.init(style: .plain) }
    required init?(coder: NSCoder) { fatalError("This app does not use storyboards.") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = song.title
        tableView.register(SongLineCell.self, forCellReuseIdentifier: "LineCell")
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 68
        tableView.separatorStyle = .none
        tableView.tableHeaderView = makeHeader()
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(title: "Auto", style: .plain, target: self, action: #selector(toggleAutoScroll)),
            UIBarButtonItem(title: "−", style: .plain, target: self, action: #selector(lowerKey)),
            UIBarButtonItem(title: "+", style: .plain, target: self, action: #selector(raiseKey))
        ]
        tableView.addGestureRecognizer(UIPinchGestureRecognizer(target: self, action: #selector(zoom(_:))))
    }
    override func viewDidDisappear(_ animated: Bool) { super.viewDidDisappear(animated); autoScroll.stop() }

    private func makeHeader() -> UIView {
        let header = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 104))
        let titleLabel = UILabel(); titleLabel.text = song.title; titleLabel.font = .preferredFont(forTextStyle: .title2); titleLabel.numberOfLines = 2
        let details = UILabel(); details.font = .preferredFont(forTextStyle: .subheadline); details.textColor = .darkGray
        details.text = [song.artist, song.key.isEmpty ? nil : "Tonart: \(ChordTransposer.transpose(song.key, by: transposition))", song.tempo.isEmpty ? nil : "\(song.tempo) BPM", song.capo.isEmpty ? nil : "Capo \(song.capo)"].compactMap { $0 }.joined(separator: "  •  ")
        let stack = UIStackView(arrangedSubviews: [titleLabel, details]); stack.axis = .vertical; stack.spacing = 6; stack.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 20), stack.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -20), stack.topAnchor.constraint(equalTo: header.topAnchor, constant: 14)])
        return header
    }
    private func refresh() { tableView.tableHeaderView = makeHeader(); tableView.reloadData() }

    @objc private func lowerKey() { transposition -= 1; refresh() }
    @objc private func raiseKey() { transposition += 1; refresh() }
    @objc private func zoom(_ pinch: UIPinchGestureRecognizer) {
        guard pinch.state == .ended else { return }
        fontSize = min(44, max(14, fontSize * pinch.scale)); refresh()
    }
    @objc private func toggleAutoScroll() {
        autoScroll.toggle { [weak self] in self?.scrollOneLine() }
        navigationItem.rightBarButtonItems?.first?.title = autoScroll.isRunning ? "Stopp" : "Auto"
    }
    private func scrollOneLine() {
        guard let path = tableView.indexPathsForVisibleRows?.last, path.row + 1 < visibleLines.count else { autoScroll.stop(); return }
        tableView.scrollToRow(at: IndexPath(row: path.row + 1, section: 0), at: .top, animated: true)
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { visibleLines.count }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "LineCell", for: indexPath) as! SongLineCell
        cell.configure(line: visibleLines[indexPath.row], fontSize: fontSize, transposition: transposition)
        return cell
    }
}

private final class SongLineCell: UITableViewCell {
    private let chords = UILabel(); private let lyrics = UILabel()
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        chords.textColor = .blue; [chords, lyrics].forEach { $0.font = .monospacedSystemFont(ofSize: 24, weight: .regular); $0.numberOfLines = 1; $0.adjustsFontSizeToFitWidth = true; $0.minimumScaleFactor = 0.35; $0.translatesAutoresizingMaskIntoConstraints = false; contentView.addSubview($0) }
        NSLayoutConstraint.activate([chords.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor), chords.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor), chords.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 5), lyrics.leadingAnchor.constraint(equalTo: chords.leadingAnchor), lyrics.trailingAnchor.constraint(equalTo: chords.trailingAnchor), lyrics.topAnchor.constraint(equalTo: chords.bottomAnchor, constant: 1), lyrics.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -5)])
    }
    required init?(coder: NSCoder) { fatalError("No storyboard") }
    func configure(line: SongLine, fontSize: CGFloat, transposition: Int) {
        if line.isSection { chords.text = ""; lyrics.text = line.lyrics; lyrics.font = .systemFont(ofSize: fontSize, weight: .bold); return }
        var chordLine = ""
        for chord in line.chords { while chordLine.count < chord.offset { chordLine.append(" ") }; chordLine += ChordTransposer.transpose(chord.name, by: transposition) }
        chords.text = chordLine; lyrics.text = line.lyrics.isEmpty ? " " : line.lyrics
        chords.font = .monospacedSystemFont(ofSize: fontSize * 0.78, weight: .semibold); lyrics.font = .monospacedSystemFont(ofSize: fontSize, weight: .regular)
    }
}
