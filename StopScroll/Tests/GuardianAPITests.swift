import XCTest
@testable import StopScroll

final class GuardianAPITests: XCTestCase {

    private let apiKey = "test"
    private let baseURL = "https://content.guardianapis.com"

    // MARK: - URL Construction

    func testSearchURLConstructionProducesValidURL() {
        var components = URLComponents(string: "\(baseURL)/search")!
        components.queryItems = [
            URLQueryItem(name: "section", value: "world|science|technology|books|culture|environment"),
            URLQueryItem(name: "show-fields", value: "trailText,thumbnail"),
            URLQueryItem(name: "page-size", value: "20"),
            URLQueryItem(name: "order-by", value: "newest"),
            URLQueryItem(name: "api-key", value: apiKey)
        ]
        let url = components.url
        XCTAssertNotNil(url, "URLComponents should produce a valid URL")
        XCTAssertTrue(url!.absoluteString.contains("content.guardianapis.com/search"))
        XCTAssertTrue(url!.absoluteString.contains("api-key=test"))
    }

    func testSearchURLContainsAllRequiredQueryItems() {
        var components = URLComponents(string: "\(baseURL)/search")!
        components.queryItems = [
            URLQueryItem(name: "section", value: "world|science"),
            URLQueryItem(name: "show-fields", value: "trailText,thumbnail"),
            URLQueryItem(name: "page-size", value: "5"),
            URLQueryItem(name: "order-by", value: "newest"),
            URLQueryItem(name: "api-key", value: apiKey)
        ]
        let url = components.url!
        let query = url.absoluteString
        XCTAssertTrue(query.contains("section="), "URL should contain section parameter")
        XCTAssertTrue(query.contains("show-fields="), "URL should contain show-fields parameter")
        XCTAssertTrue(query.contains("page-size="), "URL should contain page-size parameter")
        XCTAssertTrue(query.contains("order-by="), "URL should contain order-by parameter")
        XCTAssertTrue(query.contains("api-key="), "URL should contain api-key parameter")
    }

    // MARK: - Live API Tests

