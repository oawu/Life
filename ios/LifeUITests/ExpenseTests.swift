import XCTest

/// 開銷 CRUD 測試（EXP-001 ~ EXP-012）
/// EXP-013（Slow API）、EXP-014（群組帳本付款人）需額外基礎設施，暫略
final class ExpenseTests: XCTestCase {
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

    /// 前往開銷明細列表
    private func goToExpenseList() {
        let expenseTab = app.tabBars.buttons["記帳"]
        expenseTab.tap()
        let listBtn = app.buttons["btn_expense_list"]
        XCTAssertTrue(listBtn.waitForExistence(timeout: 5), "明細按鈕未出現")
        listBtn.tap()
        sleep(1)
    }

    /// 點擊第一筆開銷進入詳情
    private func tapFirstExpense() {
        // NavigationLink 在 List 中可能是 cell 或 button，使用廣泛搜尋
        let predicate = NSPredicate(format: "identifier BEGINSWITH 'expense_'")
        let element = app.descendants(matching: .any).matching(predicate).firstMatch
        XCTAssertTrue(element.waitForExistence(timeout: 10), "開銷 cell 未出現")
        element.tap()
        sleep(1)
    }

    /// 在詳情頁點編輯 → 清除計算機 → 輸入新金額 → 儲存
    private func editExpenseAmount(to newAmount: Int) {
        let editBtn = app.buttons["btn_edit_expense"]
        XCTAssertTrue(editBtn.waitForExistence(timeout: 5), "編輯按鈕未出現")
        editBtn.tap()
        sleep(1)

        let clearBtn = app.buttons["calc_清除"]
        XCTAssertTrue(clearBtn.waitForExistence(timeout: 5), "清除按鈕未出現")
        clearBtn.tap()

        for digit in String(newAmount) {
            app.buttons["calc_\(digit)"].tap()
        }

        app.buttons["btn_save_edit"].tap()
        sleep(2)
    }

    /// 在詳情頁刪除開銷（confirmationDialog）
    private func deleteCurrentExpense() {
        let deleteBtn = app.buttons["btn_delete_expense"]
        XCTAssertTrue(deleteBtn.waitForExistence(timeout: 5), "刪除按鈕未出現")
        deleteBtn.tap()

        let confirmBtn = app.buttons["刪除"]
        XCTAssertTrue(confirmBtn.waitForExistence(timeout: 3), "刪除確認未出現")
        confirmBtn.tap()
        sleep(2)
    }

    /// 透過 Debug Panel 切換離線模式
    private func toggleOffline() {
        let indicator = app.descendants(matching: .any).matching(identifier: "debug_indicator").firstMatch
        XCTAssertTrue(indicator.waitForExistence(timeout: 3), "Debug indicator 未出現")
        indicator.tap()
        sleep(2)

        let toggle = app.switches["toggle_offline"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5), "離線 Toggle 未出現")

        // SwiftUI mini Toggle tap 可能落在 label 上，精確點擊右側 switch 控制器
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        sleep(1)

        // 若第一次 tap 未切換，重試
        if toggle.value as? String != "1" {
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
            sleep(1)
        }
        XCTAssertEqual(toggle.value as? String, "1", "離線 Toggle 應為 ON")

