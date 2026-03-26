import XCTest

/// 示範：每次測試前重設後端資料庫，確保乾淨狀態
final class ResetTests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false

        // 每次測試前重設後端資料庫
        TestHelper.resetBackend()

        app = XCUIApplication()
        app.launch()
    }

    // 重設後以訪客身份新增開銷，確認儲存成功
    func test_guestAddExpense_afterReset() {
        let tab = app.tabBars.buttons["記帳"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10), "首頁未載入")

        // 輸入 100
        app.buttons["calc_1"].tap()
        app.buttons["calc_0"].tap()
        app.buttons["calc_0"].tap()

        // 選早餐分類
        let breakfast = app.buttons["cat_breakfast"]
        XCTAssertTrue(breakfast.waitForExistence(timeout: 3), "分類未出現")
        breakfast.tap()

        // 儲存
        app.buttons["btn_save_expense"].tap()

        // 驗證歸零 = 儲存成功
        sleep(2)
        let display = app.staticTexts.matching(identifier: "calc_display").firstMatch
        XCTAssertTrue(display.waitForExistence(timeout: 3), "計算機顯示區未找到")
        XCTAssertEqual(display.label, "0", "儲存後金額應歸零")
    }
}
