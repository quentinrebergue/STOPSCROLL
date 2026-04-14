import Foundation
import Compression

struct MiniZIP {
    private struct Entry {
        let filename: String
        let method: UInt16
        let compressedSize: Int
        let uncompressedSize: Int
        let localHeaderOffset: Int
    }

    static func extract(from data: Data) -> [String: Data]? {
        guard let eocdOffset = findEOCD(in: data) else { return nil }

        let centralDirOffset = Int(read32(data, at: eocdOffset + 16))
        let entryCount = Int(read16(data, at: eocdOffset + 10))
        let entries = parseCentralDirectory(data, offset: centralDirOffset, count: entryCount)

        var result: [String: Data] = [:]

        for entry in entries {
            guard entry.localHeaderOffset + 30 <= data.count else { continue }

            let localNameLen = Int(read16(data, at: entry.localHeaderOffset + 26))
            let localExtraLen = Int(read16(data, at: entry.localHeaderOffset + 28))
            let dataOffset = entry.localHeaderOffset + 30 + localNameLen + localExtraLen

            guard dataOffset + entry.compressedSize <= data.count else { continue }
            let fileData = Data(data[dataOffset..<dataOffset + entry.compressedSize])

            if entry.method == 0 {
                result[entry.filename] = fileData
            } else if entry.method == 8 {
                if let decompressed = decompressDeflate(fileData, expectedSize: entry.uncompressedSize) {
                    result[entry.filename] = decompressed
                }
            }
        }

        return result.isEmpty ? nil : result
    }

    private static func findEOCD(in data: Data) -> Int? {
        let searchStart = max(0, data.count - 65558)
        for i in stride(from: data.count - 22, through: searchStart, by: -1) {
            if data[i] == 0x50, data[i + 1] == 0x4B, data[i + 2] == 0x05, data[i + 3] == 0x06 {
                return i
            }
        }
        return nil
    }

    private static func parseCentralDirectory(_ data: Data, offset: Int, count: Int) -> [Entry] {
        var entries: [Entry] = []
        var pos = offset

        for _ in 0..<count {
            guard pos + 46 <= data.count else { break }
            guard data[pos] == 0x50, data[pos + 1] == 0x4B,
                  data[pos + 2] == 0x01, data[pos + 3] == 0x02 else { break }

            let method = read16(data, at: pos + 10)
            let compSize = Int(read32(data, at: pos + 20))
            let uncompSize = Int(read32(data, at: pos + 24))
            let nameLen = Int(read16(data, at: pos + 28))
            let extraLen = Int(read16(data, at: pos + 30))
            let commentLen = Int(read16(data, at: pos + 32))
            let localOffset = Int(read32(data, at: pos + 42))

            let nameStart = pos + 46
            guard nameStart + nameLen <= data.count else { break }
            let name = String(data: data[nameStart..<nameStart + nameLen], encoding: .utf8) ?? ""

            if !name.hasSuffix("/") {
                entries.append(
                    Entry(
                        filename: name,
                        method: method,
                        compressedSize: compSize,
                        uncompressedSize: uncompSize,
                        localHeaderOffset: localOffset
                    )
                )
            }

            pos = nameStart + nameLen + extraLen + commentLen
        }

        return entries
    }

    private static func decompressDeflate(_ data: Data, expectedSize: Int) -> Data? {
        guard expectedSize > 0 else { return Data() }
        let bufferSize = expectedSize + 4096
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        var decoded = data.withUnsafeBytes { srcPtr -> Int in
            guard let src = srcPtr.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return 0 }
            return compression_decode_buffer(buffer, bufferSize, src, data.count, nil, COMPRESSION_ZLIB)
        }

        if decoded <= 0 {
            var zlibData = Data([0x78, 0x01])
            zlibData.append(data)
            decoded = zlibData.withUnsafeBytes { srcPtr -> Int in
                guard let src = srcPtr.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return 0 }
                return compression_decode_buffer(buffer, bufferSize, src, zlibData.count, nil, COMPRESSION_ZLIB)
            }
        }

        guard decoded > 0 else { return nil }
        return Data(bytes: buffer, count: decoded)
    }

    private static func read16(_ data: Data, at offset: Int) -> UInt16 {
        UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
    }

    private static func read32(_ data: Data, at offset: Int) -> UInt32 {
        UInt32(data[offset]) | (UInt32(data[offset + 1]) << 8)
            | (UInt32(data[offset + 2]) << 16) | (UInt32(data[offset + 3]) << 24)
    }
}
