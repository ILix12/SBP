import SwiftUI

struct SongReaderView: View {
    let song: Song
    @State private var textQuery = ""
    @State private var chordQuery = ""
    @State private var showsChordSearch = false
    @State private var baseFontSize: CGFloat = 22
    @State private var zoom: CGFloat = 1
    @State private var lineIndex = 0
    @State private var transposition = 0
    @StateObject private var autoScroll = AutoScrollManager()

    private var effectiveFontSize: CGFloat { min(max(baseFontSize * zoom, 14), 52) }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 14) {
                    metadata
                    Divider()
                    SongRenderer(song: song, query: textQuery, chordQuery: chordQuery, fontSize: effectiveFontSize, transposition: transposition)
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
                .id("song-top")
                .gesture(MagnificationGesture().onChanged { value in zoom = value }.onEnded { value in baseFontSize = min(max(baseFontSize * value, 14), 52); zoom = 1 })
            }
            .searchable(text: $textQuery, prompt: "Im Songtext suchen")
            .navigationTitle(song.title)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button { showsChordSearch.toggle() } label: { Image(systemName: chordQuery.isEmpty ? "guitars" : "line.3.horizontal.decrease.circle.fill") }.accessibilityLabel("Nach Akkorden suchen")
                    Button { autoScroll.toggle { scrollNext(proxy) } } label: { Image(systemName: autoScroll.isRunning ? "pause.fill" : "play.fill") }.accessibilityLabel(autoScroll.isRunning ? "AutoScroll anhalten" : "AutoScroll starten")
                }
            }
            .onDisappear { autoScroll.stop() }
        }
    }

    private var metadata: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !song.artist.isEmpty { Text(song.artist).font(.title3).foregroundColor(.secondary) }
            HStack(spacing: 14) { if !song.tempo.isEmpty { Label("\(song.tempo) BPM", systemImage: "metronome") }; if !song.capo.isEmpty { Label("Capo \(song.capo)", systemImage: "guitars") } }.font(.subheadline)
            if !song.key.isEmpty {
                HStack(spacing: 10) {
                    Label("Tonart", systemImage: "music.note")
                    Button { transposition -= 1 } label: { Image(systemName: "minus.circle.fill") }
                    Text(ChordTransposer.transpose(song.key, by: transposition)).font(.headline).monospacedDigit().frame(minWidth: 42)
                    Button { transposition += 1 } label: { Image(systemName: "plus.circle.fill") }
                    if transposition != 0 { Button("Original") { transposition = 0 }.font(.caption) }
                }
                .buttonStyle(.borderless)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Tonart \(ChordTransposer.transpose(song.key, by: transposition))")
            }
            if !song.comment.isEmpty { Text(song.comment).font(.callout).italic().foregroundColor(.secondary) }
            if showsChordSearch {
                HStack { TextField("Akkord suchen, z. B. Am", text: $chordQuery).textFieldStyle(.roundedBorder); if !chordQuery.isEmpty { Button("Löschen") { chordQuery = "" } } }
            }
            HStack { Text("Schriftgröße"); Slider(value: Binding(get: { Double(baseFontSize) }, set: { baseFontSize = CGFloat($0) }), in: 14...36); Text("\(Int(effectiveFontSize)) pt").monospacedDigit() }
            HStack { Text("AutoScroll"); Slider(value: $autoScroll.secondsPerLine, in: 0.35...2.0, step: 0.05); Text("\(autoScroll.secondsPerLine, specifier: "%.2f") s").monospacedDigit() }
        }
    }

    private func scrollNext(_ proxy: ScrollViewProxy) {
        // One step per tick keeps auto-scroll stable across portrait and landscape.
        guard !song.lines.isEmpty else { return }
        lineIndex = min(lineIndex + 1, song.lines.count - 1)
        withAnimation(.linear(duration: autoScroll.secondsPerLine)) { proxy.scrollTo(song.lines[lineIndex].id, anchor: .top) }
        if lineIndex == song.lines.count - 1 { autoScroll.stop() }
    }
}
