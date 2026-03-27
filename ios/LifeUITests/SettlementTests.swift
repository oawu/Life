import XCTest

/// 拆帳結算測試（STL-001 ~ STL-005）
final class SettlementTests: XCTestCase {
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

    private func goToExpenseList() {
        let expenseTab = app.tabBars.buttons["記帳"]
        XCTAssertTrue(expenseTab.waitForExistence(timeout: 10), "記帳 Tab 未出現")
        expenseTab.tap()

        let listBtn = app.buttons["btn_expense_list"]
        XCTAssertTrue(listBtn.waitForExistence(timeout: 5), "明細按鈕未出現")
        listBtn.tap()
        sleep(1)
    }

    private func switchToGroupLedger(id: String) {
        let pill = app.buttons["ledger_\(id)"]
        XCTAssertTrue(pill.waitForExistence(timeout: 5), "群組帳本 pill 未出現")
        pill.tap()
        sleep(2)
    }

    // MARK: - STL-001：拆帳計算正確性

    func test_STL001_splitCalculation() {
        // API: userA + userB 各自登入，建立群組帳本，B 加入
        guard let tokenA = TestHelper.devLogin(email: "user_a@test.com") else {
            XCTFail("userA API 登入失敗")
            return
        }
        guard let tokenB = TestHelper.devLogin(email: "user_b@test.com") else {
            XCTFail("userB API 登入失敗")
            return
        }
        guard let groupLedger = TestHelper.createGroupLedger(token: tokenA, name: "拆帳測試") else {
            XCTFail("建立群組帳本失敗")
            return
        }
        guard let ledgerId = groupLedger["id"] as? Int,
              let inviteCode = groupLedger["inviteCode"] as? String else {
            XCTFail("無法取得帳本 ID 或 inviteCode")
            return
        }

        // B 加入帳本
        let joinResult = TestHelper.joinLedgerViaAPI(token: tokenB, inviteCode: inviteCode)
        XCTAssertNotNil(joinResult, "B 加入帳本應成功")

        // 取得 userId
        guard let userIdA = TestHelper.getUserId(email: "user_a@test.com") else {
            XCTFail("無法取得 userA ID")
            return
        }
        guard let userIdB = TestHelper.getUserId(email: "user_b@test.com") else {
            XCTFail("無法取得 userB ID")
            return
        }

        // A 付 900、B 付 300（人均 600 → B 應付 A 300）
        let expenseA = TestHelper.addExpenseViaAPI(token: tokenA, ledgerId: ledgerId, amount: 900, paidByUserId: userIdA)
        XCTAssertNotNil(expenseA, "A 新增開銷應成功")
        let expenseB = TestHelper.addExpenseViaAPI(token: tokenB, ledgerId: ledgerId, amount: 300, paidByUserId: userIdB)
        XCTAssertNotNil(expenseB, "B 新增開銷應成功")

        // UI: 以 userA 登入
        app.terminate()
        app.launchArguments = ["--reset-local-data"]
        app.launch()
        devLogin(email: "user_a@test.com")
        goToExpenseList()
        switchToGroupLedger(id: String(ledgerId))

        // 驗證拆帳 Section
        XCTAssertTrue(
            app.staticTexts["拆帳"].waitForExistence(timeout: 5),
            "拆帳 Section header 應存在"
        )

        // 驗證轉帳金額 300
        let amountPredicate = NSPredicate(format: "label CONTAINS '300'")
        let amountMatch = app.staticTexts.matching(amountPredicate).firstMatch
        XCTAssertTrue(amountMatch.waitForExistence(timeout: 5), "應顯示轉帳金額 300")

        // 驗證結清按鈕存在
        let settleBtn = app.buttons["btn_settle"]
        XCTAssertTrue(settleBtn.waitForExistence(timeout: 5), "結清按鈕應存在")
    }

    // MARK: - STL-002：結清操作

