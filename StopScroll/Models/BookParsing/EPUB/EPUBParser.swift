import Foundation

struct EPUBParser {
    static func extractChapters(from data: Data) -> [(title: String, text: String)]? {
        guard let entries = MiniZIP.extract(from: data) else { return nil }

        guard let containerData = entries["META-INF/container.xml"],
              let containerXML = String(data: containerData, encoding: .utf8),
              let opfPath = findOPFPath(in: containerXML) else { return nil }

        guard let opfData = entries[opfPath],
              let opfXML = String(data: opfData, encoding: .utf8) else { return nil }

        let basePath = (opfPath as NSString).deletingLastPathComponent
        let chapterPaths = parseSpine(opf: opfXML, basePath: basePath)
        let bookTitle = extractBookTitle(from: opfXML)

        var chapters: [(title: String, text: String)] = []
        for path in chapterPaths {
            let fileData = entries[path] ?? entries[basePath.isEmpty ? path : basePath + "/" + path]
            if let data = fileData, let html = String(data: data, encoding: .utf8) {
                let title = extractTitle(from: html)
                let stripped = html.strippingHTML()
                var body = stripped.trimmingCharacters(in: .whitespacesAndNewlines)
                var finalTitle = title

                if shouldSkipSpineDocument(path: path) {
                    continue
                }

                if !title.isEmpty {
                    let titleTrimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
                    if body.hasPrefix(titleTrimmed) {
                        body = String(body.dropFirst(titleTrimmed.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }

                if let detected = detectHeadingInBody(body), isLikelyStructuralChapterTitle(detected.title) {
                    if finalTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || isLikelyNonChapterTitle(finalTitle, bookTitle: bookTitle) {
                        finalTitle = detected.title
                    }
                    body = detected.remainingBody
                }

                if body.isEmpty {
                    if !isLikelyNonChapterTitle(finalTitle, bookTitle: bookTitle), isLikelyStructuralChapterTitle(finalTitle) {
                        chapters.append((finalTitle, ""))
                    }
                    continue
                }

                if isLikelyNonChapterTitle(finalTitle, bookTitle: bookTitle) {
                    if let split = splitEmbeddedChapters(in: body), !split.isEmpty {
                        for segment in split {
                            chapters.append(segment)
                        }
                        continue
                    }

                    if !chapters.isEmpty {
                        chapters[chapters.count - 1].text += "\n\n" + body
                    }
                    continue
                }

                if finalTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    if !chapters.isEmpty {
                        chapters[chapters.count - 1].text += "\n\n" + body
                    } else {
                        chapters.append(("", body))
                    }
                    continue
                }

                chapters.append((finalTitle, body))
            }
        }

        return chapters.isEmpty ? nil : chapters
    }

    static func extractCover(from data: Data) -> Data? {
        guard let entries = MiniZIP.extract(from: data) else { return nil }
        guard let containerData = entries["META-INF/container.xml"],
              let containerXML = String(data: containerData, encoding: .utf8),
              let opfPath = findOPFPath(in: containerXML),
              let opfData = entries[opfPath],
              let opfXML = String(data: opfData, encoding: .utf8) else {
            return fallbackCover(in: entries)
        }

        let basePath = (opfPath as NSString).deletingLastPathComponent

        if let href = firstMatch(in: opfXML, pattern: "<item[^>]*properties=\"[^\"]*cover-image[^\"]*\"[^>]*href=\"([^\"]+)\"")
            ?? firstMatch(in: opfXML, pattern: "<item[^>]*href=\"([^\"]+)\"[^>]*properties=\"[^\"]*cover-image[^\"]*\"") {
            if let data = resolveAsset(href: href, basePath: basePath, entries: entries) {
                return data
            }
        }

        if let coverId = firstMatch(in: opfXML, pattern: "<meta[^>]*name=\"cover\"[^>]*content=\"([^\"]+)\"") {
            let idPatternA = "<item[^>]*id=\\\"\(NSRegularExpression.escapedPattern(for: coverId))\\\"[^>]*href=\\\"([^\\\"]+)\\\""
            let idPatternB = "<item[^>]*href=\\\"([^\\\"]+)\\\"[^>]*id=\\\"\(NSRegularExpression.escapedPattern(for: coverId))\\\""
            if let href = firstMatch(in: opfXML, pattern: idPatternA)
                ?? firstMatch(in: opfXML, pattern: idPatternB),
               let data = resolveAsset(href: href, basePath: basePath, entries: entries) {
                return data
            }
        }

        return fallbackCover(in: entries)
    }

    static func isSectionTitle(_ title: String) -> Bool {
        let lower = title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return prefaceSections.contains(where: { lower.hasPrefix($0) || lower == $0 })
    }

    private static let prefaceSections: Set<String> = [
        "preface", "foreword", "prologue", "introduction", "acknowledgements",
        "acknowledgments", "dedication", "epigraph", "note", "notes",
        "about the author", "copyright", "colophon", "title page",
        "table of contents", "contents", "afterword", "epilogue", "appendix"
    ]

    private static func resolveAsset(href: String, basePath: String, entries: [String: Data]) -> Data? {
        let decoded = href.removingPercentEncoding ?? href
        let direct = entries[decoded]
        if direct != nil { return direct }
        if basePath.isEmpty { return entries[decoded] }
        return entries[basePath + "/" + decoded]
    }

    private static func fallbackCover(in entries: [String: Data]) -> Data? {
        let coverCandidates = entries.keys
            .filter { key in
                let lower = key.lowercased()
                return (lower.hasSuffix(".jpg") || lower.hasSuffix(".jpeg") || lower.hasSuffix(".png"))
                    && lower.contains("cover")
            }
            .sorted()

        for path in coverCandidates {
            if let data = entries[path] {
                return data
            }
        }
        return nil
    }

    private static func firstMatch(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[range])
    }

    private static func extractBookTitle(from opfXML: String) -> String {
        if let title = firstMatch(in: opfXML, pattern: "<dc:title[^>]*>(.*?)</dc:title>") {
            return title.strippingHTML().trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return ""
    }

    private static func normalizeChapterTitleForCompare(_ title: String) -> String {
        title
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func shouldSkipSpineDocument(path: String) -> Bool {
        let lowerPath = path.lowercased()
        return lowerPath.hasSuffix("nav.xhtml") || lowerPath.hasSuffix("toc.xhtml") || lowerPath.hasSuffix("toc.html")
    }

    private static func isLikelyNonChapterTitle(_ title: String, bookTitle: String) -> Bool {
        let normalized = normalizeChapterTitleForCompare(title)

        if normalized.isEmpty {
            return true
        }

        if let pageRegex = try? NSRegularExpression(pattern: "^page\\s+\\d+$", options: .caseInsensitive),
           pageRegex.firstMatch(in: normalized, range: NSRange(normalized.startIndex..., in: normalized)) != nil {
            return true
        }

        let normalizedBookTitle = normalizeChapterTitleForCompare(bookTitle)
        if !normalizedBookTitle.isEmpty && normalized == normalizedBookTitle {
            return true
        }

        if normalized.contains("project gutenberg") || normalized.contains("license") {
            return true
        }

        return false
    }

    private static func isLikelyStructuralChapterTitle(_ title: String) -> Bool {
        let normalized = normalizeChapterTitleForCompare(title)
        let patterns = [
            "^(notice|premier\\s+chapitre|chapitre\\s+[ivxlcdm\\d]{1,8}(?:\\s+[ivxlcdm\\d]{3,8})?|première\\s+partie|deuxième\\s+partie|troisième\\s+partie|partie\\s+[ivxlcdm\\d]+|the\\s+preface|chapter\\s+[ivxlcdm\\d]+|appendice|les\\s+principes\\s+du\\s+novlangue|à\\s+propos\\s+de\\s+cette\\s+édition\\s+électronique|[ivxlcdm]+)$"
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               regex.firstMatch(in: normalized, range: NSRange(normalized.startIndex..., in: normalized)) != nil {
                return true
            }
        }
        return false
    }

    private static func detectHeadingInBody(_ body: String) -> (title: String, remainingBody: String)? {
        let pattern = "(?im)^(notice|premier\\s+chapitre|chapitre\\s+[ivxlcdm\\d]{1,8}(?:\\s+[ivxlcdm\\d]{3,8})?|première\\s+partie|deuxième\\s+partie|troisième\\s+partie|partie\\s+[ivxlcdm\\d]+|the\\s+preface|chapter\\s+[ivxlcdm\\d]+\\.?|appendice|les\\s+principes\\s+du\\s+novlangue|à\\s+propos\\s+de\\s+cette\\s+édition\\s+électronique|[ivxlcdm]+)\\s*$"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let nsRange = NSRange(body.startIndex..., in: body)
        guard let match = regex.firstMatch(in: body, range: nsRange),
              let titleRange = Range(match.range(at: 1), in: body) else { return nil }

        if match.range.location > 240 {
            return nil
        }

        let heading = String(body[titleRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !heading.isEmpty else { return nil }

        let afterMatchLoc = match.range.location + match.range.length
        let remaining: String
        if let afterMatchIdx = Range(NSRange(location: afterMatchLoc, length: 0), in: body)?.lowerBound {
            remaining = String(body[afterMatchIdx...]).trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            remaining = body
        }

        return (heading, remaining)
    }

    private static func splitEmbeddedChapters(in body: String) -> [(title: String, text: String)]? {
        let pattern = "(?i)(premier\\s+chapitre|chapitre\\s+[ivxlcdm\\d]{1,8}(?:\\s+[ivxlcdm\\d]{3,8})?|premi[èe]re\\s+partie|deuxi[èe]me\\s+partie|troisi[èe]me\\s+partie|appendice|les\\s+principes\\s+du\\s+novlangue|à\\s+propos\\s+de\\s+cette\\s+édition\\s+électronique)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let nsRange = NSRange(body.startIndex..., in: body)
        let matches = regex.matches(in: body, range: nsRange)
        guard !matches.isEmpty else { return nil }

        var chapters: [(title: String, text: String)] = []

        for (i, match) in matches.enumerated() {
            guard let headingRange = Range(match.range(at: 1), in: body) else { continue }
            let rawHeading = String(body[headingRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            let heading = rawHeading.replacingOccurrences(of: "[\\.\\:\\-]+$", with: "", options: .regularExpression)

            let contentStart = headingRange.upperBound
            let contentEnd: String.Index
            if i + 1 < matches.count, let nextRange = Range(matches[i + 1].range(at: 1), in: body) {
                contentEnd = nextRange.lowerBound
            } else {
                contentEnd = body.endIndex
            }

            let text = String(body[contentStart..<contentEnd]).trimmingCharacters(in: .whitespacesAndNewlines)
            chapters.append((heading, text))
        }

        return chapters.isEmpty ? nil : chapters
    }

    private static func extractTitle(from html: String) -> String {
        let titlePatterns = [
            "<h1[^>]*>(.*?)</h1>",
            "<h2[^>]*>(.*?)</h2>",
            "<h3[^>]*>(.*?)</h3>"
        ]
        for pattern in titlePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]),
               let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
               let contentRange = Range(match.range(at: 1), in: html) {
                let raw = String(html[contentRange]).strippingHTML().trimmingCharacters(in: .whitespacesAndNewlines)
                if !raw.isEmpty && raw.count < 200 {
                    return raw
                }
            }
        }
        if let regex = try? NSRegularExpression(pattern: "<title[^>]*>(.*?)</title>", options: [.caseInsensitive, .dotMatchesLineSeparators]),
           let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
           let contentRange = Range(match.range(at: 1), in: html) {
            let raw = String(html[contentRange]).strippingHTML().trimmingCharacters(in: .whitespacesAndNewlines)
            if !raw.isEmpty && raw.count < 200 {
                return raw
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
