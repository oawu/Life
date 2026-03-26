import XCTest

/// 離線同步測試（SYNC-001 ~ SYNC-005）
final class SyncTests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        TestHelper.resetBackend()
        app = XCUIApplication()
        app.launchArguments = ["--reset-local-data"]
        app.launch()
    }

    // MARK: - UI Helpers

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

        let signOutBtn = app.buttons["btn_sign_out"]
        XCTAssertTrue(signOutBtn.waitForExistence(timeout: 10), "登入未完成")
    }

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

    private func goToExpenseList() {
        let expenseTab = app.tabBars.buttons["記帳"]
        expenseTab.tap()
        let listBtn = app.buttons["btn_expense_list"]
        XCTAssertTrue(listBtn.waitForExistence(timeout: 5), "明細按鈕未出現")
        listBtn.tap()
        sleep(1)
    }

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

        let devLoginBtn = app.buttons["btn_dev_login"]
        XCTAssertTrue(devLoginBtn.waitForExistence(timeout: 5), "登出未完成")
    }

    /// 返回記帳頁（從開銷列表 NavigationStack pop 回去）
    private func backToAddExpense() {
        let backBtn = app.navigationBars.buttons.element(boundBy: 0)
        if backBtn.exists {
            backBtn.tap()
            sleep(1)
        }
    }

    /// 透過 Debug Panel 切換離線模式（ON）
    private func toggleOffline() {
        let indicator = app.descendants(matching: .any).matching(identifier: "debug_indicator").firstMatch
        XCTAssertTrue(indicator.waitForExistence(timeout: 3), "Debug indicator 未出現")
        indicator.tap()
        sleep(2)

        let toggle = app.switches["toggle_offline"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5), "離線 Toggle 未出現")

        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        sleep(1)

        if toggle.value as? String != "1" {
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
            sleep(1)
        }
        XCTAssertEqual(toggle.value as? String, "1", "離線 Toggle 應為 ON")

        app.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.3)).tap()
        sleep(1)
    }

    /// 透過 Debug Panel 切換離線模式（OFF）
    private func toggleOnline() {
        let indicator = app.descendants(matching: .any).matching(identifier: "debug_indicator").firstMatch
        XCTAssertTrue(indicator.waitForExistence(timeout: 3), "Debug indicator 未出現")
        indicator.tap()
        sleep(2)

        let toggle = app.switches["toggle_offline"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5), "離線 Toggle 未出現")

        if toggle.value as? String == "1" {
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
            sleep(1)

            if toggle.value as? String != "0" {
                toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
                sleep(1)
            }
        }
        XCTAssertEqual(toggle.value as? String, "0", "離線 Toggle 應為 OFF")

        app.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.3)).tap()
        sleep(1)
    }

    // MARK: - SYNC-001：離線 → 上線自動同步

    func test_SYNC001_offlineToOnline_autoSync() {
        devLogin()
        toggleOffline()

        addExpense(amount: 100, categoryKey: "breakfast")
        addExpense(amount: 200, categoryKey: "lunch")

        // 驗證本地有 2 筆（列表金額不含 $ 前綴）
        goToExpenseList()
        XCTAssertTrue(app.staticTexts["100"].waitForExistence(timeout: 5), "應有 100 開銷")
        XCTAssertTrue(app.staticTexts["200"].exists, "應有 200 開銷")

        // 返回記帳頁 → 上線
        backToAddExpense()
        toggleOnline()
        sleep(5)

        // MySQL 驗證
        let expCount = TestHelper.queryMySQL("SELECT COUNT(*) as count FROM Expense")
        XCTAssertEqual(expCount?["count"] as? String, "2", "Server 應有 2 筆開銷")

        let rows = TestHelper.queryMySQLAll("SELECT amount FROM Expense ORDER BY amount ASC")
        XCTAssertEqual(rows.count, 2, "應有 2 筆")
        XCTAssertEqual(rows[0]["amount"] as? String, "100", "第 1 筆應為 100")
        XCTAssertEqual(rows[1]["amount"] as? String, "200", "第 2 筆應為 200")
    }

    // MARK: - SYNC-002：Server 端有開銷 → 重新登入同步至 App

    func test_SYNC002_reloginSyncsServerExpenses() {
        devLogin()

        // 透過 API 在 Server 端直接新增一筆開銷（App 不知道）
        guard let token = TestHelper.devLogin(email: "test@test.com") else {
            XCTFail("API 登入失敗")
            return
        }
        guard let ledgerRow = TestHelper.queryMySQL("SELECT id FROM Ledger WHERE type = 'personal' LIMIT 1"),
              let ledgerIdStr = ledgerRow["id"] as? String,
              let ledgerId = Int(ledgerIdStr) else {
            XCTFail("無法取得個人帳本 ID")
            return
        }
        let expense = TestHelper.addExpenseViaAPI(token: token, ledgerId: ledgerId, amount: 999)
        XCTAssertNotNil(expense, "API 新增開銷應成功")

        // 確認 Server 端確實有這筆
        let serverCheck = TestHelper.queryMySQL("SELECT COUNT(*) as count FROM Expense WHERE amount = 999")
        XCTAssertEqual(serverCheck?["count"] as? String, "1", "Server 應有 999 開銷")

        // 開銷列表尚無 999（App 還沒同步）
        goToExpenseList()
        let has999Before = app.staticTexts["999"].waitForExistence(timeout: 3)
        XCTAssertFalse(has999Before, "同步前不應有 999")
        backToAddExpense()

        // 登出 → 重新登入（initAfterLogin 拉取完整 state）
        logout()
        devLogin()
        sleep(3) // 等待 initAfterLogin 完成

        // 開銷列表應有 999（列表金額不含 $ 前綴）
        goToExpenseList()
        XCTAssertTrue(app.staticTexts["999"].waitForExistence(timeout: 10), "重新登入後應同步到 Server 的 999 開銷")
    }

    // MARK: - SYNC-003：多帳本離線開銷分別 batch

    func test_SYNC003_multiLedger_batchSync() {
        // 前置：透過 API 建立群組帳本
        guard let token = TestHelper.devLogin(email: "test@test.com") else {
            XCTFail("API 登入失敗")
            return
        }
        guard let groupLedger = TestHelper.createGroupLedger(token: token, name: "測試群組") else {
            XCTFail("建立群組帳本失敗")
            return
        }
        guard let groupLedgerIdNum = groupLedger["id"] as? Int else {
            XCTFail("無法取得群組帳本 ID")
            return
        }
        let groupLedgerId = String(groupLedgerIdNum)

        // 重啟 App 讓 init 載入群組帳本
        app.terminate()
        app.launchArguments = ["--reset-local-data"]
        app.launch()
        devLogin()

        // 切到記帳頁，等待分類載入完成
        let expenseTab = app.tabBars.buttons["記帳"]
        expenseTab.tap()
        let firstCat = app.buttons["cat_breakfast"]
        XCTAssertTrue(firstCat.waitForExistence(timeout: 10), "initAfterLogin 分類載入逾時")

        toggleOffline()

        // 個人帳本（預設）新增 2 筆
        addExpense(amount: 100, categoryKey: "breakfast")
        addExpense(amount: 200, categoryKey: "lunch")

        // 切到群組帳本
        expenseTab.tap()
        let groupPill = app.buttons["ledger_\(groupLedgerId)"]
        XCTAssertTrue(groupPill.waitForExistence(timeout: 5), "群組帳本 pill 未出現")
        groupPill.tap()
        sleep(2) // 等待群組帳本分類載入

        // 群組帳本新增 2 筆（群組帳本使用 groupDining / groupGrocery 分類）
        addExpense(amount: 300, categoryKey: "groupDining")
        addExpense(amount: 400, categoryKey: "groupGrocery")

        // 上線同步
        toggleOnline()
        sleep(5)

        // MySQL 驗證：個人帳本 2 筆
        let personalRow = TestHelper.queryMySQL("SELECT id FROM Ledger WHERE type = 'personal' LIMIT 1")
        guard let personalId = personalRow?["id"] as? String else {
            XCTFail("無法取得個人帳本 ID")
            return
        }
        let personalCount = TestHelper.queryMySQL(
            "SELECT COUNT(*) as count FROM Expense WHERE ledgerId = \(personalId)"
        )
        XCTAssertEqual(personalCount?["count"] as? String, "2", "個人帳本應有 2 筆開銷")

        // MySQL 驗證：群組帳本 2 筆
        let groupCount = TestHelper.queryMySQL(
            "SELECT COUNT(*) as count FROM Expense WHERE ledgerId = \(groupLedgerId)"
        )
        XCTAssertEqual(groupCount?["count"] as? String, "2", "群組帳本應有 2 筆開銷")
    }

    // MARK: - SYNC-004：同步後 Server 資料驗證

    func test_SYNC004_syncDataValidation() {
        devLogin()
        toggleOffline()

        addExpense(amount: 150, categoryKey: "breakfast")
        addExpense(amount: 280, categoryKey: "lunch")

        toggleOnline()
        sleep(5)

        // 驗證金額 150 的開銷
        let expense150 = TestHelper.queryMySQL(
            "SELECT amount, categoryId, createdByUserId, date FROM Expense WHERE amount = 150 LIMIT 1"
        )
        XCTAssertNotNil(expense150, "應有 amount=150 的開銷")
        XCTAssertNotNil(expense150?["categoryId"], "categoryId 不應為 NULL")
        let cat150 = expense150?["categoryId"]
        XCTAssertFalse(cat150 is NSNull, "categoryId 不應為 NSNull")

        // 驗證金額 280 的開銷
        let expense280 = TestHelper.queryMySQL(
            "SELECT amount, categoryId, createdByUserId, date FROM Expense WHERE amount = 280 LIMIT 1"
        )
        XCTAssertNotNil(expense280, "應有 amount=280 的開銷")
        XCTAssertNotNil(expense280?["categoryId"], "categoryId 不應為 NULL")
        let cat280 = expense280?["categoryId"]
        XCTAssertFalse(cat280 is NSNull, "categoryId 不應為 NSNull")

        // 驗證 createdByUserId 一致
        let user = TestHelper.queryMySQL("SELECT id FROM User LIMIT 1")
        guard let userId = user?["id"] as? String else {
            XCTFail("無法取得 User ID")
            return
        }
        XCTAssertEqual(expense150?["createdByUserId"] as? String, userId, "150 的 createdByUserId 應一致")
        XCTAssertEqual(expense280?["createdByUserId"] as? String, userId, "280 的 createdByUserId 應一致")

        // 驗證 date 為今天
        let todayRow = TestHelper.queryMySQL("SELECT CURDATE() as today")
        guard let today = todayRow?["today"] as? String else {
            XCTFail("無法取得今天日期")
            return
        }
        let date150 = (expense150?["date"] as? String ?? "").prefix(10)
        let date280 = (expense280?["date"] as? String ?? "").prefix(10)
        XCTAssertEqual(String(date150), today, "150 的 date 應為今天")
        XCTAssertEqual(String(date280), today, "280 的 date 應為今天")
    }

    // MARK: - SYNC-005：回前景 — 保留未同步開銷

    func test_SYNC005_foreground_preserveUnsyncedExpenses() {
        devLogin()

        // 線上新增 1 筆（synced）
        addExpense(amount: 500, categoryKey: "breakfast")
        sleep(2)

        // 離線新增 2 筆（unsynced）
        toggleOffline()
        addExpense(amount: 600, categoryKey: "lunch")
        addExpense(amount: 700, categoryKey: "dinner")

        // 驗證本地有 3 筆（列表金額不含 $ 前綴）
        goToExpenseList()
        XCTAssertTrue(app.staticTexts["500"].waitForExistence(timeout: 5), "應有 500 開銷")
        XCTAssertTrue(app.staticTexts["600"].exists, "應有 600 開銷")
        XCTAssertTrue(app.staticTexts["700"].exists, "應有 700 開銷")

        // 返回記帳頁
        backToAddExpense()

        // 模擬回前景（離線狀態，sync/refresh skip）
        XCUIDevice.shared.press(.home)
        sleep(2)
        app.activate()
        sleep(3)

        // 仍有 3 筆（未同步開銷保留）
        goToExpenseList()
        XCTAssertTrue(app.staticTexts["500"].waitForExistence(timeout: 5), "回前景後 500 應保留")
        XCTAssertTrue(app.staticTexts["600"].exists, "回前景後 600 應保留")
        XCTAssertTrue(app.staticTexts["700"].exists, "回前景後 700 應保留")

        // 返回記帳頁 → 上線 → 同步 2 筆 unsynced
        backToAddExpense()
        toggleOnline()
        sleep(5)

        // MySQL 驗證：共 3 筆
        let expCount = TestHelper.queryMySQL("SELECT COUNT(*) as count FROM Expense")
        XCTAssertEqual(expCount?["count"] as? String, "3", "Server 應有 3 筆開銷")
    }
}
