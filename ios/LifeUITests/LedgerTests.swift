import XCTest

/// 帳本管理測試（LDG-001 ~ LDG-011，略過 005/006/009/012）
final class LedgerTests: XCTestCase {
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

    private func goToLedgerSettings() {
        let expenseTab = app.tabBars.buttons["記帳"]
        XCTAssertTrue(expenseTab.waitForExistence(timeout: 10), "記帳 Tab 未出現")
        expenseTab.tap()

        let settingsBtn = app.buttons["btn_ledger_settings"]
        XCTAssertTrue(settingsBtn.waitForExistence(timeout: 5), "帳本設定按鈕未出現")
        settingsBtn.tap()
        sleep(1)
    }

    private func tapAddLedgerMenu(item: String) {
        let menu = app.buttons["menu_add_ledger"]
        XCTAssertTrue(menu.waitForExistence(timeout: 5), "新增帳本按鈕未出現")

        // Scroll into view if needed
        for _ in 0..<3 {
            if menu.isHittable { break }
            app.swipeUp()
            sleep(1)
        }

        menu.tap()
        sleep(1)

        let menuItem = app.buttons[item]
        XCTAssertTrue(menuItem.waitForExistence(timeout: 5), "\(item) 選項未出現")
        menuItem.tap()
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

    // MARK: - LDG-001：Auth+Online 建立群組帳本

    func test_LDG001_auth_online_createGroupLedger() {
        devLogin()
        goToLedgerSettings()

        // tap Menu → "自己建立"
        tapAddLedgerMenu(item: "自己建立")

        // 輸入名稱
        let nameField = app.textFields["field_ledger_name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "帳本名稱輸入框未出現")
        nameField.tap()
        nameField.typeText("旅行基金")

        // 儲存
        let saveBtn = app.buttons["btn_ledger_save"]
        XCTAssertTrue(saveBtn.waitForExistence(timeout: 5), "儲存按鈕未出現")
        saveBtn.tap()
        sleep(3)

        // 驗證列表有「旅行基金」
        XCTAssertTrue(
            app.staticTexts["旅行基金"].waitForExistence(timeout: 5),
            "帳本設定列表應顯示「旅行基金」"
        )

        // MySQL 驗證
        let ledger = TestHelper.queryMySQL(
            "SELECT name, type FROM Ledger WHERE name = '旅行基金' LIMIT 1"
        )
        XCTAssertNotNil(ledger, "MySQL 應有「旅行基金」")
        XCTAssertEqual(ledger?["name"] as? String, "旅行基金")
        XCTAssertEqual(ledger?["type"] as? String, "group")
    }

    // MARK: - LDG-002：Auth+Online 用邀請碼加入帳本

    func test_LDG002_auth_online_joinByInviteCode() {
        // userA 建立群組帳本
        guard let tokenA = TestHelper.devLogin(email: "user_a@test.com") else {
            XCTFail("userA API 登入失敗")
            return
        }
        guard let groupLedger = TestHelper.createGroupLedger(token: tokenA, name: "A的帳本") else {
            XCTFail("建立群組帳本失敗")
            return
        }
        guard let inviteCode = groupLedger["inviteCode"] as? String else {
            XCTFail("無法取得 inviteCode")
            return
        }

        // userB 透過 UI 登入
        devLogin(email: "user_b@test.com")
        goToLedgerSettings()

        // tap Menu → "掃碼加入"
        tapAddLedgerMenu(item: "掃碼加入")

        // 輸入邀請碼
        let codeField = app.textFields["field_invite_code"]
        XCTAssertTrue(codeField.waitForExistence(timeout: 5), "邀請碼輸入框未出現")
        codeField.tap()
        codeField.typeText(inviteCode)

        // tap「加入」
        let joinBtn = app.buttons["btn_join_submit"]
        XCTAssertTrue(joinBtn.waitForExistence(timeout: 5), "加入按鈕未出現")
        joinBtn.tap()
        sleep(3)

        // 驗證 success overlay
        XCTAssertTrue(
            app.staticTexts["成功加入"].waitForExistence(timeout: 5),
            "應顯示「成功加入」"
        )

        // tap「完成」（overlay 在 camera 區域上，用 coordinate tap 避免 scroll 問題）
        let doneBtn = app.buttons["btn_join_done"]
        XCTAssertTrue(doneBtn.waitForExistence(timeout: 5), "完成按鈕未出現")
        doneBtn.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        sleep(2)

        // 驗證列表有「A的帳本」
        XCTAssertTrue(
            app.staticTexts["A的帳本"].waitForExistence(timeout: 5),
            "帳本設定列表應顯示「A的帳本」"
        )

        // MySQL 驗證：LedgerMember 應有 2 筆
        guard let ledgerRow = TestHelper.queryMySQL(
            "SELECT id FROM Ledger WHERE name = 'A的帳本' LIMIT 1"
        ), let ledgerId = ledgerRow["id"] as? Int else {
            XCTFail("無法取得帳本 ID")
            return
        }
        let members = TestHelper.queryMySQLAll(
            "SELECT id FROM LedgerMember WHERE ledgerId = \(ledgerId)"
        )
        XCTAssertEqual(members.count, 2, "LedgerMember 應有 2 筆（owner + member）")
    }

    // MARK: - LDG-003：Auth+Online 無效邀請碼

    func test_LDG003_auth_online_invalidInviteCode() {
        devLogin()
        goToLedgerSettings()

        // tap Menu → "掃碼加入"
        tapAddLedgerMenu(item: "掃碼加入")

        // 輸入無效邀請碼
        let codeField = app.textFields["field_invite_code"]
        XCTAssertTrue(codeField.waitForExistence(timeout: 5), "邀請碼輸入框未出現")
        codeField.tap()
        codeField.typeText("ZZZZZZ")

        // tap「加入」
        let joinBtn = app.buttons["btn_join_submit"]
        XCTAssertTrue(joinBtn.waitForExistence(timeout: 5), "加入按鈕未出現")
        joinBtn.tap()
        sleep(3)

        // 驗證 alert「無法加入」
        let alert = app.alerts["無法加入"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "應顯示「無法加入」alert")
        alert.buttons["好"].tap()
    }

    // MARK: - LDG-004：Auth+Online 更新個人帳本名稱

    func test_LDG004_auth_online_updatePersonalLedgerName() {
        devLogin()
        goToLedgerSettings()

        // tap 個人帳本 row
        let personalRow = app.buttons["ledger_settings_personal"]
        XCTAssertTrue(personalRow.waitForExistence(timeout: 5), "個人帳本 row 未出現")
        personalRow.tap()
        sleep(1)

        // 清除名稱 → 輸入新名稱（同 CategoryTests 模式，無額外 sleep）
        let nameField = app.textFields["field_ledger_name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "帳本名稱輸入框未出現")
        nameField.tap()
        nameField.tap(withNumberOfTaps: 3, numberOfTouches: 1)
        nameField.typeText(String(XCUIKeyboardKey.delete.rawValue))
        nameField.typeText("NewLedger")

        // 儲存
        let saveBtn = app.buttons["btn_ledger_save"]
        XCTAssertTrue(saveBtn.waitForExistence(timeout: 5), "儲存按鈕未出現")
        saveBtn.tap()
        sleep(5)

        // MySQL 驗證（確認 API 有寫入）
        let ledger = TestHelper.queryMySQL(
            "SELECT name FROM Ledger WHERE name = 'NewLedger' AND type = 'personal' LIMIT 1"
        )
        XCTAssertNotNil(ledger, "MySQL 應有「NewLedger」且 type=personal")

        // 驗證 UI：用 predicate 搜尋任何包含 NewLedger 的元素
        let predicate = NSPredicate(format: "label CONTAINS 'NewLedger'")
        let match = app.descendants(matching: .any).matching(predicate).firstMatch
        XCTAssertTrue(match.waitForExistence(timeout: 10), "帳本設定列表應顯示「NewLedger」")
    }

    // MARK: - LDG-007：Auth+Online 退出群組帳本（已結清 → 帳本刪除）

    func test_LDG007_auth_online_leaveGroupLedger_settled() {
        // API: 建立群組帳本
        guard let token = TestHelper.devLogin(email: "test@test.com") else {
            XCTFail("API 登入失敗")
            return
        }
        guard let groupLedger = TestHelper.createGroupLedger(token: token, name: "可退出帳本") else {
            XCTFail("建立群組帳本失敗")
            return
        }
        guard let groupLedgerIdNum = groupLedger["id"] as? Int else {
            XCTFail("無法取得群組帳本 ID")
            return
        }
        let groupLedgerId = String(groupLedgerIdNum)

        // UI: 重啟 App 登入，初始化載入帳本
        app.terminate()
        app.launchArguments = ["--reset-local-data"]
        app.launch()
        devLogin()
        goToLedgerSettings()

        // tap 群組帳本 row → push LedgerDetailView
        let groupRow = app.buttons["ledger_settings_group_\(groupLedgerId)"]
        XCTAssertTrue(groupRow.waitForExistence(timeout: 5), "群組帳本 row 未出現")
        groupRow.tap()
        sleep(1)

        // tap「退出帳本」
        let leaveBtn = app.buttons["btn_ledger_leave"]
        XCTAssertTrue(leaveBtn.waitForExistence(timeout: 5), "退出帳本按鈕未出現")
        leaveBtn.tap()
        sleep(1)

        // confirmationDialog → tap「退出」
        let confirmBtn = app.buttons["退出"]
        XCTAssertTrue(confirmBtn.waitForExistence(timeout: 3), "退出確認未出現")
        confirmBtn.tap()
        sleep(3)

        // 驗證「可退出帳本」從列表消失
        XCTAssertFalse(
            app.staticTexts["可退出帳本"].waitForExistence(timeout: 3),
            "「可退出帳本」應從列表消失"
        )

        // MySQL 驗證：帳本完全刪除
        let ledgerCheck = TestHelper.queryMySQL(
            "SELECT id FROM Ledger WHERE name = '可退出帳本' LIMIT 1"
        )
        XCTAssertNil(ledgerCheck, "MySQL 應無「可退出帳本」（最後成員退出→刪除）")
    }

    // MARK: - LDG-008：Auth+Online 退出群組帳本（未結清 → 攔截）

    func test_LDG008_auth_online_leaveGroupLedger_unsettled() {
        // API: 建立群組帳本 + 新增開銷
        guard let token = TestHelper.devLogin(email: "test@test.com") else {
            XCTFail("API 登入失敗")
            return
        }
        guard let groupLedger = TestHelper.createGroupLedger(token: token, name: "未結清帳本") else {
            XCTFail("建立群組帳本失敗")
            return
        }
        guard let groupLedgerIdNum = groupLedger["id"] as? Int else {
            XCTFail("無法取得群組帳本 ID")
            return
        }
        let groupLedgerId = String(groupLedgerIdNum)

        // 新增一筆開銷（使帳本有未結算開銷）
        let expense = TestHelper.addExpenseViaAPI(token: token, ledgerId: groupLedgerIdNum, amount: 500)
        XCTAssertNotNil(expense, "API 新增開銷應成功")

        // UI: 重啟 App 登入，初始化載入帳本
        app.terminate()
        app.launchArguments = ["--reset-local-data"]
        app.launch()
        devLogin()
        goToLedgerSettings()

        // tap 群組帳本 row → push LedgerDetailView
        let groupRow = app.buttons["ledger_settings_group_\(groupLedgerId)"]
        XCTAssertTrue(groupRow.waitForExistence(timeout: 5), "群組帳本 row 未出現")
        groupRow.tap()
        sleep(1)

        // tap「退出帳本」
        let leaveBtn = app.buttons["btn_ledger_leave"]
        XCTAssertTrue(leaveBtn.waitForExistence(timeout: 5), "退出帳本按鈕未出現")
        leaveBtn.tap()
        sleep(1)

        // 驗證 alert「帳本尚未結清」
        let alert = app.alerts["帳本尚未結清"]
        XCTAssertTrue(alert.waitForExistence(timeout: 3), "應顯示「帳本尚未結清」alert")
        alert.buttons["好"].tap()
    }

    // MARK: - LDG-010：Guest 新增帳本 → LoginPrompt

    func test_LDG010_guest_createLedger_loginPrompt() {
        // Guest 模式（不登入）
        goToLedgerSettings()

        // tap Menu → "自己建立"
        tapAddLedgerMenu(item: "自己建立")

        // 驗證 LoginPromptView sheet
        XCTAssertTrue(
            app.staticTexts["登入後即可建立群組帳本"].waitForExistence(timeout: 5),
            "應顯示 LoginPromptView「登入後即可建立群組帳本」"
        )
    }

    // MARK: - LDG-011：Auth+Offline 新增帳本 → 阻擋

    func test_LDG011_auth_offline_createLedger_blocked() {
        devLogin()
        toggleOffline()
        goToLedgerSettings()

        // tap Menu → "自己建立" → 驗證「無法連線」
        tapAddLedgerMenu(item: "自己建立")

        let alert1 = app.alerts["無法連線"]
        XCTAssertTrue(alert1.waitForExistence(timeout: 3), "應顯示「無法連線」alert")
        alert1.buttons["好"].tap()
        sleep(1)

        // tap Menu → "掃碼加入" → 驗證「無法連線」
        tapAddLedgerMenu(item: "掃碼加入")

        let alert2 = app.alerts["無法連線"]
        XCTAssertTrue(alert2.waitForExistence(timeout: 3), "應再次顯示「無法連線」alert")
        alert2.buttons["好"].tap()
    }
}
