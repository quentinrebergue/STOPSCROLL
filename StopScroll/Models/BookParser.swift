import Foundation
import Compression

// MARK: - Reading Mode

enum ReadingMode: String, CaseIterable, Identifiable {
    case sprint = "Sprint"
    case flow = "Flow"
    case deep = "Deep"

    var id: String { rawValue }

    var charsPerCard: Int {
        switch self {
        case .sprint: return 250
        case .flow:   return 500
        case .deep:   return 750
        }
    }

    var cardsPerPage: Int {
        switch self {
        case .sprint: return 6   // ~1500 chars per page
        case .flow:   return 3   // ~1500 chars per page
        case .deep:   return 2   // ~1500 chars per page
        }
    }

    var fontSize: CGFloat {
        switch self {
        case .sprint: return 19
        case .flow:   return 17
        case .deep:   return 16
        }
    }

    var lineSpacing: CGFloat {
        switch self {
        case .sprint: return 9
        case .flow:   return 7
        case .deep:   return 6
        }
    }

    var icon: String {
        switch self {
        case .sprint: return "hare"
        case .flow:   return "figure.walk"
        case .deep:   return "tortoise"
        }
    }

    var label: String {
        switch self {
        case .sprint: return "Sprint"
        case .flow:   return "Flow"
        case .deep:   return "Deep"
        }
    }
}

// MARK: - Book Card Model

enum CardType {
    case text
    case chapterStart(title: String, chapterNumber: Int)
}

struct BookCard: Identifiable {
    let id: Int
    let text: String
    let cardNumber: Int
    let totalCards: Int
    let page: Int
    let chapter: Int
    let type: CardType
    var isBookmarked: Bool = false
}

// MARK: - Book Parser

struct BookParser {

    static func loadBook(from url: URL, mode: ReadingMode = .flow) -> (title: String, cards: [BookCard])? {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: url) else { return nil }

        let ext = url.pathExtension.lowercased()
        var chapters: [(title: String, text: String)]?

        switch ext {
        case "epub":
            chapters = EPUBParser.extractChapters(from: data)
        default:
            if let text = String(data: data, encoding: .utf8) {
                chapters = detectChapters(in: text)
            }
        }

        guard let chapters, !chapters.isEmpty else { return nil }

