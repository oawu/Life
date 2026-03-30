import XCTest

/// 邊界條件測試（EDGE-001 ~ EDGE-006）
/// 驗證訪客備份提醒、空狀態、多幣別、大金額、統計圖表、帳本切換
final class EdgeTests: XCTestCase {
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

    private func addGuestExpense(amount: Int) {
        let expenseTab = app.tabBars.buttons["記帳"]
        expenseTab.tap()

        for digit in String(amount) {
            app.buttons["calc_\(digit)"].tap()
        }

        app.buttons["cat_breakfast"].tap()
        app.buttons["btn_save_expense"].tap()
        sleep(1)
    }

    private func goToExpenseList() {
        let expenseTab = app.tabBars.buttons["記帳"]
        expenseTab.tap()
        let listBtn = app.buttons["btn_expense_list"]
        XCTAssertTrue(listBtn.waitForExistence(timeout: 5), "明細按鈕未出現")
        listBtn.tap()
        sleep(1)
    }

    private func backToAddExpense() {
        let backBtn = app.navigationBars.buttons.element(boundBy: 0)
        if backBtn.exists {
            backBtn.tap()
            sleep(1)
        }
    }

    // MARK: - EDGE-001：訪客 10 筆備份提醒

    func test_EDGE001_guestBackupReminder() {
        // 訪客模式：不登入，連續新增 10 筆開銷
        for i in 1...10 {
            addGuestExpense(amount: i)
        }

        // alert 延遲 1.5s，等待充足時間
        sleep(3)

        // 驗證備份提醒 alert 出現
        let alert = app.alerts["備份提醒"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "備份提醒 alert 未出現")

        // 驗證 alert message 含「10 筆開銷」
        let message = alert.staticTexts["你已記錄 10 筆開銷，登入以備份資料到雲端"]
        XCTAssertTrue(message.exists, "alert 訊息內容不正確")

        // 點「稍後」關閉 alert
        alert.buttons["稍後"].tap()
        sleep(1)

        // 確認 alert 已關閉
        XCTAssertFalse(alert.exists, "alert 應已關閉")
    }

    // MARK: - EDGE-002：空狀態顯示

    func test_EDGE002_emptyState() {
        devLogin()

        // 進入開銷列表
        goToExpenseList()

        // 驗證空狀態文字「尚無開銷紀錄」存在
        XCTAssertTrue(
            app.staticTexts["尚無開銷紀錄"].waitForExistence(timeout: 5),
            "空狀態文字未出現"
        )

        // 驗證空狀態元素存在（VStack）
        let emptyView = app.descendants(matching: .any).matching(identifier: "expense_list_empty").firstMatch
        XCTAssertTrue(emptyView.waitForExistence(timeout: 3), "空狀態元素未出現")
    }

    // MARK: - EDGE-003：多幣別帳本切換

