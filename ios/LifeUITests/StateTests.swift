import XCTest

/// 狀態重整測試（STA-001 ~ STA-003）
/// 驗證 App 回前景時 refreshState 能正確重建快取
final class StateTests: XCTestCase {
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

    // MARK: - STA-001：回前景 rebuild — Server 有新資料

    func test_STA001_foreground_rebuild_serverNewData() {
        // API 前置：兩個用戶 + 群組帳本（模擬「另一裝置」新增開銷）
        guard let tokenA = TestHelper.devLogin(email: "test@test.com") else {
            XCTFail("用戶 A 登入失敗")
            return
        }
        guard let tokenB = TestHelper.devLogin(email: "test2@test.com") else {
            XCTFail("用戶 B 登入失敗")
            return
        }

        guard let groupLedger = TestHelper.createGroupLedger(token: tokenA, name: "共用帳本") else {
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

        guard let userBId = TestHelper.getUserId(email: "test2@test.com") else {
            XCTFail("取不到用戶 B 的 ID")
            return
        }

        // 重啟 App → UI 登入（用戶 A）
        app.terminate()
        app.launchArguments = ["--reset-local-data"]
        app.launch()
        sleep(2)
        devLogin()

        // 開銷列表 → 切到群組帳本
        goToExpenseList()
        let groupPill = app.buttons["ledger_\(groupLedgerId)"]
        XCTAssertTrue(groupPill.waitForExistence(timeout: 5), "群組帳本 pill 未出現")
        groupPill.tap()
        sleep(2)

        // 驗證列表目前沒有 777
        let has777Before = app.staticTexts["777"].waitForExistence(timeout: 3)
        XCTAssertFalse(has777Before, "列表不應有 777 開銷")

        // 返回記帳頁
        backToAddExpense()

        // 用戶 B 新增開銷 777（模擬另一裝置新增）
        let result = TestHelper.addExpenseViaAPI(
            token: tokenB,
            ledgerId: groupLedgerIdNum,
            amount: 777,
            paidByUserId: userBId
        )
        XCTAssertNotNil(result, "用戶 B 新增開銷失敗")

        // 送到背景 → 回前景（觸發 refreshState）
        XCUIDevice.shared.press(.home)
        sleep(2)
        app.activate()
        sleep(5)

        // 進入開銷列表 → 切到群組帳本驗證
        goToExpenseList()
        let groupPillAfter = app.buttons["ledger_\(groupLedgerId)"]
        if groupPillAfter.waitForExistence(timeout: 5) {
            groupPillAfter.tap()
            sleep(2)
        }

        XCTAssertTrue(
            app.staticTexts["777"].waitForExistence(timeout: 10),
            "回前景後應顯示另一用戶新增的 777 開銷"
        )

        // MySQL 驗證
        let row = TestHelper.queryMySQL("SELECT COUNT(*) as count FROM Expense WHERE amount = 777")
        XCTAssertEqual(row?["count"] as? String, "1", "Server 應有 1 筆 amount=777 的開銷")
    }

    // MARK: - STA-002：回前景 — 群組帳本另一成員新增開銷

    func test_STA002_foreground_rebuild_groupMemberNewExpense() {
        // API 前置：兩個用戶 + 群組帳本
        guard let tokenA = TestHelper.devLogin(email: "test@test.com") else {
            XCTFail("用戶 A 登入失敗")
            return
        }
        guard let tokenB = TestHelper.devLogin(email: "test2@test.com") else {
            XCTFail("用戶 B 登入失敗")
            return
        }

        // A 建立群組帳本
        guard let groupLedger = TestHelper.createGroupLedger(token: tokenA, name: "測試群組") else {
            XCTFail("建立群組帳本失敗")
            return
        }
        guard let groupLedgerIdNum = groupLedger["id"] as? Int else {
            XCTFail("取不到群組帳本 ID")
            return
        }
        let groupLedgerId = String(groupLedgerIdNum)

        // B 加入群組
        guard let inviteCode = groupLedger["inviteCode"] as? String else {
            XCTFail("取不到邀請碼")
            return
        }
        _ = TestHelper.joinLedgerViaAPI(token: tokenB, inviteCode: inviteCode)

        // 取得用戶 B 的 userId
        guard let userBId = TestHelper.getUserId(email: "test2@test.com") else {
            XCTFail("取不到用戶 B 的 ID")
            return
        }

        // UI 登入用戶 A → 重啟 App 以載入群組帳本
        app.terminate()
        app.launchArguments = ["--reset-local-data"]
        app.launch()
        sleep(2)
        devLogin(email: "test@test.com")

        // 進入開銷列表 → 切到群組帳本
        goToExpenseList()
        let groupPill = app.buttons["ledger_\(groupLedgerId)"]
        XCTAssertTrue(groupPill.waitForExistence(timeout: 5), "群組帳本 pill 未出現")
        groupPill.tap()
        sleep(2)

        // 驗證列表目前沒有 888
        let has888Before = app.staticTexts["888"].waitForExistence(timeout: 3)
        XCTAssertFalse(has888Before, "列表不應有 888 開銷")

        // 返回記帳頁
        backToAddExpense()

        // 用戶 B 在群組帳本新增開銷（App 尚未 refresh，不會看到）
        let result = TestHelper.addExpenseViaAPI(
            token: tokenB,
            ledgerId: groupLedgerIdNum,
            amount: 888,
            paidByUserId: userBId
        )
        XCTAssertNotNil(result, "用戶 B 新增開銷失敗")

        // 送到背景 → 回前景（觸發 refreshState）
        XCUIDevice.shared.press(.home)
        sleep(2)
        app.activate()
        sleep(5)

        // 進入開銷列表 → 切到群組帳本驗證
        goToExpenseList()
        let groupPillAfter = app.buttons["ledger_\(groupLedgerId)"]
        if groupPillAfter.waitForExistence(timeout: 5) {
            groupPillAfter.tap()
            sleep(2)
        }

        XCTAssertTrue(
            app.staticTexts["888"].waitForExistence(timeout: 10),
            "回前景後應顯示用戶 B 新增的 888 開銷"
        )
    }

    // MARK: - STA-003：回前景 rebuild — 保留未同步開銷

    func test_STA003_foreground_rebuild_preserveUnsyncedExpenses() {
        // UI 登入
        devLogin()

        // 離線模式 → 新增開銷 500
        toggleOffline()
        addExpense(amount: 500, categoryKey: "breakfast")

        // 恢復網路
        toggleOnline()

        // 送到背景 → 回前景（觸發 syncOfflineExpenses + refreshState）
        XCUIDevice.shared.press(.home)
        sleep(2)
        app.activate()
        sleep(5)

        // 進入開銷列表驗證
        goToExpenseList()
        XCTAssertTrue(
            app.staticTexts["500"].waitForExistence(timeout: 10),
            "回前景後離線開銷 500 應仍在列表"
        )

        // MySQL 驗證：已同步到 Server
        let row = TestHelper.queryMySQL("SELECT COUNT(*) as count FROM Expense WHERE amount = 500")
        XCTAssertEqual(row?["count"] as? String, "1", "離線開銷應已同步到 Server")
    }
}
