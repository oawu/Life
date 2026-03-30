import XCTest

/// 認證流程測試（AUTH-001 ~ AUTH-008）
final class AuthTests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        TestHelper.resetBackend()
        app = XCUIApplication()
        app.launchArguments = ["--reset-local-data"]
        app.launch()
    }

    // MARK: - Helpers

    /// 透過 UI 執行開發者登入
    private func devLogin(email: String = "test@test.com") {
        let profileTab = app.tabBars.buttons["個人"]
        XCTAssertTrue(profileTab.waitForExistence(timeout: 10), "個人 Tab 未出現")
        profileTab.tap()

        let devLoginBtn = app.buttons["btn_dev_login"]
        XCTAssertTrue(devLoginBtn.waitForExistence(timeout: 5), "開發者登入按鈕未出現")
        devLoginBtn.tap()

        let emailField = app.alerts["開發者登入"].collectionViews.textFields["Email"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 5), "Email 輸入框未出現")
        emailField.tap()
        emailField.tap(withNumberOfTaps: 3, numberOfTouches: 1)
        emailField.typeText(String(XCUIKeyboardKey.delete.rawValue))
        emailField.typeText(email)

        app.alerts["開發者登入"].buttons["登入"].tap()

        // 處理同步資料 alert（有 guest 開銷時出現）
        let syncAlert = app.alerts["同步資料"]
        if syncAlert.waitForExistence(timeout: 3) {
            syncAlert.buttons["上傳"].tap()
        }

        // 登入後自動跳到記帳 Tab，切回個人 Tab 驗證登入完成
        app.tabBars.buttons["個人"].tap()

        let signOutBtn = app.buttons["btn_sign_out"]
        XCTAssertTrue(signOutBtn.waitForExistence(timeout: 15), "登入未完成")
    }

    /// 透過 UI 執行登出
    private func logout() {
        let profileTab = app.tabBars.buttons["個人"]
        XCTAssertTrue(profileTab.waitForExistence(timeout: 10), "個人 Tab 未出現")
        profileTab.tap()

        let signOutBtn = app.buttons["btn_sign_out"]
        XCTAssertTrue(signOutBtn.waitForExistence(timeout: 5), "登出按鈕未出現")
        signOutBtn.tap()

        let confirmBtn = app.alerts["確定要登出嗎？"].buttons["登出"]
        XCTAssertTrue(confirmBtn.waitForExistence(timeout: 3), "登出確認未出現")
        confirmBtn.tap()

        // 等待登出完成：回到 GuestProfileView
        let devLoginBtn = app.buttons["btn_dev_login"]
        XCTAssertTrue(devLoginBtn.waitForExistence(timeout: 5), "登出未完成")
    }

    /// 新增一筆開銷
    private func addExpense(amount: Int, categoryKey: String) {
        let expenseTab = app.tabBars.buttons["記帳"]
        XCTAssertTrue(expenseTab.waitForExistence(timeout: 10), "記帳 Tab 未出現")
        expenseTab.tap()

        for digit in String(amount) {
            app.buttons["calc_\(digit)"].tap()
        }

        let cat = app.buttons["cat_\(categoryKey)"]
        XCTAssertTrue(cat.waitForExistence(timeout: 5), "分類 \(categoryKey) 未出現")
        cat.tap()

        app.buttons["btn_save_expense"].tap()
        sleep(2)
    }

    /// 驗證 Guest 模式
    private func assertGuestMode(_ message: String = "應為 Guest 模式") {
        let profileTab = app.tabBars.buttons["個人"]
        profileTab.tap()
        XCTAssertTrue(
            app.buttons["btn_dev_login"].waitForExistence(timeout: 10),
            message
        )
    }

    /// 驗證 Authenticated 模式
    private func assertAuthMode(_ message: String = "應為 Authenticated 模式") {
        let profileTab = app.tabBars.buttons["個人"]
        profileTab.tap()
        XCTAssertTrue(
            app.buttons["btn_sign_out"].waitForExistence(timeout: 10),
            message
        )
    }

    // MARK: - AUTH-001：冷啟動 — 有效 token

    func test_AUTH001_coldStart_validToken() {
        // 登入取得有效 token
        devLogin()

        // 終止 → 重新啟動
        app.terminate()
        app.launch()

        // Keychain token 仍有效 → Authenticated
        assertAuthMode("冷啟動 + 有效 token 應為 Authenticated")
    }

    // MARK: - AUTH-002：冷啟動 — 無 token

    func test_AUTH002_coldStart_noToken() {
        // 直接啟動（無登入）→ Guest
        assertGuestMode("無 token 應為 Guest")

        // Tab 1 應顯示 AddExpenseView
        let expenseTab = app.tabBars.buttons["記帳"]
        expenseTab.tap()
        XCTAssertTrue(
            app.buttons["btn_save_expense"].waitForExistence(timeout: 5),
            "Guest 模式 Tab 1 應顯示記帳頁"
        )
    }

    // MARK: - AUTH-003：冷啟動 — 過期/失效 token

    func test_AUTH003_coldStart_expiredToken() {
        // 登入取得 token
        devLogin()

        // 終止 App + 重設後端（User 消失，token 失效）
        app.terminate()
        TestHelper.resetBackend()
        app.launch()

        // GET /auth/me 失敗 → 清除 token → Guest
        assertGuestMode("token 失效後應降級為 Guest")
    }

    // MARK: - AUTH-004：登入 — 無訪客開銷

    func test_AUTH004_login_noGuestExpenses() {
        // 直接登入（無 guest 開銷）
        devLogin()
        sleep(3) // 等待 initAfterLogin 完成

        // 驗證 DB：個人帳本已建立
        let ledger = TestHelper.queryMySQL(
            "SELECT id, type FROM Ledger WHERE type = 'personal' LIMIT 1"
        )
        XCTAssertNotNil(ledger, "應建立個人帳本")
        XCTAssertEqual(ledger?["type"] as? String, "personal")

        // 驗證 DB：有預設分類
        guard let ledgerId = ledger?["id"] as? String else {
            XCTFail("無法取得帳本 ID")
            return
        }
        let catCount = TestHelper.queryMySQL(
            "SELECT COUNT(*) as count FROM Category WHERE ledgerId = \(ledgerId)"
        )
        let count = Int(catCount?["count"] as? String ?? "0") ?? 0
        XCTAssertGreaterThan(count, 0, "應有預設分類")

        // 驗證 DB：0 筆開銷
        let expCount = TestHelper.queryMySQL(
            "SELECT COUNT(*) as count FROM Expense"
        )
        XCTAssertEqual(expCount?["count"] as? String, "0", "應無開銷")
    }

    // MARK: - AUTH-005：登入 — 有訪客開銷

    func test_AUTH005_login_withGuestExpenses() {
        // Guest 模式新增 5 筆開銷
        addExpense(amount: 100, categoryKey: "breakfast")
        addExpense(amount: 200, categoryKey: "lunch")
        addExpense(amount: 300, categoryKey: "dinner")
        addExpense(amount: 400, categoryKey: "breakfast")
        addExpense(amount: 500, categoryKey: "lunch")

        // 登入 → initAfterLogin 上傳 5 筆
        devLogin()
        sleep(3)

        // 驗證 DB：5 筆開銷
        let expCount = TestHelper.queryMySQL(
            "SELECT COUNT(*) as count FROM Expense"
        )
        XCTAssertEqual(expCount?["count"] as? String, "5", "Server 應有 5 筆開銷")

        // 驗證各分類數量正確
        let breakfastCount = TestHelper.queryMySQL(
            "SELECT COUNT(*) as count FROM Expense e JOIN Category c ON e.categoryId = c.id WHERE c.`key` = 'breakfast'"
        )
        XCTAssertEqual(breakfastCount?["count"] as? String, "2", "breakfast 應有 2 筆")

        let lunchCount = TestHelper.queryMySQL(
            "SELECT COUNT(*) as count FROM Expense e JOIN Category c ON e.categoryId = c.id WHERE c.`key` = 'lunch'"
        )
        XCTAssertEqual(lunchCount?["count"] as? String, "2", "lunch 應有 2 筆")
    }

    // MARK: - AUTH-006：登出

    func test_AUTH006_logout() {
        // 登入 + 新增開銷
        devLogin()
        addExpense(amount: 150, categoryKey: "breakfast")

        // 登出
        logout()

        // 驗證 Guest 模式
        assertGuestMode("登出後應為 Guest")

        // 記帳頁應正常
        let expenseTab = app.tabBars.buttons["記帳"]
        expenseTab.tap()
        XCTAssertTrue(
            app.buttons["btn_save_expense"].waitForExistence(timeout: 5),
            "登出後記帳頁應正常"
        )
    }

    // MARK: - AUTH-007：登出後再登入 — 不重複資料

    func test_AUTH007_logoutAndRelogin_noDuplicates() {
        // 登入 + 新增 5 筆 authenticated 開銷
        devLogin()
        addExpense(amount: 110, categoryKey: "breakfast")
        addExpense(amount: 120, categoryKey: "lunch")
        addExpense(amount: 130, categoryKey: "dinner")
        addExpense(amount: 140, categoryKey: "breakfast")
        addExpense(amount: 150, categoryKey: "lunch")
        sleep(2) // 等待 API 完成

        // 登出
        logout()

        // Guest 模式新增 3 筆
        addExpense(amount: 210, categoryKey: "breakfast")
        addExpense(amount: 220, categoryKey: "lunch")
        addExpense(amount: 230, categoryKey: "dinner")

        // 重新登入 → 上傳 3 筆 guest 開銷
        devLogin()
        sleep(3)

        // 驗證 DB：共 8 筆（5 + 3）
        let expCount = TestHelper.queryMySQL(
            "SELECT COUNT(*) as count FROM Expense"
        )
        XCTAssertEqual(expCount?["count"] as? String, "8", "應有 8 筆（5 + 3）")

        // 驗證只有 1 本 personal ledger
        let ledgerCount = TestHelper.queryMySQL(
            "SELECT COUNT(*) as count FROM Ledger WHERE type = 'personal'"
        )
        XCTAssertEqual(ledgerCount?["count"] as? String, "1", "應只有 1 本個人帳本")
    }

    // MARK: - AUTH-008：冷啟動 — 離線 + 有效 token

    func test_AUTH008_coldStart_offline_validToken() {
        // 登入取得有效 token
        devLogin()

        // 終止 App + 重設後端 + 以離線模式重啟
        app.terminate()
        TestHelper.resetBackend()
        app.launchArguments = ["--force-offline"]
        app.launch()

        // GET /auth/me 失敗 → Guest（不 crash）
        assertGuestMode("離線冷啟動應降級為 Guest（不 crash）")

        // 記帳頁應正常
        let expenseTab = app.tabBars.buttons["記帳"]
        expenseTab.tap()
        XCTAssertTrue(
            app.buttons["btn_save_expense"].waitForExistence(timeout: 5),
            "離線 Guest 記帳頁應正常"
        )
    }
}
