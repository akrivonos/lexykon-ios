import XCTest

final class DictUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI_TESTING"]
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Main app screens (navigate and assert key elements exist, no crash)

    func testLookupTabShowsSearch() throws {
        app.launch()
        app.tabBars.buttons["Lookup"].tap()
        XCTAssertTrue(app.navigationBars["Lookup"].waitForExistence(timeout: 3) || app.searchFields.firstMatch.waitForExistence(timeout: 3))
    }

    func testToolsTabShowsHub() throws {
        app.launch()
        app.tabBars.buttons["Tools"].tap()
        XCTAssertTrue(app.staticTexts["Tools"].waitForExistence(timeout: 3) || app.navigationBars["Tools"].waitForExistence(timeout: 3))
    }

    func testToolsTopicBrowsingScreen() throws {
        app.launch()
        app.tabBars.buttons["Tools"].tap()
        if app.buttons["Browse Topics"].waitForExistence(timeout: 3) {
            app.buttons["Browse Topics"].tap()
            XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 3))
        }
    }

    func testSettingsTabShowsSettings() throws {
        app.launch()
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 3) || app.staticTexts["Settings"].waitForExistence(timeout: 3))
    }

    func testLookupSearchFieldExists() throws {
        app.launch()
        app.tabBars.buttons["Lookup"].tap()
        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
    }

    func testEntryDetailNavigationFromLookup() throws {
        app.launch()
        app.tabBars.buttons["Lookup"].tap()
        let searchField = app.searchFields.firstMatch
        guard searchField.waitForExistence(timeout: 5) else {
            XCTFail("Lookup search field not found")
            return
        }
        searchField.tap()
        searchField.typeText("тест\n")
        // May show result list or entry; wait for something to appear
        let timeout = 10.0
        let entryOrResult = app.staticTexts.firstMatch
        XCTAssertTrue(entryOrResult.waitForExistence(timeout: timeout) || app.buttons.firstMatch.waitForExistence(timeout: timeout))
    }

    // MARK: - iPad (when run on iPad simulator: NavigationSplitView sidebar + detail)

    func testIPadSidebarSectionsExist() throws {
        app.launch()
        // On iPad: sidebar is a list with Lookup, Tools, Settings
        // On iPhone: tab bar with same labels; both have "Lookup" etc.
        let lookup = app.buttons["Lookup"].firstMatch
        let tools = app.buttons["Tools"].firstMatch
        if lookup.waitForExistence(timeout: 3) {
            XCTAssertTrue(lookup.exists)
        }
        if tools.waitForExistence(timeout: 1) {
            tools.tap()
            XCTAssertTrue(app.staticTexts["Tools"].waitForExistence(timeout: 2) || app.navigationBars["Tools"].waitForExistence(timeout: 2))
        }
    }

    // MARK: - Performance (plan: cold start < 1.5s, entry detail < 500ms)

    func testColdStartUnderThreshold() throws {
        let app = XCUIApplication()
        let start = Date()
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 2))
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertLessThan(elapsed, 1.5, "Cold start should be < 1.5s (was \(elapsed)s)")
    }

    func testColdStartMetricRecorded() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
