import XCTest

/// 固定開銷測試（REC-001 ~ REC-006）
final class RecurringExpenseTests: XCTestCase {
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
        sleep(3) // 等待 initAfterLogin 完成狀態重建
    }

    private func goToLedgerSettings() {
        let expenseTab = app.tabBars.buttons["記帳"]
        XCTAssertTrue(expenseTab.waitForExistence(timeout: 10), "記帳 Tab 未出現")
        expenseTab.tap()

        let settingsBtn = app.buttons["btn_ledger_settings"]
        XCTAssertTrue(settingsBtn.waitForExistence(timeout: 5), "帳本設定按鈕未出現")
        settingsBtn.tap()
        sleep(1)
    }

    private func goToRecurringList() {
        goToLedgerSettings()

        let recurringBtn = app.buttons["btn_personal_recurring"]
        XCTAssertTrue(recurringBtn.waitForExistence(timeout: 5), "固定開銷按鈕未出現")
        recurringBtn.tap()
        sleep(1)
    }

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

    private func getPersonalLedgerId(token: String) -> Int? {
        // 呼叫 /api/auth/init 確保 personal ledger 已建立
        _ = TestHelper.apiPost(path: "/api/auth/init", token: token, body: ["expenses": []])

        let row = TestHelper.queryMySQL(
            "SELECT l.id FROM Ledger l JOIN LedgerMember lm ON l.id = lm.ledgerId WHERE l.type = 'personal' AND lm.userId = (SELECT id FROM User WHERE email = 'test@test.com' LIMIT 1) LIMIT 1"
        )
        if let idStr = row?["id"] as? String {
            return Int(idStr)
        }
        return row?["id"] as? Int
    }

    /// 取得 API 回傳的 recurring expense ID（字串）
    private func extractId(_ dict: [String: Any]?) -> String {
        guard let id = dict?["id"] else {
            return ""
        }
        if let idInt = id as? Int {
            return String(idInt)
        }
        if let idStr = id as? String {
            return idStr
        }
        return ""
    }

    /// 透過 descendants 查找 row（List 中的 Button 在 accessibility tree 可能不是 .button 類型）
    private func findRecurringRow(id: String) -> XCUIElement {
        return app.descendants(matching: .any).matching(identifier: "recurring_\(id)").firstMatch
    }

    // MARK: - REC-001：建立固定開銷

    func test_REC001_auth_online_addRecurring() {
        // API 登入取得 token（確保後端有用戶）
        let token = TestHelper.devLogin()
        XCTAssertNotNil(token, "API 登入失敗")

        let ledgerId = getPersonalLedgerId(token: token!)
        XCTAssertNotNil(ledgerId, "取不到 personal ledgerId")

        // UI 登入
        devLogin()
        goToRecurringList()

        // 驗證空狀態
        XCTAssertTrue(
            app.staticTexts["尚無固定開銷"].waitForExistence(timeout: 5),
            "應顯示空狀態「尚無固定開銷」"
        )

        // tap + 新增
        let addBtn = app.buttons["btn_add_recurring"]
        XCTAssertTrue(addBtn.waitForExistence(timeout: 5), "新增按鈕未出現")
        addBtn.tap()
        sleep(1)

        // 計算機輸入 300
        app.buttons["calc_3"].tap()
        app.buttons["calc_0"].tap()
        app.buttons["calc_0"].tap()

        // 選分類（breakfast）
        let catBtn = app.buttons["cat_breakfast"]
        XCTAssertTrue(catBtn.waitForExistence(timeout: 5), "分類 breakfast 未出現")
        catBtn.tap()

        // 選頻率（daily）
        let freqBtn = app.buttons["freq_daily"]
        XCTAssertTrue(freqBtn.waitForExistence(timeout: 5), "頻率 daily 未出現")
        freqBtn.tap()

        // 儲存
        let saveBtn = app.buttons["btn_save_recurring"]
        XCTAssertTrue(saveBtn.waitForExistence(timeout: 5), "儲存按鈕未出現")
        saveBtn.tap()
        sleep(3)

        // 驗證列表有 $300
        XCTAssertTrue(
            app.staticTexts["$300"].waitForExistence(timeout: 5),
            "列表應顯示 $300"
        )

        // MySQL 驗證
        let recurring = TestHelper.queryMySQL(
            "SELECT amount, frequencyType FROM RecurringExpense WHERE ledgerId = \(ledgerId!) LIMIT 1"
        )
        XCTAssertNotNil(recurring, "MySQL 應有固定開銷")

        let amount = recurring?["amount"]
        if let amountStr = amount as? String {
            XCTAssertEqual(Int(amountStr), 300, "amount 應為 300")
        } else if let amountInt = amount as? Int {
            XCTAssertEqual(amountInt, 300, "amount 應為 300")
        }

        XCTAssertEqual(recurring?["frequencyType"] as? String, "daily", "frequencyType 應為 daily")
    }

    // MARK: - REC-002：編輯固定開銷

    func test_REC002_auth_online_editRecurring() {
        // API 前置
        guard let token = TestHelper.devLogin() else {
            XCTFail("API 登入失敗")
            return
        }
        guard let ledgerId = getPersonalLedgerId(token: token) else {
            XCTFail("取不到 personal ledgerId")
            return
        }

        let recurring = TestHelper.addRecurringExpenseViaAPI(
            token: token,
            ledgerId: ledgerId,
            amount: 500,
            memo: "舊備註"
        )
        XCTAssertNotNil(recurring, "API 建立固定開銷失敗")
        let recurringIdStr = extractId(recurring)

        // UI 登入
        devLogin()
        goToRecurringList()

        // tap row
        let row = findRecurringRow(id: recurringIdStr)
        XCTAssertTrue(row.waitForExistence(timeout: 10), "固定開銷 row 未出現")
        row.tap()
        sleep(1)

        // 清除備註 → 輸入新備註
        let memoField = app.textFields["輸入備註"]
        XCTAssertTrue(memoField.waitForExistence(timeout: 5), "備註欄位未出現")
        memoField.tap()
        memoField.tap(withNumberOfTaps: 3, numberOfTouches: 1)
        memoField.typeText(String(XCUIKeyboardKey.delete.rawValue))
        memoField.typeText("新備註")

        // 儲存
        let saveBtn = app.buttons["btn_save_recurring"]
        saveBtn.tap()
        sleep(3)

        // 驗證列表顯示「新備註」
        XCTAssertTrue(
            app.staticTexts["新備註"].waitForExistence(timeout: 5),
            "列表應顯示「新備註」"
        )

        // MySQL 驗證
        let updated = TestHelper.queryMySQL(
            "SELECT memo FROM RecurringExpense WHERE id = \(recurringIdStr) LIMIT 1"
        )
        XCTAssertEqual(updated?["memo"] as? String, "新備註", "MySQL memo 應為「新備註」")
    }

    // MARK: - REC-003：刪除固定開銷

    func test_REC003_auth_online_deleteRecurring() {
        // API 前置
        guard let token = TestHelper.devLogin() else {
            XCTFail("API 登入失敗")
            return
        }
        guard let ledgerId = getPersonalLedgerId(token: token) else {
            XCTFail("取不到 personal ledgerId")
            return
        }

        let recurring = TestHelper.addRecurringExpenseViaAPI(
            token: token,
            ledgerId: ledgerId,
            amount: 200,
            memo: "待刪除"
        )
        XCTAssertNotNil(recurring, "API 建立固定開銷失敗")
        let recurringIdStr = extractId(recurring)

        // UI 登入
        devLogin()
        goToRecurringList()

        // tap row → edit sheet
        let row = findRecurringRow(id: recurringIdStr)
        XCTAssertTrue(row.waitForExistence(timeout: 10), "固定開銷 row 未出現")
        row.tap()
        sleep(1)

        // tap 刪除
        let deleteBtn = app.buttons["btn_delete_recurring"]
        XCTAssertTrue(deleteBtn.waitForExistence(timeout: 5), "刪除按鈕未出現")
        deleteBtn.tap()

        // confirmationDialog → tap「刪除」
        let confirmBtn = app.buttons["刪除"]
        XCTAssertTrue(confirmBtn.waitForExistence(timeout: 3), "刪除確認未出現")
        confirmBtn.tap()
        sleep(3)

        // 驗證列表不再顯示「待刪除」
        XCTAssertFalse(
            app.staticTexts["待刪除"].exists,
            "列表不應顯示「待刪除」"
        )

        // MySQL 驗證
        let rows = TestHelper.queryMySQLAll(
            "SELECT id FROM RecurringExpense WHERE ledgerId = \(ledgerId)"
        )
        XCTAssertEqual(rows.count, 0, "MySQL 應無固定開銷")
    }

    // MARK: - REC-004：Toggle isEnabled

    func test_REC004_auth_online_toggleEnabled() {
        // API 前置
        guard let token = TestHelper.devLogin() else {
            XCTFail("API 登入失敗")
            return
        }
        guard let ledgerId = getPersonalLedgerId(token: token) else {
            XCTFail("取不到 personal ledgerId")
            return
        }

        let recurring = TestHelper.addRecurringExpenseViaAPI(
            token: token,
            ledgerId: ledgerId,
            amount: 100
        )
        XCTAssertNotNil(recurring, "API 建立固定開銷失敗")
        let recurringIdStr = extractId(recurring)

        // UI 登入
        devLogin()
        goToRecurringList()

        // 列表應有 1 筆
        let row = findRecurringRow(id: recurringIdStr)
        XCTAssertTrue(row.waitForExistence(timeout: 10), "固定開銷 row 未出現")

        // tap Toggle（使用 coordinate 確保點擊到 Toggle 開關區域）
        let toggle = app.switches.firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 5), "Toggle 未出現")
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        sleep(3)

        // MySQL 驗證 isEnabled = 0
        let updated = TestHelper.queryMySQL(
            "SELECT isEnabled FROM RecurringExpense WHERE id = \(recurringIdStr) LIMIT 1"
        )
        XCTAssertNotNil(updated, "MySQL 應有固定開銷")

        let isEnabled = updated?["isEnabled"]
        var isEnabledInt = 1
        if let str = isEnabled as? String {
            isEnabledInt = Int(str) ?? 1
        } else if let num = isEnabled as? Int {
            isEnabledInt = num
        }
        XCTAssertEqual(isEnabledInt, 0, "isEnabled 應為 0（停用）")
    }

    // MARK: - REC-005：Guest 模式 → 儲存被攔截

    func test_REC005_guest_saveBlocked() {
        // Guest 模式（不登入）
        goToRecurringList()

        // 驗證空狀態
        XCTAssertTrue(
            app.staticTexts["尚無固定開銷"].waitForExistence(timeout: 5),
            "應顯示空狀態"
        )

        // tap + 新增
        let addBtn = app.buttons["btn_add_recurring"]
        XCTAssertTrue(addBtn.waitForExistence(timeout: 5), "新增按鈕未出現")
        addBtn.tap()
        sleep(1)

        // 計算機輸入 100
        app.buttons["calc_1"].tap()
        app.buttons["calc_0"].tap()
        app.buttons["calc_0"].tap()

        // 選分類
        let catBtn = app.buttons["cat_breakfast"]
        XCTAssertTrue(catBtn.waitForExistence(timeout: 5), "分類 breakfast 未出現")
        catBtn.tap()

        // 選頻率
        let freqBtn = app.buttons["freq_daily"]
        XCTAssertTrue(freqBtn.waitForExistence(timeout: 5), "頻率 daily 未出現")
        freqBtn.tap()

        // 儲存
        let saveBtn = app.buttons["btn_save_recurring"]
        saveBtn.tap()
        sleep(2)

        // 驗證「錯誤」alert 出現
        let alert = app.alerts["錯誤"]
        XCTAssertTrue(alert.waitForExistence(timeout: 3), "應顯示「錯誤」alert")
        alert.buttons["確定"].tap()
    }

    // MARK: - REC-006：Auth+Offline → 儲存被攔截

    func test_REC006_auth_offline_saveBlocked() {
        // API 登入
        let token = TestHelper.devLogin()
        XCTAssertNotNil(token, "API 登入失敗")

        // UI 登入
        devLogin()
        toggleOffline()
        goToRecurringList()

        // tap + 新增
        let addBtn = app.buttons["btn_add_recurring"]
        XCTAssertTrue(addBtn.waitForExistence(timeout: 5), "新增按鈕未出現")
        addBtn.tap()
        sleep(1)

        // 計算機輸入 100
        app.buttons["calc_1"].tap()
        app.buttons["calc_0"].tap()
        app.buttons["calc_0"].tap()

        // 選分類
        let catBtn = app.buttons["cat_breakfast"]
        XCTAssertTrue(catBtn.waitForExistence(timeout: 5), "分類 breakfast 未出現")
        catBtn.tap()

        // 選頻率
        let freqBtn = app.buttons["freq_daily"]
        XCTAssertTrue(freqBtn.waitForExistence(timeout: 5), "頻率 daily 未出現")
        freqBtn.tap()

        // 儲存
        let saveBtn = app.buttons["btn_save_recurring"]
        saveBtn.tap()
        sleep(2)

        // 驗證「錯誤」alert 出現
        let alert = app.alerts["錯誤"]
        XCTAssertTrue(alert.waitForExistence(timeout: 3), "應顯示「錯誤」alert")
        alert.buttons["確定"].tap()
    }
}
