import Foundation

struct BookParser {

    static func loadBook(from url: URL, mode: ReadingMode = .flow) -> (title: String, cards: [BookCard], chapters: [(title: String, text: String)], coverData: Data?)? {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: url) else { return nil }

        let ext = url.pathExtension.lowercased()
        var chapters: [(title: String, text: String)]?
        var coverData: Data?

        switch ext {
        case "epub":
            chapters = EPUBParser.extractChapters(from: data)
            coverData = EPUBParser.extractCover(from: data)
        default:
            if let text = String(data: data, encoding: .utf8) {
                chapters = detectChapters(in: text)
            }
        }

        guard let chapters, !chapters.isEmpty else { return nil }

        let title = url.deletingPathExtension().lastPathComponent
        let cards = makeCards(from: chapters, mode: mode)
        return (title, cards, chapters, coverData)
    }

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

    static func isSectionOrMetaTitle(_ title: String) -> Bool {
        let lower = title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let sectionKeywords = [
            "préface", "preface", "foreword", "avant-propos",
            "introduction", "prologue", "épilogue", "epilogue",
            "appendix", "appendice", "postface", "à propos",
            "about", "author", "auteur", "translator", "traducteur",
            "notes", "glossaire", "glossary", "index", "table"
        ]
        return sectionKeywords.contains { lower.contains($0) }
    }

    static func makeCards(from chapters: [(title: String, text: String)], mode: ReadingMode) -> [BookCard] {
        var cards: [BookCard] = []
        let charLimit = mode.charsPerCard
        let cardsPerPage = mode.cardsPerPage
        var realChapterNum = 0
        var currentChapterTitle = ""

        for (_, chapter) in chapters.enumerated() {
            let isSection = EPUBParser.isSectionTitle(chapter.title) || isSectionOrMetaTitle(chapter.title)

            if !chapter.title.isEmpty {
                let id = cards.count
                if isSection {
                    currentChapterTitle = chapter.title
                    cards.append(BookCard(
                        id: id,
                        text: chapter.title,
                        cardNumber: id + 1,
                        totalCards: 0,
                        page: 0,
                        chapter: 0,
                        type: .sectionStart(title: chapter.title),
                        chapterTitle: chapter.title,
                        cardIndexInPage: 0
                    ))
                } else {
                    realChapterNum += 1
                    currentChapterTitle = chapter.title
                    cards.append(BookCard(
                        id: id,
                        text: chapter.title,
                        cardNumber: id + 1,
                        totalCards: 0,
                        page: 0,
                        chapter: realChapterNum,
                        type: .chapterStart(title: chapter.title, chapterNumber: realChapterNum),
                        chapterTitle: chapter.title,
                        cardIndexInPage: 0
                    ))
                }
            } else if chapter.title.isEmpty && realChapterNum == 0 {
                currentChapterTitle = ""
            }

            let currentChapter = isSection && chapter.title.isEmpty ? 0 : (isSection ? 0 : max(realChapterNum, 1))
            let textCards = splitAtSentences(text: chapter.text, charLimit: charLimit)

            for cardText in textCards {
                let id = cards.count
                let textCardIndex = cards.filter { if case .text = $0.type { return true }; return false }.count
                let page = textCardIndex / cardsPerPage + 1
                let cardIndexInPage = textCardIndex % cardsPerPage + 1
                cards.append(BookCard(
                    id: id,
                    text: cardText,
                    cardNumber: id + 1,
                    totalCards: 0,
                    page: page,
                    chapter: currentChapter,
                    type: .text,
                    chapterTitle: currentChapterTitle,
                    cardIndexInPage: cardIndexInPage
                ))
            }
        }

        let total = cards.count
        return cards.map {
            BookCard(
                id: $0.id,
                text: $0.text,
                cardNumber: $0.cardNumber,
                totalCards: total,
                page: $0.page,
                chapter: $0.chapter,
                type: $0.type,
                chapterTitle: $0.chapterTitle,
                cardIndexInPage: $0.cardIndexInPage,
                isBookmarked: $0.isBookmarked
            )
        }
    }

    private static func splitAtSentences(text: String, charLimit: Int) -> [String] {
        let sentenceEnders: Set<Character> = [".", "!", "?", "…"]
        var results: [String] = []
        var remaining = text[...]

        while !remaining.isEmpty {
            remaining = remaining.drop(while: { $0.isWhitespace && $0 != "\n" })
            if remaining.isEmpty { break }

            if remaining.count <= charLimit {
                let t = String(remaining).trimmingCharacters(in: .whitespacesAndNewlines)
                if !t.isEmpty { results.append(t) }
                break
            }

            let searchEnd = remaining.index(remaining.startIndex, offsetBy: charLimit)
            var bestBreak: String.Index?
            var idx = remaining.index(before: searchEnd)

            while idx > remaining.startIndex {
                let ch = remaining[idx]
                if sentenceEnders.contains(ch) {
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
                breakPoint = best
            } else {
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