    func testSearchEndpointReturnsResults() async throws {
        var components = URLComponents(string: "\(baseURL)/search")!
        components.queryItems = [
            URLQueryItem(name: "section", value: "world|science|technology|books|culture|environment"),
            URLQueryItem(name: "show-fields", value: "trailText,thumbnail"),
            URLQueryItem(name: "page-size", value: "5"),
            URLQueryItem(name: "order-by", value: "newest"),
            URLQueryItem(name: "api-key", value: apiKey)
        ]
        let url = try XCTUnwrap(components.url)

        let (data, response) = try await URLSession.shared.data(from: url)
        let httpResponse = try XCTUnwrap(response as? HTTPURLResponse)
        if httpResponse.statusCode == 429 {
            throw XCTSkip("Guardian API rate limit exceeded — skipping live test")
        }
        XCTAssertEqual(httpResponse.statusCode, 200, "API should return 200 OK")

        let json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any],
            "Response should be a JSON dictionary"
        )
        let apiResponse = try XCTUnwrap(
            json["response"] as? [String: Any],
            "JSON should contain a 'response' key"
        )
        XCTAssertEqual(apiResponse["status"] as? String, "ok", "Response status should be 'ok'")

        let results = try XCTUnwrap(
            apiResponse["results"] as? [[String: Any]],
            "Response should contain a 'results' array"
        )
        XCTAssertFalse(results.isEmpty, "Results should not be empty")
    }

    func testArticleHasRequiredFields() async throws {
        var components = URLComponents(string: "\(baseURL)/search")!
        components.queryItems = [
            URLQueryItem(name: "section", value: "world"),
            URLQueryItem(name: "show-fields", value: "trailText,thumbnail"),
            URLQueryItem(name: "page-size", value: "1"),
            URLQueryItem(name: "order-by", value: "newest"),
            URLQueryItem(name: "api-key", value: apiKey)
        ]
        let url = try XCTUnwrap(components.url)

        let (data, response) = try await URLSession.shared.data(from: url)
        if let http = response as? HTTPURLResponse, http.statusCode == 429 {
            throw XCTSkip("Guardian API rate limit exceeded — skipping live test")
        }
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let apiResponse = try XCTUnwrap(json["response"] as? [String: Any])
        let results = try XCTUnwrap(apiResponse["results"] as? [[String: Any]])
        let article = try XCTUnwrap(results.first)

        // Required top-level fields
        XCTAssertNotNil(article["webTitle"], "Article should have webTitle")
        XCTAssertNotNil(article["webUrl"], "Article should have webUrl")
        XCTAssertNotNil(article["sectionName"], "Article should have sectionName")

        // Required fields sub-object
        let fields = try XCTUnwrap(article["fields"] as? [String: Any], "Article should have fields")
        XCTAssertNotNil(fields["trailText"], "Fields should contain trailText")

        // Validate types
        let title = try XCTUnwrap(article["webTitle"] as? String)
        XCTAssertFalse(title.isEmpty, "webTitle should not be empty")

        let webUrl = try XCTUnwrap(article["webUrl"] as? String)
        XCTAssertTrue(webUrl.hasPrefix("https://"), "webUrl should be an HTTPS URL")
    }

    // MARK: - Article-to-JS Mapping

    func testArticleMappingProducesValidJSON() throws {
        // Simulate a Guardian API article response
        let article: [String: Any] = [
            "webTitle": "Test article with 'quotes' and \"double quotes\"",
            "webUrl": "https://www.theguardian.com/world/2024/test-article",
            "sectionName": "World news",
            "fields": [
                "trailText": "<p>A trail with <strong>HTML</strong> tags & entities</p>",
                "thumbnail": "https://media.guim.co.uk/test/500.jpg"
            ]
        ]

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

        let jsonData = try XCTUnwrap(try? JSONSerialization.data(withJSONObject: articleDict))
        let jsonString = try XCTUnwrap(String(data: jsonData, encoding: .utf8))

        // Verify the JSON round-trips correctly
        let decoded = try XCTUnwrap(
            JSONSerialization.jsonObject(with: jsonData) as? [String: String]
        )
        XCTAssertEqual(decoded["title"], "Test article with 'quotes' and \"double quotes\"")
        XCTAssertEqual(decoded["extract"], "A trail with HTML tags & entities")
        XCTAssertEqual(decoded["description"], "World news")
        XCTAssertTrue(decoded["webUrl"]?.hasPrefix("https://") ?? false)

        // Verify the JS-safe string doesn't break single-quoted context
        let jsSafe = jsonString
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
        XCTAssertFalse(jsSafe.isEmpty, "JS-safe string should not be empty")
        // Single quotes inside the value should be escaped
        XCTAssertFalse(jsSafe.contains("'quotes'"), "Unescaped single quotes should not remain")
    }

    func testHTMLStrippingFromTrailText() {
        let htmlInputs = [
            ("<p>Simple paragraph</p>", "Simple paragraph"),
            ("<strong>Bold</strong> text", "Bold text"),
            ("No HTML at all", "No HTML at all"),
            ("<a href=\"url\">Link</a> here", "Link here"),
            ("<p>Nested <em>tags</em> inside</p>", "Nested tags inside"),
        ]

        for (html, expected) in htmlInputs {
            let stripped = html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            XCTAssertEqual(stripped, expected, "HTML stripping failed for: \(html)")
        }
    }

    // MARK: - Full Article Fetch (for reader)

    func testFullArticleEndpointReturnsBodyText() async throws {
        // First, get a real article URL from the search endpoint
        var searchComponents = URLComponents(string: "\(baseURL)/search")!
        searchComponents.queryItems = [
            URLQueryItem(name: "section", value: "world"),
            URLQueryItem(name: "show-fields", value: "trailText"),
            URLQueryItem(name: "page-size", value: "1"),
            URLQueryItem(name: "type", value: "article"),
            URLQueryItem(name: "order-by", value: "newest"),
            URLQueryItem(name: "api-key", value: apiKey)
        ]
        let searchURL = try XCTUnwrap(searchComponents.url)
        let (searchData, searchNetworkResponse) = try await URLSession.shared.data(from: searchURL)
        if let http = searchNetworkResponse as? HTTPURLResponse, http.statusCode == 429 {
            throw XCTSkip("Guardian API rate limit exceeded — skipping live test")
        }
        let searchJSON = try XCTUnwrap(JSONSerialization.jsonObject(with: searchData) as? [String: Any])
        let searchResponse = try XCTUnwrap(searchJSON["response"] as? [String: Any])
        let results = try XCTUnwrap(searchResponse["results"] as? [[String: Any]])
        let article = try XCTUnwrap(results.first)
        let articleId = try XCTUnwrap(article["id"] as? String, "Article should have an id field")

        // Now fetch the full article
        let articleURLString = "\(baseURL)/\(articleId)?show-fields=bodyText&api-key=\(apiKey)"
        let articleURL = try XCTUnwrap(URL(string: articleURLString))
        let (articleData, articleResponse) = try await URLSession.shared.data(from: articleURL)
        let httpResponse = try XCTUnwrap(articleResponse as? HTTPURLResponse)
        XCTAssertEqual(httpResponse.statusCode, 200)

        let articleJSON = try XCTUnwrap(JSONSerialization.jsonObject(with: articleData) as? [String: Any])
        let contentResponse = try XCTUnwrap(articleJSON["response"] as? [String: Any])
        XCTAssertEqual(contentResponse["status"] as? String, "ok")

        let content = try XCTUnwrap(contentResponse["content"] as? [String: Any])
        let fields = try XCTUnwrap(content["fields"] as? [String: Any])
        let bodyText = try XCTUnwrap(fields["bodyText"] as? String)
        XCTAssertGreaterThan(bodyText.count, 100, "bodyText should contain substantial content")
    }
}

