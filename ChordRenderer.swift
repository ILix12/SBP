import SwiftUI

/// Renders chord labels above their matching lyric character using a monospaced grid.
struct ChordRenderer: View {
    let line: SongLine
    let fontSize: CGFloat
    let transposition: Int

    var body: some View {
        GeometryReader { geometry in
            // A monospace font has a predictable character width. Scaling the line
            // before rendering keeps chords precisely above lyrics in portrait and landscape.
            let displaySize = fittingFontSize(for: geometry.size.width)
            let characterWidth = displaySize * 0.61
            VStack(alignment: .leading, spacing: 1) {
                ZStack(alignment: .topLeading) {
                    Color.clear.frame(height: line.chords.isEmpty ? 0 : displaySize * 1.25)
                    ForEach(line.chords) { chord in
                        Text(ChordTransposer.transpose(chord.name, by: transposition))
                            .font(.system(size: displaySize * 0.78, weight: .semibold, design: .monospaced))
                            .foregroundColor(.accentColor)
                            .fixedSize()
                            .offset(x: CGFloat(chord.offset) * characterWidth)
                    }
                }
                Text(line.lyrics.isEmpty ? " " : line.lyrics)
                    .font(.system(size: displaySize, design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.35)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(height: line.chords.isEmpty ? fontSize * 1.35 : fontSize * 2.6)
        .clipped()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(line.chords.map { ChordTransposer.transpose($0.name, by: transposition) }.joined(separator: ", ")) \(line.lyrics)")
    }

    private func fittingFontSize(for availableWidth: CGFloat) -> CGFloat {
        let chordColumns = line.chords.map { $0.offset + ChordTransposer.transpose($0.name, by: transposition).count }.max() ?? 0
        let requiredColumns = max(line.lyrics.count, chordColumns)
        guard requiredColumns > 0 else { return fontSize }
        let requiredWidth = CGFloat(requiredColumns) * fontSize * 0.61
        // Preserve the reader's chosen size unless this particular line needs to shrink.
        return max(10, min(fontSize, fontSize * availableWidth / max(requiredWidth, 1)))
    }
}