        let title = url.deletingPathExtension().lastPathComponent
        let cards = makeCards(from: chapters, mode: mode)
        return (title, cards)
    }

    /// Detect chapters in plain text using common patterns
    static func detectChapters(in text: String) -> [(title: String, text: String)] {
        let pattern = "(?m)^\\s*(chapter\\s+\\w+|part\\s+\\w+|\\d+\\.\\s+\\w+).*$"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return [("", text)]
        }
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        guard !matches.isEmpty else { return [("", text)] }

        var chapters: [(String, String)] = []
        for (i, match) in matches.enumerated() {
            guard let titleRange = Range(match.range, in: text) else { continue }
            let title = String(text[titleRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            let bodyStart = titleRange.upperBound
            let bodyEnd = (i + 1 < matches.count)
                ? Range(matches[i + 1].range, in: text)!.lowerBound
                : text.endIndex
            let body = String(text[bodyStart..<bodyEnd]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !body.isEmpty {
                chapters.append((title, body))
            }
        }

        // If first chapter doesn't start at beginning, prepend the intro text
        if let firstMatchRange = Range(matches[0].range, in: text),
           firstMatchRange.lowerBound > text.startIndex {
            let intro = String(text[text.startIndex..<firstMatchRange.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !intro.isEmpty {
                chapters.insert(("", intro), at: 0)
            }
        }

        return chapters
    }

    static func makeCards(from chapters: [(title: String, text: String)], mode: ReadingMode) -> [BookCard] {
        var cards: [BookCard] = []
        let charLimit = mode.charsPerCard
        let cardsPerPage = mode.cardsPerPage

        for (chapterIdx, chapter) in chapters.enumerated() {
            let chapterNum = chapterIdx + 1

            // Insert chapter separator card
            if !chapter.title.isEmpty {
                let id = cards.count
                cards.append(BookCard(
                    id: id,
                    text: chapter.title,
                    cardNumber: id + 1,
                    totalCards: 0,
                    page: 0,
                    chapter: chapterNum,
                    type: .chapterStart(title: chapter.title, chapterNumber: chapterNum)
                ))
            }

            // Split text into cards at sentence boundaries
            let textCards = splitAtSentences(text: chapter.text, charLimit: charLimit)
            for cardText in textCards {
                let id = cards.count
                let textCardIndex = cards.filter { if case .text = $0.type { return true }; return false }.count
                let page = textCardIndex / cardsPerPage + 1
                cards.append(BookCard(
                    id: id,
                    text: cardText,
                    cardNumber: id + 1,
                    totalCards: 0,
                    page: page,
                    chapter: chapterNum,
                    type: .text
                ))
            }
        }

        let total = cards.count
        return cards.map {
            BookCard(id: $0.id, text: $0.text, cardNumber: $0.cardNumber, totalCards: total,
                     page: $0.page, chapter: $0.chapter, type: $0.type, isBookmarked: $0.isBookmarked)
        }
    }

    /// Split text into chunks that start and end at sentence boundaries
    private static func splitAtSentences(text: String, charLimit: Int) -> [String] {
        // Sentence-ending punctuation followed by space or end
        let sentenceEnders: Set<Character> = [".", "!", "?", "…"]
        var results: [String] = []
        var remaining = text[...]

        while !remaining.isEmpty {
            // Skip leading whitespace
            remaining = remaining.drop(while: { $0.isWhitespace && $0 != "\n" })
            if remaining.isEmpty { break }

            if remaining.count <= charLimit {
                let t = String(remaining).trimmingCharacters(in: .whitespacesAndNewlines)
                if !t.isEmpty { results.append(t) }
                break
            }

            let searchEnd = remaining.index(remaining.startIndex, offsetBy: charLimit)

            // Look for the last sentence-ending punctuation within the limit
            var bestBreak: String.Index?
            var idx = remaining.index(before: searchEnd)
            while idx > remaining.startIndex {
                let ch = remaining[idx]
                if sentenceEnders.contains(ch) {
                    // Check it's followed by a space, newline, quote or end
                    let next = remaining.index(after: idx)
                    if next >= searchEnd || remaining[next].isWhitespace || remaining[next] == "\"" || remaining[next] == "\u{201D}" {
                        bestBreak = next
                        break
                    }
                }
                idx = remaining.index(before: idx)
            }

            let breakPoint: String.Index
            if let best = bestBreak, remaining.distance(from: remaining.startIndex, to: best) >= charLimit / 3 {
                // Good sentence break found (at least 1/3 of card is filled)
                breakPoint = best
            } else {
                // Fallback: break at last space
                if let lastSpace = remaining[..<searchEnd].lastIndex(of: " ") {
                    breakPoint = remaining.index(after: lastSpace)
                } else {
                    breakPoint = searchEnd
                }
            }

            let chunk = String(remaining[..<breakPoint]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !chunk.isEmpty { results.append(chunk) }
            remaining = remaining[breakPoint...]
        }

        return results
    }
}

// MARK: - EPUB Parser

struct EPUBParser {
    static func extractChapters(from data: Data) -> [(title: String, text: String)]? {
        guard let entries = MiniZIP.extract(from: data) else { return nil }

        // 1. Find OPF path from container.xml
        guard let containerData = entries["META-INF/container.xml"],
              let containerXML = String(data: containerData, encoding: .utf8),
              let opfPath = findOPFPath(in: containerXML) else { return nil }

        // 2. Parse OPF for reading order
        guard let opfData = entries[opfPath],
              let opfXML = String(data: opfData, encoding: .utf8) else { return nil }

        let basePath = (opfPath as NSString).deletingLastPathComponent
        let chapterPaths = parseSpine(opf: opfXML, basePath: basePath)

        // 3. Read each chapter
        var chapters: [(title: String, text: String)] = []
        for path in chapterPaths {
            let fileData = entries[path]
                ?? entries[basePath.isEmpty ? path : basePath + "/" + path]
            if let data = fileData, let html = String(data: data, encoding: .utf8) {
                let title = extractTitle(from: html)
                let stripped = html.strippingHTML()
                let body = stripped.trimmingCharacters(in: .whitespacesAndNewlines)
                if !body.isEmpty {
                    chapters.append((title, body))
                }
            }
        }

        return chapters.isEmpty ? nil : chapters
    }

    /// Extract chapter title from HTML (h1, h2, h3, or title tag)
    private static func extractTitle(from html: String) -> String {
        let titlePatterns = [
            "<h1[^>]*>(.*?)</h1>",
            "<h2[^>]*>(.*?)</h2>",
            "<h3[^>]*>(.*?)</h3>",
            "<title[^>]*>(.*?)</title>"
        ]
        for pattern in titlePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]),
               let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
               let contentRange = Range(match.range(at: 1), in: html) {
                let raw = String(html[contentRange]).strippingHTML()
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !raw.isEmpty && raw.count < 200 {
                    return raw
                }
            }
        }
        return ""
    }

    private static func findOPFPath(in xml: String) -> String? {
        guard let range = xml.range(of: "full-path=\"", options: .literal) else { return nil }
        let after = xml[range.upperBound...]
        guard let endQuote = after.firstIndex(of: "\"") else { return nil }
        return String(after[..<endQuote])
    }

    private static func parseSpine(opf: String, basePath: String) -> [String] {
        // Parse manifest: <item id="x" href="y" ... />
        var manifest: [String: String] = [:]
        let patterns = [
            "<item\\s+[^>]*?id=\"([^\"]+)\"[^>]*?href=\"([^\"]+)\"",
            "<item\\s+[^>]*?href=\"([^\"]+)\"[^>]*?id=\"([^\"]+)\""
        ]
        for (i, pattern) in patterns.enumerated() {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { continue }
            let matches = regex.matches(in: opf, range: NSRange(opf.startIndex..., in: opf))
            for match in matches {
                let first = Range(match.range(at: 1), in: opf).map { String(opf[$0]) }
                let second = Range(match.range(at: 2), in: opf).map { String(opf[$0]) }
                if let a = first, let b = second {
                    if i == 0 { manifest[a] = b } else { manifest[b] = a }
                }
            }
        }

        // Parse spine: <itemref idref="x" />
        var order: [String] = []
        if let regex = try? NSRegularExpression(pattern: "<itemref\\s+[^>]*?idref=\"([^\"]+)\"", options: []) {
            let matches = regex.matches(in: opf, range: NSRange(opf.startIndex..., in: opf))
            for match in matches {
                if let idRange = Range(match.range(at: 1), in: opf),
                   let href = manifest[String(opf[idRange])] {
                    let decoded = href.removingPercentEncoding ?? href
                    let fullPath = basePath.isEmpty ? decoded : basePath + "/" + decoded
                    order.append(fullPath)
                }
            }
        }

        return order
    }
}

// MARK: - Minimal ZIP Reader (no external dependencies)

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
            if data[i] == 0x50, data[i+1] == 0x4B, data[i+2] == 0x05, data[i+3] == 0x06 {
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
            guard data[pos] == 0x50, data[pos+1] == 0x4B,
                  data[pos+2] == 0x01, data[pos+3] == 0x02 else { break }

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
                entries.append(Entry(filename: name, method: method,
                                     compressedSize: compSize, uncompressedSize: uncompSize,
                                     localHeaderOffset: localOffset))
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

        // Try raw deflate with COMPRESSION_ZLIB
        var decoded = data.withUnsafeBytes { srcPtr -> Int in
            guard let src = srcPtr.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return 0 }
            return compression_decode_buffer(buffer, bufferSize, src, data.count, nil, COMPRESSION_ZLIB)
        }

        // Fallback: prepend zlib header if raw didn't work
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
        UInt32(data[offset]) | (UInt32(data[offset+1]) << 8) |
        (UInt32(data[offset+2]) << 16) | (UInt32(data[offset+3]) << 24)
    }
}