final class ArticleOpenWorkflowTests: XCTestCase {

    func testArticleOpenDefaultsIncrementsOpenTokenAndResetsCardIndex() {
        let result = InstagramWebView.Coordinator.makeArticleOpenDefaults(
            previousOpenToken: 41,
            articleId: "article-123",
            title: "Article test"
        )

        XCTAssertEqual(result.currentArticleOpenToken, 42)
        XCTAssertEqual(result.savedCardIndex, 0)
        XCTAssertEqual(result.currentArticleId, "article-123")
        XCTAssertEqual(result.savedBookTitle, "Article test")
    }

    func testSplitIntoChaptersSplitsOnSectionHeadings() {
        let text = """
        Intro paragraph.

        == History ==
        A long history section.

        == Legacy ==
        Legacy section text.
        """

        let chapters = InstagramWebView.Coordinator.splitIntoChapters(title: "Root", fullText: text)

        XCTAssertEqual(chapters.count, 3)
        XCTAssertEqual(chapters[0].title, "Root")
        XCTAssertEqual(chapters[1].title, "History")
        XCTAssertEqual(chapters[2].title, "Legacy")
    }

    func testSplitIntoChaptersRemovesReferenceLikeSections() {
        let text = """
        Main body line.

        == References ==
        Reference 1

        == External links ==
        http://example.com
        """

        let chapters = InstagramWebView.Coordinator.splitIntoChapters(title: "Topic", fullText: text)

        XCTAssertEqual(chapters.count, 1)
        XCTAssertEqual(chapters[0].title, "Topic")
        XCTAssertTrue(chapters[0].text.contains("Main body line"))
    }
}

final class WikipediaArticleButtonWorkflowTests: XCTestCase {

    func testMakeWikipediaExtractURLUsesProvidedLanguageDomain() {
        let url = InstagramWebView.Coordinator.makeWikipediaExtractURL(
            title: "Le Petit Prince",
            lang: "fr"
        )

        XCTAssertNotNil(url)
        XCTAssertTrue(url!.absoluteString.contains("https://fr.wikipedia.org/w/api.php"))
    }

    func testMakeWikipediaExtractURLSanitizesLanguageTag() {
        let url = InstagramWebView.Coordinator.makeWikipediaExtractURL(
            title: "Planets",
            lang: "en-US<script>"
        )

        XCTAssertNotNil(url)
        XCTAssertEqual(url!.host, "enUS.wikipedia.org")
    }

