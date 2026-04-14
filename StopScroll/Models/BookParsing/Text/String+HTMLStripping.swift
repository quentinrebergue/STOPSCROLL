import Foundation

extension String {
    func strippingHTML() -> String {
        var text = self

        let blockPatterns = [
            "<script[^>]*>[\\s\\S]*?</script>",
            "<style[^>]*>[\\s\\S]*?</style>"
        ]
        for pattern in blockPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                text = regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "")
            }
        }

        let blockCloseTags = ["p", "div", "h1", "h2", "h3", "h4", "h5", "h6", "li", "blockquote", "tr"]
        for tag in blockCloseTags {
            if let regex = try? NSRegularExpression(pattern: "</\(tag)\\s*>", options: .caseInsensitive) {
                text = regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "\n\n")
            }
        }

        if let regex = try? NSRegularExpression(pattern: "<br\\s*/?>", options: .caseInsensitive) {
            text = regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "\n")
        }

        for tag in blockCloseTags {
            if let regex = try? NSRegularExpression(pattern: "<\(tag)[^>]*>", options: .caseInsensitive) {
                text = regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "")
            }
        }

        if let regex = try? NSRegularExpression(pattern: "<[^>]+>", options: .caseInsensitive) {
            text = regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "")
        }

        text = text.replacingOccurrences(of: "&nbsp;", with: " ")
        text = text.replacingOccurrences(of: "&amp;", with: "&")
        text = text.replacingOccurrences(of: "&lt;", with: "<")
        text = text.replacingOccurrences(of: "&gt;", with: ">")
        text = text.replacingOccurrences(of: "&quot;", with: "\"")
        text = text.replacingOccurrences(of: "&#39;", with: "'")
        text = text.replacingOccurrences(of: "&rsquo;", with: "\u{2019}")
        text = text.replacingOccurrences(of: "&lsquo;", with: "\u{2018}")
        text = text.replacingOccurrences(of: "&rdquo;", with: "\u{201D}")
        text = text.replacingOccurrences(of: "&ldquo;", with: "\u{201C}")
        text = text.replacingOccurrences(of: "&mdash;", with: "—")
        text = text.replacingOccurrences(of: "&ndash;", with: "–")
        text = text.replacingOccurrences(of: "&hellip;", with: "…")

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

        text = text.replacingOccurrences(of: "[ \\t]+", with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: "\\n[ \\t]+\\n", with: "\n\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "\n\n", with: "\u{0000}PARA\u{0000}")
        text = text.replacingOccurrences(of: "\n", with: " ")
        text = text.replacingOccurrences(of: "\u{0000}PARA\u{0000}", with: "\n")
        text = text.replacingOccurrences(of: "  +", with: " ", options: .regularExpression)

        let lines = text.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .init(charactersIn: " \t")) }
        text = lines.joined(separator: "\n")
        text = text.replacingOccurrences(of: "\\n{2,}", with: "\n", options: .regularExpression)

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
