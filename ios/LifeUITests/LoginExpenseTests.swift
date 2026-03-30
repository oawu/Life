import XCTest

/// 登入後建立開銷，透過 MySQL 驗證資料正確
final class LoginExpenseTests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false

        TestHelper.resetBackend()

        app = XCUIApplication()
        app.launchArguments = ["--reset-local-data"]
        app.launch()
    }

    func test_loginAndAddExpense_verifyInDB() {
        // === 1. 切到個人 Tab，開發者登入 ===
        let profileTab = app.tabBars.buttons["個人"]
        XCTAssertTrue(profileTab.waitForExistence(timeout: 10), "個人 Tab 未出現")
        profileTab.tap()

        let devLoginBtn = app.buttons["btn_dev_login"]
        XCTAssertTrue(devLoginBtn.waitForExistence(timeout: 5), "開發者登入按鈕未出現")
        devLoginBtn.tap()

        // alert 彈出：清除預設 email，填入測試帳號
        let emailField = app.alerts["開發者登入"].collectionViews.textFields["Email"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 5), "Email 輸入框未出現")
        emailField.tap()

        // triple tap 全選文字，再刪除
        emailField.tap(withNumberOfTaps: 3, numberOfTouches: 1)
        emailField.typeText(String(XCUIKeyboardKey.delete.rawValue))

        emailField.typeText("test@test.com")

        let loginBtn = app.alerts["開發者登入"].buttons["登入"]
        XCTAssertTrue(loginBtn.exists, "登入按鈕未出現")
        loginBtn.tap()

        // 處理同步資料 alert（有 guest 開銷時出現）
        let syncAlert = app.alerts["同步資料"]
        if syncAlert.waitForExistence(timeout: 3) {
            syncAlert.buttons["上傳"].tap()
        }

        // 登入後自動跳到記帳 Tab，確保在記帳頁
        let expenseTab = app.tabBars.buttons["記帳"]
        XCTAssertTrue(expenseTab.waitForExistence(timeout: 10), "記帳 Tab 未出現")
        expenseTab.tap()
        sleep(3)

        // === 2. 輸入金額 250 ===
        app.buttons["calc_2"].tap()
        app.buttons["calc_5"].tap()
        app.buttons["calc_0"].tap()

        // === 3. 選擇「早餐」分類 ===
        let breakfast = app.buttons["cat_breakfast"]
        XCTAssertTrue(breakfast.waitForExistence(timeout: 5), "分類未出現")
        breakfast.tap()

        // === 4. 儲存 ===
        let saveBtn = app.buttons["btn_save_expense"]
        XCTAssertTrue(saveBtn.exists, "儲存按鈕不存在")
        saveBtn.tap()

        // 等待儲存完成
        sleep(2)
        let display = app.staticTexts.matching(identifier: "calc_display").firstMatch
        XCTAssertTrue(display.waitForExistence(timeout: 3), "計算機顯示區未找到")
        XCTAssertEqual(display.label, "0", "儲存後金額應歸零")

        // === 5. 等待 API 完成，透過 MySQL 驗證資料 ===
        sleep(2)
        let expense = TestHelper.queryMySQL(
            "SELECT e.amount, c.`key` as categoryKey FROM Expense e LEFT JOIN Category c ON e.categoryId = c.id WHERE e.amount = 250 LIMIT 1"
        )
        XCTAssertNotNil(expense, "MySQL 查無金額 250 的 Expense 資料")
        XCTAssertEqual(expense?["amount"] as? String, "250", "金額應為 250")
        XCTAssertEqual(expense?["categoryKey"] as? String, "breakfast", "分類應為 breakfast")
    }
}
