import Foundation
import XCTest

struct EPUBChapterManifest: Decodable {
    let testName: String
    let bookFile: String
    let expectedChapterTitles: [String]?
    let expectedChapterCount: Int?

    var chapterCount: Int? {
        if let expectedChapterCount {
            return expectedChapterCount
        }
        if let expectedChapterTitles {
            return expectedChapterTitles.count
        }
        return nil
    }
}

enum FixtureLoader {
    static func bundle(for testCase: AnyClass) -> Bundle {
        Bundle(for: testCase)
    }

    static func manifestFiles(in bundle: Bundle) throws -> [URL] {
        let nested = bundle.urls(forResourcesWithExtension: "json", subdirectory: "Fixtures/manifests") ?? []
        if !nested.isEmpty {
            return nested.sorted { $0.lastPathComponent < $1.lastPathComponent }
        }

        let flat = (bundle.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? [])
            .filter { !$0.lastPathComponent.hasPrefix("Info") }
        guard !flat.isEmpty else {
            throw NSError(domain: "FixtureLoader", code: 1, userInfo: [NSLocalizedDescriptionKey: "No manifest files found in test bundle"])
        }
        return flat.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    static func decodeManifest(at url: URL) throws -> EPUBChapterManifest {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(EPUBChapterManifest.self, from: data)
    }

    static func fixtureURL(named filename: String, in bundle: Bundle) throws -> URL {
        if let nested = bundle.url(forResource: filename, withExtension: nil, subdirectory: "Fixtures/books") {
            return nested
        }
        if let flat = bundle.url(forResource: filename, withExtension: nil, subdirectory: nil) {
            return flat
        }
        throw NSError(
            domain: "FixtureLoader",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "Missing EPUB fixture: \(filename)"]
        )
    }

    static func normalizeTitle(_ title: String) -> String {
        let collapsed = title
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return collapsed.replacingOccurrences(of: "[\\.\\:\\-]+$", with: "", options: .regularExpression)
    }

    static func assertTitles(
        expected: [String],
        actual: [String],
        fixtureName: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let minCount = min(expected.count, actual.count)
        var firstMismatchIndex: Int?

        for i in 0..<minCount {
            if normalizeTitle(actual[i]) != normalizeTitle(expected[i]) {
                firstMismatchIndex = i
                break
            }
        }

        if firstMismatchIndex == nil && expected.count == actual.count {
            return
        }

        let previewActual = actual.prefix(6).joined(separator: " | ")
        let previewExpected = expected.prefix(6).joined(separator: " | ")
        let tailActual = actual.suffix(4).joined(separator: " | ")
        let tailExpected = expected.suffix(4).joined(separator: " | ")

        if let idx = firstMismatchIndex {
            XCTFail(
                "\(fixtureName): first mismatch at chapter #\(idx + 1). expected='\(expected[idx])' actual='\(actual[idx])'. expectedCount=\(expected.count) actualCount=\(actual.count). expectedPreview=[\(previewExpected)] actualPreview=[\(previewActual)] expectedTail=[\(tailExpected)] actualTail=[\(tailActual)]",
                file: file,
                line: line
            )
            return
        }

        XCTFail(
            "\(fixtureName): chapter count mismatch with aligned prefix. expectedCount=\(expected.count) actualCount=\(actual.count). expectedPreview=[\(previewExpected)] actualPreview=[\(previewActual)] expectedTail=[\(tailExpected)] actualTail=[\(tailActual)]",
            file: file,
            line: line
        )

    }
}
