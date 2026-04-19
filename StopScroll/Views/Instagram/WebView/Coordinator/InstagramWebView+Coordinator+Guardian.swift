import Foundation

extension InstagramWebView.Coordinator {
    /// Fetch a random article from The Guardian API (editorially curated, top stories).
    func fetchGuardianArticle() {
        let apiKey = "test"
        var components = URLComponents(string: "https://content.guardianapis.com/search")!
        components.queryItems = [
            URLQueryItem(name: "section", value: "world|science|technology|books|culture|environment"),
            URLQueryItem(name: "show-fields", value: "trailText,thumbnail"),
            URLQueryItem(name: "page-size", value: "20"),
            URLQueryItem(name: "order-by", value: "newest"),
            URLQueryItem(name: "api-key", value: apiKey)
        ]
        guard let url = components.url else {
            print("[StopScroll] Guardian: failed to build URL")
            injectGuardianError("bad_url")
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            if let error = error {
                print("[StopScroll] Guardian fetch error: \(error.localizedDescription)")
                self?.injectGuardianError("network")
                return
            }
            guard let data = data else {
                print("[StopScroll] Guardian: no data")
                self?.injectGuardianError("no_data")
                return
            }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let resp = json["response"] as? [String: Any],
                  let results = resp["results"] as? [[String: Any]],
                  !results.isEmpty else {
                let preview = String(data: data.prefix(500), encoding: .utf8) ?? "<binary>"
                print("[StopScroll] Guardian: unexpected response – \(preview)")
                self?.injectGuardianError("parse")
                return
            }

            let article = results[Int.random(in: 0..<results.count)]
            self?.injectGuardianArticleToJS(article: article)
        }.resume()
    }

    /// Notify JS that Guardian fetch failed so it can retry.
    func injectGuardianError(_ reason: String) {
        let js = "(function(){var ns=window.StopScroll;if(ns&&ns.guardian&&ns.guardian._setFromNative){ns.guardian._setFromNative(null);}})();"
        DispatchQueue.main.async {
            self.webView?.evaluateJavaScript(js)
        }
    }

    /// Inject a Guardian article into the JS runtime using safe JSON serialization.
    func injectGuardianArticleToJS(article: [String: Any]) {
        let title = article["webTitle"] as? String ?? ""
        let webUrl = article["webUrl"] as? String ?? ""
        let sectionName = article["sectionName"] as? String ?? ""
        let fields = article["fields"] as? [String: Any] ?? [:]
        let rawTrailText = fields["trailText"] as? String ?? ""
        let extract = rawTrailText.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        let thumbnail = fields["thumbnail"] as? String ?? ""

        let articleDict: [String: String] = [
            "title": title,
            "extract": extract.isEmpty ? sectionName : extract,
            "description": sectionName,
            "webUrl": webUrl,
            "thumbnail": thumbnail
        ]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: articleDict),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            print("[StopScroll] Guardian: failed to serialize article JSON")
            injectGuardianError("json")
            return
        }

        let escapedJSON = jsonString
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
        let js = "(function(){var ns=window.StopScroll;if(ns&&ns.guardian&&ns.guardian._setFromNative){ns.guardian._setFromNative(JSON.parse('\(escapedJSON)'));}})();"
        DispatchQueue.main.async {
            self.webView?.evaluateJavaScript(js) { _, error in
                if let error = error {
                    print("[StopScroll] Guardian JS injection error: \(error)")
                }
            }
        }
    }

    /// Fetch Guardian article full text and open in reader.
    func fetchGuardianFullArticleAndOpen(urlString: String, title: String) {
        let apiKey = "test"
        let articlePath = urlString
            .replacingOccurrences(of: "https://www.theguardian.com/", with: "")
        let apiUrlString = "https://content.guardianapis.com/\(articlePath)?show-fields=bodyText&api-key=\(apiKey)"
        guard let url = URL(string: apiUrlString) else { return }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let data = data, error == nil,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let response = json["response"] as? [String: Any],
                  let content = response["content"] as? [String: Any],
                  let fields = content["fields"] as? [String: Any],
                  let bodyText = fields["bodyText"] as? String,
                  !bodyText.isEmpty else { return }

            let chapters = [(title: title, text: bodyText)]
            DispatchQueue.main.async {
                self?.handleOpenArticle(title: title, chapters: chapters)
            }
        }.resume()
    }
}
