import XCTest
@testable import StopScroll

final class BookParserEPUBTests: XCTestCase {
    func testAllEPUBManifestsMatchChapterDetection() throws {
        let bundle = FixtureLoader.bundle(for: Self.self)
        let manifestURLs = try FixtureLoader.manifestFiles(in: bundle)

        XCTAssertFalse(manifestURLs.isEmpty, "Expected at least one manifest in Fixtures/manifests")

        for manifestURL in manifestURLs {
            let manifest = try FixtureLoader.decodeManifest(at: manifestURL)
            let fixtureURL = try FixtureLoader.fixtureURL(named: manifest.bookFile, in: bundle)
            let expectedTitles = manifest.expectedChapterTitles ?? []
            let hasTemplatePlaceholders = expectedTitles.contains { $0.hasPrefix("REPLACE_WITH_") }
            if hasTemplatePlaceholders {
                throw XCTSkip("\(manifest.bookFile): replace template titles in manifest before strict validation")
            }
            if manifest.expectedChapterCount == nil && expectedTitles.isEmpty {
                throw XCTSkip("\(manifest.bookFile): add expectedChapterCount and/or expectedChapterTitles in manifest")
            }

            guard let result = BookParser.loadBook(from: fixtureURL, mode: .flow) else {
                XCTFail("\(manifest.testName): parser returned nil for fixture \(manifest.bookFile)")
                continue
            }

            let actualTitles = result.chapters.map(\.title)
            if let expectedCount = manifest.expectedChapterCount, expectedTitles.isEmpty {
                XCTAssertEqual(
                    result.chapters.count,
                    expectedCount,
                    "\(manifest.testName): chapter count mismatch for fixture \(manifest.bookFile)"
                )
            }

            if !expectedTitles.isEmpty {
                FixtureLoader.assertTitles(
                    expected: expectedTitles,
                    actual: actualTitles,
                    fixtureName: manifest.bookFile
                )
            }
        }
    }
}
