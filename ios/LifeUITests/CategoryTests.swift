import XCTest

/// 分類管理測試（CAT-001 ~ CAT-007，略過 CAT-004 拖動排序、CAT-008 純 API 權限）
final class CategoryTests: XCTestCase {
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

    /// 前往分類設定頁
    private func goToCategorySettings() {
        let expenseTab = app.tabBars.buttons["記帳"]
        XCTAssertTrue(expenseTab.waitForExistence(timeout: 10), "記帳 Tab 未出現")
        expenseTab.tap()

        let settingsBtn = app.buttons["btn_cat_settings"]
        XCTAssertTrue(settingsBtn.waitForExistence(timeout: 5), "分類設定按鈕未出現")
        settingsBtn.tap()
        sleep(1)
    }

    /// 選擇圖示（點擊群組 → 點擊圖示）
    private func selectIcon(group: String, icon: String) {
        let groupElement = app.descendants(matching: .any)
            .matching(identifier: "cat_icon_group_\(group)").firstMatch
        XCTAssertTrue(groupElement.waitForExistence(timeout: 5), "圖示群組 \(group) 未出現")
        groupElement.tap()
        sleep(1)

        let iconElement = app.descendants(matching: .any)
            .matching(identifier: "cat_icon_\(icon)").firstMatch
        XCTAssertTrue(iconElement.waitForExistence(timeout: 5), "圖示 \(icon) 未出現")
        iconElement.tap()
        sleep(1)
    }

    /// 透過 Debug Panel 切換離線模式
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

    // MARK: - CAT-001：Auth+Online 新增分類