        // 關閉面板：點擊背景區域（面板在右下角，點左上角的背景遮罩）
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.3)).tap()
        sleep(1)
    }

    // MARK: - EXP-001：Guest 新增開銷

    func test_EXP001_guest_addExpense() {
        addExpense(amount: 150, categoryKey: "breakfast")

        let display = app.staticTexts.matching(identifier: "calc_display").firstMatch
        XCTAssertTrue(display.waitForExistence(timeout: 3))
        XCTAssertEqual(display.label, "0", "儲存後金額應歸零")
    }

    // MARK: - EXP-002：Guest 編輯開銷

    func test_EXP002_guest_editExpense() {
        addExpense(amount: 150, categoryKey: "breakfast")

        goToExpenseList()
        tapFirstExpense()
        editExpenseAmount(to: 200)

        // 驗證詳情頁金額更新
        XCTAssertTrue(
            app.staticTexts["$200"].waitForExistence(timeout: 5),
            "金額應更新為 $200"
        )
    }

    // MARK: - EXP-003：Guest 刪除開銷

    func test_EXP003_guest_deleteExpense() {
        addExpense(amount: 150, categoryKey: "breakfast")

        goToExpenseList()
        tapFirstExpense()
        deleteCurrentExpense()

        // 驗證列表為空（VStack 非 accessibilityElement，改用文字驗證）
        let emptyText = app.staticTexts["尚無開銷紀錄"]
        XCTAssertTrue(emptyText.waitForExistence(timeout: 5), "刪除後列表應為空")
    }

    // MARK: - EXP-004：Auth+Online 新增開銷

    func test_EXP004_auth_online_addExpense() {
        devLogin()
        addExpense(amount: 300, categoryKey: "lunch")

        let display = app.staticTexts.matching(identifier: "calc_display").firstMatch
        XCTAssertEqual(display.label, "0", "儲存後金額應歸零")

        sleep(2)
        let expense = TestHelper.queryMySQL(
            "SELECT e.amount, c.`key` as categoryKey FROM Expense e LEFT JOIN Category c ON e.categoryId = c.id WHERE e.amount = 300 LIMIT 1"
        )
        XCTAssertNotNil(expense, "MySQL 應有此筆開銷")
        XCTAssertEqual(expense?["amount"] as? String, "300")
        XCTAssertEqual(expense?["categoryKey"] as? String, "lunch")
    }

    // MARK: - EXP-005：Auth+Online 編輯已同步開銷

    func test_EXP005_auth_online_editExpense() {
        devLogin()
        addExpense(amount: 300, categoryKey: "lunch")
        sleep(2)

        goToExpenseList()
        tapFirstExpense()
        editExpenseAmount(to: 500)

        sleep(2)
        let expense = TestHelper.queryMySQL(
            "SELECT amount FROM Expense ORDER BY id DESC LIMIT 1"
        )
        XCTAssertEqual(expense?["amount"] as? String, "500", "MySQL 金額應更新為 500")
    }

    // MARK: - EXP-006：Auth+Online 刪除已同步開銷

    func test_EXP006_auth_online_deleteExpense() {
        devLogin()
        addExpense(amount: 300, categoryKey: "lunch")
        sleep(2)

        goToExpenseList()
        tapFirstExpense()
        deleteCurrentExpense()

        sleep(2)
        let expCount = TestHelper.queryMySQL(
            "SELECT COUNT(*) as count FROM Expense"
        )
        XCTAssertEqual(expCount?["count"] as? String, "0", "MySQL 應無開銷")
    }

    // MARK: - EXP-007：Auth+Online 新增「其他」分類開銷

    func test_EXP007_auth_online_addExpenseOtherCategory() {
        devLogin()

        let expenseTab = app.tabBars.buttons["記帳"]
        expenseTab.tap()

        app.buttons["calc_2"].tap()
        app.buttons["calc_5"].tap()
        app.buttons["calc_0"].tap()

        // 「其他」在最後，分類是水平分頁，需要左滑
        let otherCat = app.buttons["cat_other"]
        let firstCat = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'cat_'")
        ).firstMatch
        for _ in 0..<3 {
            if otherCat.exists && otherCat.isHittable {
                break
            }
            if firstCat.exists {
                firstCat.swipeLeft()
            }
            sleep(1)
        }
        XCTAssertTrue(otherCat.exists, "其他分類未出現")
        otherCat.tap()

        app.buttons["btn_save_expense"].tap()
        sleep(3)

        // MySQL 驗證 categoryId = NULL
        let expense = TestHelper.queryMySQL(
            "SELECT amount, categoryId FROM Expense WHERE amount = 250 LIMIT 1"
        )
        XCTAssertNotNil(expense, "MySQL 應有此筆開銷")
        let categoryId = expense?["categoryId"]
        let isNull = categoryId == nil || categoryId is NSNull
        XCTAssertTrue(isNull, "categoryId 應為 NULL（其他分類）")
    }

    // MARK: - EXP-008：Auth+Offline 新增開銷（離線排隊）

    func test_EXP008_auth_offline_addExpense() {
        devLogin()
        toggleOffline()

        addExpense(amount: 200, categoryKey: "lunch")

        // 儲存成功（計算機歸零）
        let display = app.staticTexts.matching(identifier: "calc_display").firstMatch
        XCTAssertEqual(display.label, "0", "離線儲存後金額應歸零")

        // MySQL 無資料（未同步）
        let expCount = TestHelper.queryMySQL(
            "SELECT COUNT(*) as count FROM Expense"
        )
        XCTAssertEqual(expCount?["count"] as? String, "0", "離線新增不應同步到 Server")
    }

    // MARK: - EXP-009：Auth+Offline 編輯已同步開銷 → 阻擋

    func test_EXP009_auth_offline_editSynced_blocked() {
        devLogin()
        addExpense(amount: 300, categoryKey: "lunch")
        sleep(2)

        toggleOffline()

        goToExpenseList()
        tapFirstExpense()

        // 嘗試編輯
        app.buttons["btn_edit_expense"].tap()
        sleep(1)

        app.buttons["calc_清除"].tap()
        app.buttons["calc_5"].tap()
        app.buttons["calc_0"].tap()
        app.buttons["calc_0"].tap()
        app.buttons["btn_save_edit"].tap()

        // 應顯示離線錯誤
        let errorAlert = app.alerts["錯誤"]
        XCTAssertTrue(errorAlert.waitForExistence(timeout: 5), "應顯示錯誤 alert")
        XCTAssertTrue(
            errorAlert.staticTexts["目前無法連線，請稍後再試"].exists,
            "應顯示離線錯誤訊息"
        )
        errorAlert.buttons["確定"].tap()

        // MySQL 金額不變
        let expense = TestHelper.queryMySQL(
            "SELECT amount FROM Expense ORDER BY id DESC LIMIT 1"
        )
        XCTAssertEqual(expense?["amount"] as? String, "300", "金額不應改變")
    }

    // MARK: - EXP-010：Auth+Offline 編輯未同步開銷 → 允許

    func test_EXP010_auth_offline_editUnsynced_allowed() {
        devLogin()
        toggleOffline()

        // 離線新增（isSynced=false）
        addExpense(amount: 200, categoryKey: "lunch")

        goToExpenseList()
        tapFirstExpense()
        editExpenseAmount(to: 350)

        // 不應出現錯誤
        let errorAlert = app.alerts["錯誤"]
        XCTAssertFalse(errorAlert.exists, "未同步開銷編輯不應顯示錯誤")

        // 詳情頁金額已更新
        XCTAssertTrue(
            app.staticTexts["$350"].waitForExistence(timeout: 5),
            "金額應更新為 $350"
        )
    }

    // MARK: - EXP-011：Auth+Offline 刪除已同步開銷 → 阻擋

    func test_EXP011_auth_offline_deleteSynced_blocked() {
        devLogin()
        addExpense(amount: 300, categoryKey: "lunch")
        sleep(2)

        toggleOffline()

        goToExpenseList()
        tapFirstExpense()

        // 嘗試刪除
        app.buttons["btn_delete_expense"].tap()
        let deleteConfirm = app.buttons["刪除"]
        XCTAssertTrue(deleteConfirm.waitForExistence(timeout: 3))
        deleteConfirm.tap()

        // 應顯示離線錯誤
        let errorAlert = app.alerts["錯誤"]
        XCTAssertTrue(errorAlert.waitForExistence(timeout: 5), "應顯示錯誤 alert")
        XCTAssertTrue(
            errorAlert.staticTexts["目前無法連線，請稍後再試"].exists,
            "應顯示離線錯誤訊息"
        )
        errorAlert.buttons["確定"].tap()

        // MySQL 開銷仍在
        let expCount = TestHelper.queryMySQL(
            "SELECT COUNT(*) as count FROM Expense"
        )
        XCTAssertEqual(expCount?["count"] as? String, "1", "開銷不應被刪除")
    }

    // MARK: - EXP-012：Auth+Offline 刪除未同步開銷 → 允許

    func test_EXP012_auth_offline_deleteUnsynced_allowed() {
        devLogin()
        toggleOffline()

        // 離線新增
        addExpense(amount: 200, categoryKey: "lunch")

        goToExpenseList()
        tapFirstExpense()
        deleteCurrentExpense()

        // 應成功 → 列表為空（VStack 非 accessibilityElement，改用文字驗證）
        let emptyText = app.staticTexts["尚無開銷紀錄"]
        XCTAssertTrue(emptyText.waitForExistence(timeout: 5), "刪除後列表應為空")
    }
}
