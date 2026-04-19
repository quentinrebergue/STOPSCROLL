import Foundation
import XCTest

final class FileLengthGuardTests: XCTestCase {

    func testFileLengthWarnings() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Tests/
            .deletingLastPathComponent() // StopScroll/
            .deletingLastPathComponent() // repo root

        let sourceRoot = rootURL.appendingPathComponent("StopScroll", isDirectory: true)
        let fm = FileManager.default

        guard let enumerator = fm.enumerator(
            at: sourceRoot,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            XCTFail("Unable to enumerate source files")
            return
        }

        var softWarnings: [String] = []
        var hardWarnings: [String] = []

        for case let fileURL as URL in enumerator {
            let path = fileURL.path
            if path.contains("/Tests/") || path.contains("/Fixtures/") || path.contains("/xcuserdata/") {
                continue
            }

            let ext = fileURL.pathExtension.lowercased()
            if ext != "swift" && ext != "js" && ext != "mjs" { continue }

            guard let contents = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }
            let lineCount = contents.split(whereSeparator: \.isNewline).count
            let relative = fileURL.path.replacingOccurrences(of: rootURL.path + "/", with: "")

            if lineCount > 400 {
                hardWarnings.append("\(relative):\(lineCount)")
            } else if lineCount > 300 {
                softWarnings.append("\(relative):\(lineCount)")
            }
        }

        if !softWarnings.isEmpty {
            XCTContext.runActivity(named: "File length warnings (>300 LOC)") { _ in
                for entry in softWarnings.sorted() {
                    print("warning: [FileLengthGuard] Large file (>300 LOC): \(entry)")
                }
            }
        }

        if !hardWarnings.isEmpty {
            XCTContext.runActivity(named: "File length strong warnings (>400 LOC)") { _ in
                for entry in hardWarnings.sorted() {
                    print("warning: [FileLengthGuard][HIGH] VERY LARGE file (>400 LOC): \(entry)")
                }
            }
        }

        XCTAssertTrue(true)
    }
}
