//
//  StopScrollUITests.swift
//  StopScrollUITests
//
//  Created by Quentin Rebergue on 19/04/2026.
//

import XCTest

final class StopScrollUITests: XCTestCase {
    private var app: XCUIApplication!

    private func findElement(_ identifiers: [String]) -> XCUIElement {
        for id in identifiers {
            let any = app.descendants(matching: .any)[id]
            if any.exists { return any }
        }
        return app.descendants(matching: .any)[identifiers.first ?? ""]
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments.append("-uiTestBootstrapBook")
        app.launch()
    }

    @MainActor
    func testBookReaderSettingsSectionsAreReachable() throws {
        let bookTab = findElement(["native.tab.book", "native-tab-book"])
        XCTAssertTrue(bookTab.waitForExistence(timeout: 12))
        bookTab.tap()

        let openSettingsButton = app.buttons["bookreader.openSettings"]
        XCTAssertTrue(openSettingsButton.waitForExistence(timeout: 12))
        openSettingsButton.tap()

        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 12))

        XCTAssertTrue(app.staticTexts["Reading Mode"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Library"].exists)
        XCTAssertTrue(app.staticTexts["Data"].exists)

        let doneButton = app.buttons["booksettings.done"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 8))
        doneButton.tap()
    }

    @MainActor
    func testDashboardCanOpenAppSettings() throws {
        let dashboardTab = findElement(["native.tab.dashboard", "native-tab-dashboard"])
        XCTAssertTrue(dashboardTab.waitForExistence(timeout: 12))
        dashboardTab.tap()

        let openSettingsButton = app.buttons["dashboard.openSettings"]
        XCTAssertTrue(openSettingsButton.waitForExistence(timeout: 12))
        openSettingsButton.tap()

        XCTAssertTrue(app.navigationBars["StopScroll Settings"].waitForExistence(timeout: 12))
    }
}