    func test_EDGE003_multiCurrencyLedgerSwitch() {
        // API 前置：建立 JPY 群組帳本
        guard let tokenA = TestHelper.devLogin(email: "test@test.com") else {
            XCTFail("登入失敗")
            return
        }
        guard let jpyLedger = TestHelper.createGroupLedger(token: tokenA, name: "日本旅遊", currency: "JPY") else {
            XCTFail("建立 JPY 群組帳本失敗")
            return
        }
        guard let jpyLedgerId = jpyLedger["id"] as? Int else {
            XCTFail("取不到 JPY 帳本 ID")
            return
        }
        let jpyLedgerIdStr = String(jpyLedgerId)

        // 重啟 App → UI 登入
        app.terminate()
        app.launchArguments = ["--reset-local-data"]
        app.launch()
        sleep(2)
        devLogin()

        // 個人帳本新增 100 元
        addExpense(amount: 100, categoryKey: "breakfast")

        // 進入開銷列表
        goToExpenseList()

        // 驗證個人帳本：金額 100 + 新台幣標籤
        XCTAssertTrue(
            app.staticTexts["100"].waitForExistence(timeout: 5),
            "個人帳本應顯示 100"
        )
        XCTAssertTrue(
            app.staticTexts["新台幣"].waitForExistence(timeout: 3),
            "個人帳本應顯示「新台幣」標籤"
        )

        // 切到 JPY 群組帳本
        let jpyPill = app.buttons["ledger_\(jpyLedgerIdStr)"]
        XCTAssertTrue(jpyPill.waitForExistence(timeout: 5), "JPY 帳本 pill 未出現")
        jpyPill.tap()
        sleep(2)

        // 驗證空狀態
        XCTAssertTrue(
            app.staticTexts["尚無開銷紀錄"].waitForExistence(timeout: 5),
            "JPY 帳本應為空"
        )

        // 返回記帳頁 → 在 JPY 帳本新增 500 元
        backToAddExpense()
        addExpense(amount: 500, categoryKey: "groupDining")

        // 進入開銷列表 → 切到 JPY 帳本
        goToExpenseList()
        let jpyPillAfter = app.buttons["ledger_\(jpyLedgerIdStr)"]
        XCTAssertTrue(jpyPillAfter.waitForExistence(timeout: 5), "JPY 帳本 pill 未出現")
        jpyPillAfter.tap()
        sleep(2)

        // 驗證 JPY 帳本：金額 500 + 日幣標籤
        XCTAssertTrue(
            app.staticTexts["500"].waitForExistence(timeout: 5),
            "JPY 帳本應顯示 500"
        )
        XCTAssertTrue(
            app.staticTexts["日幣"].waitForExistence(timeout: 3),
            "JPY 帳本應顯示「日幣」標籤"
        )
    }

    // MARK: - EDGE-004：大金額處理

    func test_EDGE004_largeAmountFormatting() {
        devLogin()

        // 輸入 9999999（7 位數）
        addExpense(amount: 9999999, categoryKey: "breakfast")

        // 進入開銷列表
        goToExpenseList()

        // 驗證千分位格式「9,999,999」
        XCTAssertTrue(
            app.staticTexts["9,999,999"].waitForExistence(timeout: 5),
            "大金額應以千分位格式顯示 9,999,999"
        )

        // MySQL 驗證
        let row = TestHelper.queryMySQL("SELECT amount FROM Expense WHERE amount = 9999999 LIMIT 1")
        XCTAssertNotNil(row, "Server 應有 amount=9999999 的開銷")
    }

    // MARK: - EDGE-005：統計圖表

    func test_EDGE005_expenseChart() {
        devLogin()

        // 新增 3 筆不同分類開銷：100 + 200 + 300 = 600
        addExpense(amount: 100, categoryKey: "breakfast")
        addExpense(amount: 200, categoryKey: "lunch")
        addExpense(amount: 300, categoryKey: "dinner")

        // 進入開銷列表
        goToExpenseList()

        // 點 chart 按鈕
        let chartBtn = app.buttons["btn_chart"]
        XCTAssertTrue(chartBtn.waitForExistence(timeout: 5), "Chart 按鈕未出現")
        chartBtn.tap()
        sleep(1)

        // 驗證導航標題「開銷統計」
        XCTAssertTrue(
            app.navigationBars["開銷統計"].waitForExistence(timeout: 5),
            "開銷統計頁面未出現"
        )

        // 驗證合計金額「600」存在（圖表中心顯示 $600）
        XCTAssertTrue(
            app.staticTexts["$600"].waitForExistence(timeout: 5),
            "月統計應顯示合計 $600"
        )

        // 切到年 Tab
        let yearTab = app.buttons["年"]
        XCTAssertTrue(yearTab.waitForExistence(timeout: 3), "年 Tab 未出現")
        yearTab.tap()
        sleep(1)

        // 驗證年統計仍有 600
        XCTAssertTrue(
            app.staticTexts["$600"].waitForExistence(timeout: 5),
            "年統計應仍顯示合計 $600"
        )
    }

    // MARK: - EDGE-006：帳本切換（LedgerSwitcher + PayerChips）

