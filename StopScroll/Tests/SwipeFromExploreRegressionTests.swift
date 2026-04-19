import XCTest
@testable import StopScroll

final class SwipeFromExploreRegressionTests: XCTestCase {
    func testSwipeDirectionMatchesNavbarOrderFromSearch() {
        XCTAssertEqual(NativeTabLayout.adjacentTab(to: "search", swipeTranslation: 120), "home")
        XCTAssertEqual(NativeTabLayout.adjacentTab(to: "search", swipeTranslation: -120), "book")
    }

    func testSearchSwipeRecognizerIsAppFirst() {
        XCTAssertTrue(HorizontalSwipeRecognizerPolicy.shouldBegin(velocityX: 30, velocityY: 20, activeTab: "search"))
        XCTAssertFalse(HorizontalSwipeRecognizerPolicy.shouldBegin(velocityX: 30, velocityY: 20, activeTab: "home"))
    }
}