    func testMakeWikipediaExtractURLEncodesArticleTitle() {
        let url = InstagramWebView.Coordinator.makeWikipediaExtractURL(
            title: "L'étranger & société",
            lang: "fr"
        )

        XCTAssertNotNil(url)
        let components = URLComponents(url: url!, resolvingAgainstBaseURL: false)
        let titlesValue = components?.queryItems?.first(where: { $0.name == "titles" })?.value
        XCTAssertEqual(titlesValue, "L'étranger & société")
    }
}

final class WikipediaArticleSelectionTests: XCTestCase {

    func testPickWikipediaArticleAvoidsPreviousTitleWhenAlternativeExists() {
        let articles: [[String: Any]] = [
            ["title": "Same", "extract": "A"],
            ["title": "Different", "extract": "B"]
        ]

        let picked = InstagramWebView.Coordinator.pickWikipediaArticle(from: articles, avoidingTitle: "Same")
        XCTAssertEqual(picked?["title"] as? String, "Different")
    }

    func testPickWikipediaArticleReturnsNilWhenOnlySameTitleAvailable() {
        let articles: [[String: Any]] = [
            ["title": "Same", "extract": "A"]
        ]

        let picked = InstagramWebView.Coordinator.pickWikipediaArticle(from: articles, avoidingTitle: "Same")
        XCTAssertNil(picked)
    }
}

final class ArticleFirstClickTimingTests: XCTestCase {

    func testResolveCurrentArticleIdUsesUserDefaultsWhenAppStorageStillEmpty() {
        let resolved = BookReaderView.resolveCurrentArticleId(
            appStorageValue: "",
            userDefaultsValue: "article-42"
        )

        XCTAssertEqual(resolved, "article-42")
    }

    func testResolveCurrentArticleIdFallsBackToAppStorageWhenDefaultsMissing() {
        let resolved = BookReaderView.resolveCurrentArticleId(
            appStorageValue: "article-7",
            userDefaultsValue: nil
        )

        XCTAssertEqual(resolved, "article-7")
    }
}

final class XPProgressTests: XCTestCase {

    func testXPProgressLevelAndRemainder() {
        XCTAssertEqual(XPProgress.level(for: 0), 1)
        XCTAssertEqual(XPProgress.level(for: 99), 1)
        XCTAssertEqual(XPProgress.level(for: 100), 2)

        XCTAssertEqual(XPProgress.xpInCurrentLevel(for: 142), 42)
        XCTAssertEqual(XPProgress.remainingToNextLevel(for: 142), 58)
    }

    func testParseXPAmountSupportsCommonPayloadTypes() {
        XCTAssertEqual(InstagramWebView.Coordinator.parseXPAmount(15), 15)
        XCTAssertEqual(InstagramWebView.Coordinator.parseXPAmount(12.6), 13)
        XCTAssertEqual(InstagramWebView.Coordinator.parseXPAmount("9"), 9)
        XCTAssertEqual(InstagramWebView.Coordinator.parseXPAmount(nil), 10)
    }
}

final class InstagramSecondaryRouteTests: XCTestCase {

    func testMessagesRouteURL() {
        XCTAssertEqual(
            InstagramSecondaryRoute.url(for: "messages", username: "any"),
            "https://www.instagram.com/direct/inbox/"
        )
    }

    func testSearchRouteURL() {
        XCTAssertEqual(
            InstagramSecondaryRoute.url(for: "search", username: "any"),
            "https://www.instagram.com/explore/"
        )
    }

    func testProfileRouteUsesSanitizedUsername() {
        XCTAssertEqual(
            InstagramSecondaryRoute.url(for: "profile", username: "@john.doe_42"),
            "https://www.instagram.com/john.doe_42/"
        )
    }

    func testProfileRouteReturnsNilWhenUsernameMissing() {
        XCTAssertNil(InstagramSecondaryRoute.url(for: "profile", username: "   "))
    }
}
