import Foundation

extension InstagramWebView.Coordinator {
    /// Fetch a curated Wikipedia article (featured or "on this day") and inject it into JS.
    func fetchWikipediaArticle(lang: String) {
        let safeLang = String(lang.prefix(5).filter { $0.isLetter })

        let now = Date()
        let cal = Calendar.current
        let y = cal.component(.year, from: now)
        let m = String(format: "%02d", cal.component(.month, from: now))
        let d = String(format: "%02d", cal.component(.day, from: now))
        let urlString = "https://\(safeLang).wikipedia.org/api/rest_v1/feed/featured/\(y)/\(m)/\(d)"
        guard let url = URL(string: urlString) else {
            fetchRandomWikipediaArticle(lang: safeLang)
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let data = data, error == nil,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                self?.fetchRandomWikipediaArticle(lang: safeLang)
                return
            }

            var picked: [String: Any]? = nil

            if let mostRead = json["mostread"] as? [String: Any],
               let articles = mostRead["articles"] as? [[String: Any]] {
                let good = articles.filter { art in
                    let ext = art["extract"] as? String ?? ""
                    let desc = (art["description"] as? String ?? "").lowercased()
                    return ext.count > 80
                        && !desc.contains("disambiguation")
                        && !desc.contains("wikimedia")
                        && !desc.contains("wikipedia")
                }
                picked = Self.pickWikipediaArticle(from: good, avoidingTitle: self?.lastWikipediaTitle)
            }

            if picked == nil, let tfa = json["tfa"] as? [String: Any] {
                picked = Self.pickWikipediaArticle(from: [tfa], avoidingTitle: self?.lastWikipediaTitle)
            }

            if picked == nil, let otd = json["onthisday"] as? [[String: Any]],
               let first = otd.first,
               let pages = first["pages"] as? [[String: Any]],
               let page = pages.first {
                picked = Self.pickWikipediaArticle(from: [page], avoidingTitle: self?.lastWikipediaTitle)
            }

            guard let article = picked else {
                self?.fetchRandomWikipediaArticle(lang: safeLang)
                return
            }

            if let title = article["title"] as? String {
                self?.lastWikipediaTitle = title
            }

            self?.injectArticleToJS(article: article, lang: safeLang)
        }.resume()
    }

    /// Fallback: fetch a random Wikipedia summary (for languages without featured feed).
    func fetchRandomWikipediaArticle(lang: String) {
        let urlString = "https://\(lang).wikipedia.org/api/rest_v1/page/random/summary"
        guard let url = URL(string: urlString) else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let data = data, error == nil,
                  let article = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
            self?.injectArticleToJS(article: article, lang: lang)
        }.resume()
    }

    /// Inject an article object (from any Wikipedia API) into the JS runtime.
    func injectArticleToJS(article: [String: Any], lang: String) {
        let title = (article["title"] as? String ?? "").replacingOccurrences(of: "'", with: "\\'")
        let extract = (article["extract"] as? String ?? "").replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
        let desc = (article["description"] as? String ?? "").replacingOccurrences(of: "'", with: "\\'")
        let pageUrl: String
        if let urls = article["content_urls"] as? [String: Any],
           let mobile = urls["mobile"] as? [String: Any],
           let page = mobile["page"] as? String {
            pageUrl = page.replacingOccurrences(of: "'", with: "\\'")
        } else {
            pageUrl = ""
        }
        let thumb: String
        if let t = article["thumbnail"] as? [String: Any],
           let src = t["source"] as? String {
            thumb = src.replacingOccurrences(of: "'", with: "\\'")
        } else {
            thumb = ""
        }

        let js = """
        (function(){
            var ns = window.StopScroll;
            if (ns && ns.wikipedia && ns.wikipedia._setFromNative) {
                ns.wikipedia._setFromNative({
                    title:'\(title)',extract:'\(extract)',description:'\(desc)',
                    pageUrl:'\(pageUrl)',thumbnail:'\(thumb)',lang:'\(lang)'
                });
            }
        })();
        """

        DispatchQueue.main.async {
            self.webView?.evaluateJavaScript(js)
        }
    }

    /// Fetch the full Wikipedia article text, split into sections, then open the reader.
    func fetchFullArticleAndOpen(title: String, lang: String) {
        guard let url = Self.makeWikipediaExtractURL(title: title, lang: lang) else { return }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let data = data, error == nil,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let query = json["query"] as? [String: Any],
                  let pages = query["pages"] as? [String: Any] else { return }

            guard let pageObj = pages.values.first as? [String: Any],
                  let fullText = pageObj["extract"] as? String,
                  !fullText.isEmpty else { return }

            let chapters = Self.splitIntoChapters(title: title, fullText: fullText)

            DispatchQueue.main.async {
                self?.handleOpenArticle(title: title, chapters: chapters)
            }
        }.resume()
    }

    /// Split Wikipedia plain-text extract into (title, text) chapters by section headings.
    static func splitIntoChapters(title: String, fullText: String) -> [(title: String, text: String)] {
        let lines = fullText.components(separatedBy: "\n")
        var chapters: [(title: String, text: String)] = []
        var currentTitle = title
        var currentLines: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("==") && trimmed.hasSuffix("==") {
                let text = currentLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    chapters.append((currentTitle, text))
                }
                currentTitle = trimmed
                    .replacingOccurrences(of: "=", with: "")
                    .trimmingCharacters(in: .whitespaces)
                currentLines = []
            } else {
                currentLines.append(line)
            }
        }

        let lastText = currentLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        if !lastText.isEmpty {
            chapters.append((currentTitle, lastText))
        }

        let skipSections: Set<String> = [
            "see also", "references", "external links", "further reading",
            "notes", "bibliography", "sources",
            "voir aussi", "références", "liens externes", "notes et références",
            "bibliographie", "annexes"
        ]
        chapters = chapters.filter { ch in
            !skipSections.contains(ch.title.lowercased())
        }

        return chapters.isEmpty ? [(title, fullText)] : chapters
    }

    static func makeArticleOpenDefaults(previousOpenToken: Int, articleId: String, title: String) -> ArticleOpenDefaults {
        ArticleOpenDefaults(
            savedCardIndex: 0,
            savedBookTitle: title,
            currentArticleId: articleId,
            currentArticleOpenToken: previousOpenToken + 1
        )
    }

    static func makeWikipediaExtractURL(title: String, lang: String) -> URL? {
        let safeLang = String(lang.prefix(5).filter { $0.isLetter })
        var components = URLComponents()
        components.scheme = "https"
        components.host = "\(safeLang).wikipedia.org"
        components.path = "/w/api.php"
        components.queryItems = [
            URLQueryItem(name: "action", value: "query"),
            URLQueryItem(name: "prop", value: "extracts"),
            URLQueryItem(name: "titles", value: title),
            URLQueryItem(name: "explaintext", value: "1"),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "exlimit", value: "1")
        ]
        return components.url
    }

    static func pickWikipediaArticle(from articles: [[String: Any]], avoidingTitle: String?) -> [String: Any]? {
        guard !articles.isEmpty else { return nil }
        guard let avoidingTitle, !avoidingTitle.isEmpty else {
            return articles.randomElement()
        }

        let normalizedAvoiding = avoidingTitle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filtered = articles.filter { article in
            let title = (article["title"] as? String ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            return title != normalizedAvoiding
        }

        return filtered.randomElement()
    }

    /// Save a Wikipedia article into BookStorage & library, then open the reader.
    func handleOpenArticle(title: String, chapters: [(title: String, text: String)]) {
        var library: [LibraryBook] = []
        if let data = UserDefaults.standard.data(forKey: "library"),
           let lib = try? JSONDecoder().decode([LibraryBook].self, from: data) {
            library = lib
        }

        let existingId = library.first(where: { $0.isArticle && $0.title == title })?.id
        let bookId = existingId ?? UUID().uuidString

        if existingId == nil {
            BookStorage.save(chapters: chapters, bookId: bookId)

            let cards = BookParser.makeCards(from: chapters, mode: .flow)
            let textCards = cards.filter { if case .text = $0.type { return true }; return false }
            let totalPages = textCards.isEmpty ? 0 : textCards.last!.page

            library.append(LibraryBook(
                id: bookId, title: title,
                savedCardIndex: 0, totalCards: cards.count,
                currentChapter: 1, totalPages: totalPages,
                readingMode: ReadingMode.flow.rawValue, isArticle: true
            ))
            if let encoded = try? JSONEncoder().encode(library) {
                UserDefaults.standard.set(encoded, forKey: "library")
            }
        }

        DispatchQueue.main.async {
            let openToken = UserDefaults.standard.integer(forKey: "currentArticleOpenToken")
            let next = Self.makeArticleOpenDefaults(previousOpenToken: openToken, articleId: bookId, title: title)

            UserDefaults.standard.set(next.savedCardIndex, forKey: "savedCardIndex")
            UserDefaults.standard.set(next.savedBookTitle, forKey: "savedBookTitle")
            UserDefaults.standard.set(next.currentArticleId, forKey: "currentArticleId")
            UserDefaults.standard.set(next.currentArticleOpenToken, forKey: "currentArticleOpenToken")

            DispatchQueue.main.async {
                self.parent.showingReader = true
            }
        }
    }
}