    func test_CAT001_auth_online_addCategory() {
        devLogin()
        goToCategorySettings()

        // tap "+" 新增
        let addBtn = app.buttons["btn_add_category"]
        XCTAssertTrue(addBtn.waitForExistence(timeout: 5), "新增分類按鈕未出現")
        addBtn.tap()
        sleep(1)

        // 輸入名稱
        let nameField = app.textFields["field_cat_name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "名稱輸入框未出現")
        nameField.tap()
        nameField.typeText("測試分類")

        // 選圖示：餐飲群組 → fork.knife
        selectIcon(group: "餐飲", icon: "fork.knife")

        // 儲存（API 非同步，需等待 sheet dismiss + API 完成 + 列表更新）
        let saveBtn = app.buttons["btn_cat_save"]
        XCTAssertTrue(saveBtn.waitForExistence(timeout: 5), "儲存按鈕未出現")
        saveBtn.tap()
        sleep(3)

        // 驗證列表有「測試分類」（新分類在列表底部，需滾動）
        let newCatText = app.staticTexts["測試分類"]
        for _ in 0..<5 {
            if newCatText.exists && newCatText.isHittable {
                break
            }
            app.swipeUp()
            sleep(1)
        }
        XCTAssertTrue(newCatText.exists, "分類設定列表應顯示「測試分類」")

        // MySQL 驗證
        let category = TestHelper.queryMySQL(
            "SELECT name, icon FROM Category WHERE name = '測試分類' LIMIT 1"
        )
        XCTAssertNotNil(category, "MySQL 應有「測試分類」")
        XCTAssertEqual(category?["name"] as? String, "測試分類")
        XCTAssertEqual(category?["icon"] as? String, "fork.knife")
    }

    // MARK: - CAT-002：Auth+Online 編輯分類

    func test_CAT002_auth_online_editCategory() {
        devLogin()
        goToCategorySettings()

        // tap 第一個分類（「早餐」）
        let predicate = NSPredicate(format: "identifier BEGINSWITH 'cat_settings_'")
        let firstRow = app.descendants(matching: .any).matching(predicate).firstMatch
        XCTAssertTrue(firstRow.waitForExistence(timeout: 5), "分類 row 未出現")
        firstRow.tap()
        sleep(1)

        // 清除名稱 → 輸入新名稱
        let nameField = app.textFields["field_cat_name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "名稱輸入框未出現")
        nameField.tap()
        nameField.tap(withNumberOfTaps: 3, numberOfTouches: 1)
        nameField.typeText(String(XCUIKeyboardKey.delete.rawValue))
        nameField.typeText("改名分類")

        // 儲存
        let saveBtn = app.buttons["btn_cat_save"]
        saveBtn.tap()
        sleep(2)

        // 驗證列表有「改名分類」
        XCTAssertTrue(
            app.staticTexts["改名分類"].waitForExistence(timeout: 5),
            "分類設定列表應顯示「改名分類」"
        )

        // MySQL 驗證
        let category = TestHelper.queryMySQL(
            "SELECT name FROM Category WHERE name = '改名分類' LIMIT 1"
        )
        XCTAssertNotNil(category, "MySQL 應有「改名分類」")
    }

    // MARK: - CAT-003：Auth+Online 刪除分類（cascade 開銷 → 其他）

    func test_CAT003_auth_online_deleteCategory_cascade() {
        devLogin()

        // 先新增 1 筆開銷（breakfast 分類）
        addExpense(amount: 999, categoryKey: "breakfast")
        sleep(2)

        // MySQL 確認 999 開銷的 categoryId NOT NULL
        let expenseBefore = TestHelper.queryMySQL(
            "SELECT categoryId FROM Expense WHERE amount = 999 LIMIT 1"
        )
        XCTAssertNotNil(expenseBefore, "MySQL 應有 999 開銷")
        let categoryIdBefore = expenseBefore?["categoryId"]
        let isNullBefore = categoryIdBefore == nil || categoryIdBefore is NSNull
        XCTAssertFalse(isNullBefore, "刪除前 categoryId 應非 NULL")

        // 前往分類設定
        goToCategorySettings()

        // tap「早餐」分類
        let predicate = NSPredicate(format: "identifier BEGINSWITH 'cat_settings_'")
        let firstRow = app.descendants(matching: .any).matching(predicate).firstMatch
        XCTAssertTrue(firstRow.waitForExistence(timeout: 5), "分類 row 未出現")
        firstRow.tap()
        sleep(1)

        // tap 刪除分類
        let deleteBtn = app.buttons["btn_cat_delete"]
        XCTAssertTrue(deleteBtn.waitForExistence(timeout: 5), "刪除分類按鈕未出現")
        deleteBtn.tap()

        // confirmationDialog → tap「刪除」
        let confirmBtn = app.buttons["刪除"]
        XCTAssertTrue(confirmBtn.waitForExistence(timeout: 3), "刪除確認未出現")
        confirmBtn.tap()
        sleep(2)

        // 驗證「早餐」從列表消失
        XCTAssertFalse(
            app.staticTexts["早餐"].exists,
            "「早餐」應從列表消失"
        )

        // MySQL 驗證 cascade：categoryId → NULL
        let expenseAfter = TestHelper.queryMySQL(
            "SELECT categoryId FROM Expense WHERE amount = 999 LIMIT 1"
        )
        XCTAssertNotNil(expenseAfter, "MySQL 應仍有 999 開銷")
        let categoryIdAfter = expenseAfter?["categoryId"]
        let isNullAfter = categoryIdAfter == nil || categoryIdAfter is NSNull
        XCTAssertTrue(isNullAfter, "刪除分類後 categoryId 應為 NULL（cascade）")
    }

    // MARK: - CAT-005：「其他」分類不可編輯/刪除

    func test_CAT005_otherCategory_notEditable() {
        devLogin()
        goToCategorySettings()

        // 「其他」在列表最底部，需滾動到可見
        let otherText = app.staticTexts["其他"]
        for _ in 0..<5 {
            if otherText.exists && otherText.isHittable {
                break
            }
            app.swipeUp()
            sleep(1)
        }

        // 驗證「其他」文字存在於列表
        XCTAssertTrue(otherText.exists, "「其他」分類應存在於列表")

        // 驗證「其他」沒有 catSettingsRow identifier（非 Button，不可 tap）
        let otherRow = app.descendants(matching: .any)
            .matching(identifier: "cat_settings_other").firstMatch
        XCTAssertFalse(
            otherRow.exists,
            "「其他」分類不應有 cat_settings_other identifier（不可點擊）"
        )
    }

    // MARK: - CAT-006：Guest 分類管理 → 阻擋

    func test_CAT006_guest_categoryBlocked() {
        // Guest 模式（不登入）
        goToCategorySettings()

        // tap 第一個分類 row
        let predicate = NSPredicate(format: "identifier BEGINSWITH 'cat_settings_'")
        let firstRow = app.descendants(matching: .any).matching(predicate).firstMatch
        XCTAssertTrue(firstRow.waitForExistence(timeout: 5), "分類 row 未出現")
        firstRow.tap()

        // 驗證 alert
        let alert = app.alerts["登入後可編輯"]
        XCTAssertTrue(alert.waitForExistence(timeout: 3), "應顯示「登入後可編輯」alert")

        // 關閉
        alert.buttons["好"].tap()
        sleep(1)
    }

    // MARK: - CAT-007：Auth+Offline 分類管理 → 阻擋

    func test_CAT007_auth_offline_categoryBlocked() {
        devLogin()
        toggleOffline()
        goToCategorySettings()

        // tap 第一個分類 row
        let predicate = NSPredicate(format: "identifier BEGINSWITH 'cat_settings_'")
        let firstRow = app.descendants(matching: .any).matching(predicate).firstMatch
        XCTAssertTrue(firstRow.waitForExistence(timeout: 5), "分類 row 未出現")
        firstRow.tap()

        // 驗證 alert「無法連線」
        let alert1 = app.alerts["無法連線"]
        XCTAssertTrue(alert1.waitForExistence(timeout: 3), "應顯示「無法連線」alert")
        alert1.buttons["好"].tap()
        sleep(1)

        // tap "+" 新增按鈕
        let addBtn = app.buttons["btn_add_category"]
        XCTAssertTrue(addBtn.waitForExistence(timeout: 5), "新增分類按鈕未出現")
        addBtn.tap()

        // 驗證 alert「無法連線」再次出現
        let alert2 = app.alerts["無法連線"]
        XCTAssertTrue(alert2.waitForExistence(timeout: 3), "應再次顯示「無法連線」alert")
        alert2.buttons["好"].tap()
    }
}
