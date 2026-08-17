import Compression
import Foundation

enum SBPArchiveError: LocalizedError {
    case invalidArchive, missingDataFile, unsupportedCompression, corruptData
    var errorDescription: String? {
        switch self {
        case .invalidArchive: return "Die .sbp-Datei ist kein gültiges SongBookPro-Archiv."
        case .missingDataFile: return "Die SongBookPro-Datei enthält keine dataFile.txt."
        case .unsupportedCompression: return "Die SongBookPro-Datei verwendet eine nicht unterstützte ZIP-Komprimierung."
        case .corruptData: return "Die SongBookPro-Datei ist beschädigt."
        }
    }
}

/// Minimal ZIP reader for SongBookPro set exports. It reads the `dataFile.txt`
/// database entry and supports both standard ZIP storage and raw DEFLATE.
struct SBPArchiveReader {
    private static let centralSignature: UInt32 = 0x02014B50
    private static let localSignature: UInt32 = 0x04034B50
    private static let maximumSize = 50 * 1024 * 1024

    static func dataFile(from archive: Data) throws -> Data {
        let bytes = [UInt8](archive)
        guard bytes.count >= 46 else { throw SBPArchiveError.invalidArchive }
        var offset = 0
        while offset + 46 <= bytes.count {
            guard uint32(bytes, at: offset) == centralSignature else { offset += 1; continue }
            guard let method = uint16(bytes, at: offset + 10), let compressedSize = uint32(bytes, at: offset + 20), let uncompressedSize = uint32(bytes, at: offset + 24), let nameLength = uint16(bytes, at: offset + 28), let extraLength = uint16(bytes, at: offset + 30), let commentLength = uint16(bytes, at: offset + 32), let localOffset = uint32(bytes, at: offset + 42) else { throw SBPArchiveError.corruptData }
            let nameStart = offset + 46; let nameEnd = nameStart + Int(nameLength)
            guard nameEnd <= bytes.count else { throw SBPArchiveError.corruptData }
            let next = nameEnd + Int(extraLength) + Int(commentLength)
            guard next <= bytes.count else { throw SBPArchiveError.corruptData }
            if String(bytes: bytes[nameStart..<nameEnd], encoding: .utf8)?.lowercased() == "datafile.txt" {
                return try extract(bytes: bytes, localOffset: Int(localOffset), method: method, compressedSize: Int(compressedSize), uncompressedSize: Int(uncompressedSize))
            }
            offset = next
        }
        throw SBPArchiveError.missingDataFile
    }

    private static func extract(bytes: [UInt8], localOffset: Int, method: UInt16, compressedSize: Int, uncompressedSize: Int) throws -> Data {
        guard localOffset + 30 <= bytes.count, uint32(bytes, at: localOffset) == localSignature, let nameLength = uint16(bytes, at: localOffset + 26), let extraLength = uint16(bytes, at: localOffset + 28), uncompressedSize <= maximumSize else { throw SBPArchiveError.corruptData }
        let start = localOffset + 30 + Int(nameLength) + Int(extraLength); let end = start + compressedSize
        guard start >= 0, end <= bytes.count else { throw SBPArchiveError.corruptData }
        let compressed = Data(bytes[start..<end])
        switch method { case 0: return compressed; case 8: return try inflate(compressed, expectedSize: uncompressedSize); default: throw SBPArchiveError.unsupportedCompression }
    }

    private static func inflate(_ data: Data, expectedSize: Int) throws -> Data {
        guard expectedSize > 0 else { return Data() }
        var output = [UInt8](repeating: 0, count: expectedSize)
        let count = output.withUnsafeMutableBufferPointer { destination in data.withUnsafeBytes { source -> Int in
            guard let destinationAddress = destination.baseAddress, let sourceAddress = source.bindMemory(to: UInt8.self).baseAddress else { return 0 }
            return compression_decode_buffer(destinationAddress, destination.count, sourceAddress, source.count, nil, COMPRESSION_ZLIB)
        } }
        guard count == expectedSize else { throw SBPArchiveError.corruptData }
        return Data(output)
    }

    private static func uint16(_ bytes: [UInt8], at offset: Int) -> UInt16? { guard offset >= 0, offset + 2 <= bytes.count else { return nil }; return UInt16(bytes[offset]) | UInt16(bytes[offset + 1]) << 8 }
    private static func uint32(_ bytes: [UInt8], at offset: Int) -> UInt32? { guard offset >= 0, offset + 4 <= bytes.count else { return nil }; return UInt32(bytes[offset]) | UInt32(bytes[offset + 1]) << 8 | UInt32(bytes[offset + 2]) << 16 | UInt32(bytes[offset + 3]) << 24 }
}