    func test_EDGE006_ledgerSwitcherPayerChips() {
        // API 前置：建立群組帳本 + 邀請用戶 B
        guard let tokenA = TestHelper.devLogin(email: "test@test.com") else {
            XCTFail("用戶 A 登入失敗")
            return
        }
        guard let tokenB = TestHelper.devLogin(email: "test2@test.com") else {
            XCTFail("用戶 B 登入失敗")
            return
        }
        guard let groupLedger = TestHelper.createGroupLedger(token: tokenA, name: "測試群組") else {
            XCTFail("建立群組帳本失敗")
            return
        }
        guard let groupLedgerIdNum = groupLedger["id"] as? Int else {
            XCTFail("取不到群組帳本 ID")
            return
        }
        let groupLedgerId = String(groupLedgerIdNum)

        guard let inviteCode = groupLedger["inviteCode"] as? String else {
            XCTFail("取不到邀請碼")
            return
        }
        _ = TestHelper.joinLedgerViaAPI(token: tokenB, inviteCode: inviteCode)

        // 重啟 App → UI 登入
        app.terminate()
        app.launchArguments = ["--reset-local-data"]
        app.launch()
        sleep(2)
        devLogin()

        // 記帳頁：驗證個人帳本已選中，PayerChips 不存在
        let expenseTab = app.tabBars.buttons["記帳"]
        expenseTab.tap()
        sleep(1)

        XCTAssertFalse(
            app.staticTexts["付款人"].exists,
            "個人帳本不應顯示付款人"
        )

        // 切到群組帳本 pill
        let groupPill = app.buttons["ledger_\(groupLedgerId)"]
        XCTAssertTrue(groupPill.waitForExistence(timeout: 5), "群組帳本 pill 未出現")
        groupPill.tap()
        sleep(2)

        // 驗證 PayerChips 出現
        XCTAssertTrue(
            app.staticTexts["付款人"].waitForExistence(timeout: 5),
            "群組帳本應顯示付款人區塊"
        )

        // 在群組帳本新增開銷
        for digit in String(100) {
            app.buttons["calc_\(digit)"].tap()
        }
        let groupCat = app.buttons["cat_groupDining"]
        XCTAssertTrue(groupCat.waitForExistence(timeout: 5), "groupDining 分類未出現")
        groupCat.tap()
        app.buttons["btn_save_expense"].tap()
        sleep(2)

        // 查詢個人帳本 ID（group ledger 先建立，personal 在 UI login 時建立，ID 不固定）
        guard let personalRow = TestHelper.queryMySQL(
            "SELECT id FROM Ledger WHERE type = 'personal' AND createdByUserId = (SELECT id FROM User WHERE email = 'test@test.com') LIMIT 1"
        ) else {
            XCTFail("找不到個人帳本")
            return
        }
        let personalLedgerId: String
        if let idStr = personalRow["id"] as? String {
            personalLedgerId = idStr
        } else if let idNum = personalRow["id"] as? Int {
            personalLedgerId = String(idNum)
        } else {
            XCTFail("無法解析個人帳本 ID")
            return
        }

        // 切回個人帳本 → 驗證 PayerChips 消失
        let personalPill = app.buttons["ledger_\(personalLedgerId)"]
        XCTAssertTrue(personalPill.waitForExistence(timeout: 5), "個人帳本 pill 未出現")
        personalPill.tap()
        sleep(2)

        XCTAssertFalse(
            app.staticTexts["付款人"].exists,
            "切回個人帳本後不應顯示付款人"
        )

        // 再切回群組帳本 → 進入開銷列表驗證開銷
        let groupPillAgain = app.buttons["ledger_\(groupLedgerId)"]
        groupPillAgain.tap()
        sleep(1)

        goToExpenseList()
        sleep(1)

        // 驗證開銷存在
        XCTAssertTrue(
            app.staticTexts["100"].waitForExistence(timeout: 5),
            "群組帳本應顯示 100 開銷"
        )
    }
}