    func test_STL002_settleOperation() {
        // API: 兩人帳本 + 新增開銷（需 2 成員才有拆帳）
        guard let tokenA = TestHelper.devLogin(email: "test@test.com") else {
            XCTFail("API 登入失敗")
            return
        }
        guard let tokenB = TestHelper.devLogin(email: "user_b@test.com") else {
            XCTFail("userB API 登入失敗")
            return
        }
        guard let groupLedger = TestHelper.createGroupLedger(token: tokenA, name: "結清測試") else {
            XCTFail("建立群組帳本失敗")
            return
        }
        guard let ledgerId = groupLedger["id"] as? Int,
              let inviteCode = groupLedger["inviteCode"] as? String else {
            XCTFail("無法取得帳本 ID 或 inviteCode")
            return
        }

        let joinResult = TestHelper.joinLedgerViaAPI(token: tokenB, inviteCode: inviteCode)
        XCTAssertNotNil(joinResult, "B 加入帳本應成功")

        guard let userId = TestHelper.getUserId(email: "test@test.com") else {
            XCTFail("無法取得 userId")
            return
        }

        let expense = TestHelper.addExpenseViaAPI(token: tokenA, ledgerId: ledgerId, amount: 500, paidByUserId: userId)
        XCTAssertNotNil(expense, "新增開銷應成功")

        // UI: 重啟 App 登入
        app.terminate()
        app.launchArguments = ["--reset-local-data"]
        app.launch()
        devLogin()
        goToExpenseList()
        switchToGroupLedger(id: String(ledgerId))

        // tap 結清 → confirmationDialog → 確認
        let settleBtn = app.buttons["btn_settle"]
        XCTAssertTrue(settleBtn.waitForExistence(timeout: 5), "結清按鈕應存在")
        settleBtn.tap()
        sleep(1)

        // confirmationDialog 在 iPhone 上呈現為 sheet
        let confirmBtn = app.sheets.buttons["結清"]
        XCTAssertTrue(confirmBtn.waitForExistence(timeout: 3), "結清確認未出現")
        confirmBtn.tap()

        // 驗證 toast（1.5 秒後消失，需立即檢查）
        XCTAssertTrue(
            app.staticTexts["已完成結算"].waitForExistence(timeout: 10),
            "應顯示「已完成結算」toast"
        )
        sleep(2)

        // MySQL: Settlement 表有 1 筆
        let settlement = TestHelper.queryMySQL(
            "SELECT COUNT(*) as count FROM Settlement WHERE ledgerId = \(ledgerId)"
        )
        XCTAssertEqual(settlement?["count"] as? String, "1", "Settlement 表應有 1 筆")

        // MySQL: Expense isSettled = 1
        let settledExpense = TestHelper.queryMySQL(
            "SELECT isSettled FROM Expense WHERE ledgerId = \(ledgerId) LIMIT 1"
        )
        XCTAssertEqual(settledExpense?["isSettled"] as? String, "1", "開銷應標記為已結算")
    }

    // MARK: - STL-003：結算紀錄查看

    func test_STL003_viewSettlementRecord() {
        // API: 建立群組帳本 + 新增開銷 + API 直接結清
        guard let token = TestHelper.devLogin(email: "test@test.com") else {
            XCTFail("API 登入失敗")
            return
        }
        guard let groupLedger = TestHelper.createGroupLedger(token: token, name: "紀錄測試") else {
            XCTFail("建立群組帳本失敗")
            return
        }
        guard let ledgerId = groupLedger["id"] as? Int else {
            XCTFail("無法取得帳本 ID")
            return
        }

        let expense = TestHelper.addExpenseViaAPI(token: token, ledgerId: ledgerId, amount: 800)
        XCTAssertNotNil(expense, "新增開銷應成功")

        let settlement = TestHelper.settleViaAPI(token: token, ledgerId: ledgerId)
        XCTAssertNotNil(settlement, "API 結清應成功")

        // UI: 重啟 App 登入
        app.terminate()
        app.launchArguments = ["--reset-local-data"]
        app.launch()
        devLogin()
        goToExpenseList()
        switchToGroupLedger(id: String(ledgerId))

        // 結清按鈕不應存在（已無未結算開銷）
        let settleBtn = app.buttons["btn_settle"]
        XCTAssertFalse(settleBtn.waitForExistence(timeout: 3), "已結清後結清按鈕不應存在")

        // timeline 有「結算拆帳」文字
        let settlementPredicate = NSPredicate(format: "label CONTAINS '結算拆帳'")
        let settlementEntry = app.staticTexts.matching(settlementPredicate).firstMatch
        XCTAssertTrue(settlementEntry.waitForExistence(timeout: 5), "應顯示結算拆帳紀錄")

        // tap 結算 entry → push SettlementDetailView
        settlementEntry.tap()
        sleep(1)

        // 驗證詳情頁
        XCTAssertTrue(
            app.staticTexts["結算時間"].waitForExistence(timeout: 5),
            "結算詳情應顯示「結算時間」"
        )
        XCTAssertTrue(
            app.staticTexts["操作者"].exists,
            "結算詳情應顯示「操作者」"
        )
    }