// MARK: - HTML Stripping

extension String {
    func strippingHTML() -> String {
        var text = self
        let patterns = [
            "<script[^>]*>[\\s\\S]*?</script>",
            "<style[^>]*>[\\s\\S]*?</style>",
            "<[^>]+>"
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                text = regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: " ")
            }
        }
        text = text.replacingOccurrences(of: "&nbsp;", with: " ")
        text = text.replacingOccurrences(of: "&amp;", with: "&")
        text = text.replacingOccurrences(of: "&lt;", with: "<")
        text = text.replacingOccurrences(of: "&gt;", with: ">")
        text = text.replacingOccurrences(of: "&quot;", with: "\"")
        text = text.replacingOccurrences(of: "&#39;", with: "'")
        text = text.replacingOccurrences(of: "&rsquo;", with: "'")
        text = text.replacingOccurrences(of: "&lsquo;", with: "'")
        text = text.replacingOccurrences(of: "&rdquo;", with: "\u{201D}")
        text = text.replacingOccurrences(of: "&ldquo;", with: "\u{201C}")
        text = text.replacingOccurrences(of: "&mdash;", with: "—")
        text = text.replacingOccurrences(of: "&ndash;", with: "–")
        text = text.replacingOccurrences(of: "&hellip;", with: "…")
        // Decode numeric entities like &#8217;
        if let numRegex = try? NSRegularExpression(pattern: "&#(\\d+);", options: []) {
            let matches = numRegex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            for match in matches.reversed() {
                if let fullRange = Range(match.range, in: text),
                   let numRange = Range(match.range(at: 1), in: text),
                   let code = Int(text[numRange]),
                   let scalar = Unicode.Scalar(code) {
                    text.replaceSubrange(fullRange, with: String(Character(scalar)))
                }
            }
        }
        text = text.replacingOccurrences(of: "\\s*\\n\\s*", with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "[ \\t]+", with: " ", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
