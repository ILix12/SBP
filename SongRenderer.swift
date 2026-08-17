import SwiftUI

struct SongRenderer: View {
    let song: Song
    let query: String
    let chordQuery: String
    let fontSize: CGFloat
    let transposition: Int

    var body: some View {
        LazyVStack(alignment: .leading, spacing: fontSize * 0.48) {
            ForEach(song.lines) { line in
                Group {
                    if shouldShow(line) {
                        if line.isSection {
                            Text(line.lyrics)
                                .font(.system(size: fontSize * 0.92, weight: .bold))
                                .foregroundColor(.secondary)
                                .padding(.top, fontSize * 0.45)
                        } else {
                            ChordRenderer(line: line, fontSize: fontSize, transposition: transposition)
                        }
                    }
                }
                .id(line.id)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func shouldShow(_ line: SongLine) -> Bool {
        let textMatch = query.isEmpty || line.lyrics.localizedCaseInsensitiveContains(query)
        let chordMatch = chordQuery.isEmpty || line.chords.contains { $0.name.localizedCaseInsensitiveContains(chordQuery) }
        return textMatch && chordMatch
    }
}
