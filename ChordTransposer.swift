import Foundation

/// Transposes chord symbols without changing their quality (for example `Cmaj7`,
/// `F#sus4` and the bass note in `G/B`). Invalid or non-musical labels pass through.
enum ChordTransposer {
    private static let sharpNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    private static let flatNames  = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]
    private static let semitones: [String: Int] = ["C": 0, "B#": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "Fb": 4, "F": 5, "E#": 5, "F#": 6, "Gb": 6, "G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11, "Cb": 11]

    static func transpose(_ chord: String, by steps: Int) -> String {
        guard steps != 0 else { return chord }
        let parts = chord.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false)
        let rootAndQuality = transposeRoot(String(parts[0]), by: steps)
        guard parts.count == 2 else { return rootAndQuality }
        return rootAndQuality + "/" + transposeRoot(String(parts[1]), by: steps)
    }

    private static func transposeRoot(_ value: String, by steps: Int) -> String {
        guard let first = value.first, ("A"..."G").contains(first) else { return value }
        var root = String(first)
        var suffix = String(value.dropFirst())
        if let accidental = suffix.first, accidental == "#" || accidental == "b" { root.append(accidental); suffix.removeFirst() }
        guard let original = semitones[root] else { return value }
        let index = (original + (steps % 12) + 12) % 12
        // Retain flats when the original spelling uses a flat; otherwise favour sharps.
        return (root.contains("b") ? flatNames : sharpNames)[index] + suffix
    }
}
