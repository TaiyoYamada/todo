import XCTest

/// アプリが起動し、最初の画面が出ることだけを確かめる。
final class LaunchTests: XCTestCase {
    @MainActor
    func testLaunchesIntoTodayWithSampleData() {
        let app = XCUIApplication()
        app.launchArguments += ["-sampleData", "countdown", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Lock forecast"].waitForExistence(timeout: 10))
    }
}