    // MARK: - STL-004：已全部結清 → 拆帳區塊不顯示

    func test_STL004_settledLedger_noSplitSection() {
        // API: 建立群組帳本 + 新增開銷 + 全部結清
        guard let token = TestHelper.devLogin(email: "test@test.com") else {
            XCTFail("API 登入失敗")
            return
        }
        guard let groupLedger = TestHelper.createGroupLedger(token: token, name: "已結清帳本") else {
            XCTFail("建立群組帳本失敗")
            return
        }
        guard let ledgerId = groupLedger["id"] as? Int else {
            XCTFail("無法取得帳本 ID")
            return
        }

        let expense = TestHelper.addExpenseViaAPI(token: token, ledgerId: ledgerId, amount: 300)
        XCTAssertNotNil(expense, "新增開銷應成功")

        let settlement = TestHelper.settleViaAPI(token: token, ledgerId: ledgerId)
        XCTAssertNotNil(settlement, "API 結清應成功")

        // UI: 重啟 App 登入
        app.terminate()
        app.launchArguments = ["--reset-local-data"]
        app.launch()
        devLogin()
        goToExpenseList()
        switchToGroupLedger(id: String(ledgerId))

        // 結清按鈕不應存在
        let settleBtn = app.buttons["btn_settle"]
        XCTAssertFalse(settleBtn.waitForExistence(timeout: 3), "已結清後結清按鈕不應存在")

        // 結算紀錄仍顯示
        let settlementPredicate = NSPredicate(format: "label CONTAINS '結算拆帳'")
        let settlementEntry = app.staticTexts.matching(settlementPredicate).firstMatch
        XCTAssertTrue(settlementEntry.waitForExistence(timeout: 5), "結算紀錄應仍顯示")
    }

    // MARK: - STL-005：結算後新成員加入（純 API）

    func test_STL005_joinAfterSettlement() {
        // API: A 建立帳本 + 新增開銷 + 結清
        guard let tokenA = TestHelper.devLogin(email: "user_a@test.com") else {
            XCTFail("userA API 登入失敗")
            return
        }
        guard let groupLedger = TestHelper.createGroupLedger(token: tokenA, name: "開放加入") else {
            XCTFail("建立群組帳本失敗")
            return
        }
        guard let ledgerId = groupLedger["id"] as? Int,
              let inviteCode = groupLedger["inviteCode"] as? String else {
            XCTFail("無法取得帳本 ID 或 inviteCode")
            return
        }

        let expense = TestHelper.addExpenseViaAPI(token: tokenA, ledgerId: ledgerId, amount: 600)
        XCTAssertNotNil(expense, "新增開銷應成功")

        let settlement = TestHelper.settleViaAPI(token: tokenA, ledgerId: ledgerId)
        XCTAssertNotNil(settlement, "API 結清應成功")

        // B 加入已結清帳本
        guard let tokenB = TestHelper.devLogin(email: "user_b@test.com") else {
            XCTFail("userB API 登入失敗")
            return
        }
        let joinResult = TestHelper.joinLedgerViaAPI(token: tokenB, inviteCode: inviteCode)
        XCTAssertNotNil(joinResult, "結算後加入帳本應成功")

        // MySQL: LedgerMember 應有 2 筆
        let members = TestHelper.queryMySQLAll(
            "SELECT id FROM LedgerMember WHERE ledgerId = \(ledgerId)"
        )
        XCTAssertEqual(members.count, 2, "LedgerMember 應有 2 筆（owner + 新成員）")
    }
}
