import XCTest

/// 個人資料測試（PRF-001 ~ PRF-004）
final class ProfileTests: XCTestCase {
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
        sleep(3)
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

    // MARK: - PRF-001：更新名稱

    func test_PRF001_auth_online_updateName() {
        // API 登入取得 token
        let token = TestHelper.devLogin()
        XCTAssertNotNil(token, "API 登入失敗")

        // UI 登入（devLogin 結束後停在 Tab 2 個人頁）
        devLogin()

        // tap 名稱按鈕 → TextField 出現
        let nameBtn = app.buttons["btn_edit_name"]
        XCTAssertTrue(nameBtn.waitForExistence(timeout: 5), "名稱按鈕未出現")
        nameBtn.tap()

        let nameField = app.textFields["field_profile_name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "名稱 TextField 未出現")

        // 清除 → 輸入「新名稱」
        nameField.tap(withNumberOfTaps: 3, numberOfTouches: 1)
        nameField.typeText(String(XCUIKeyboardKey.delete.rawValue))
        nameField.typeText("新名稱")

        // 按 Return（submit）
        nameField.typeText("\n")
        sleep(2)

        // UI 驗證：名稱按鈕重新出現，label 為「新名稱」
        let updatedNameBtn = app.buttons["btn_edit_name"]
        XCTAssertTrue(updatedNameBtn.waitForExistence(timeout: 5), "名稱按鈕應重新出現")
        XCTAssertEqual(updatedNameBtn.label, "新名稱", "名稱按鈕 label 應為「新名稱」")

        // MySQL 驗證
        let user = TestHelper.queryMySQL(
            "SELECT name FROM User WHERE email = 'test@test.com' LIMIT 1"
        )
        XCTAssertNotNil(user, "MySQL 應有用戶資料")
        XCTAssertEqual(user?["name"] as? String, "新名稱", "MySQL name 應為「新名稱」")
    }

    // MARK: - PRF-002：更新載具號碼

    func test_PRF002_auth_online_updateCarrier() {
        // API 登入取得 token
        let token = TestHelper.devLogin()
        XCTAssertNotNil(token, "API 登入失敗")

        // UI 登入
        devLogin()

        // tap 載具號碼 → push CarrierEditView
        let carrierBtn = app.buttons["btn_edit_carrier"]
        XCTAssertTrue(carrierBtn.waitForExistence(timeout: 5), "載具號碼按鈕未出現")
        carrierBtn.tap()
        sleep(1)

        // 輸入載具號碼
        let carrierField = app.textFields["field_carrier_number"]
        XCTAssertTrue(carrierField.waitForExistence(timeout: 5), "載具號碼 TextField 未出現")
        carrierField.tap()
        carrierField.typeText("/AAA1234")

        // 返回上頁（nav back）→ onDisappear 觸發儲存
        app.navigationBars.buttons.firstMatch.tap()
        sleep(2)

        // UI 驗證：ProfileView 載具顯示 /AAA1234
        XCTAssertTrue(
            app.staticTexts["/AAA1234"].waitForExistence(timeout: 5),
            "載具號碼應顯示 /AAA1234"
        )

        // MySQL 驗證
        let user = TestHelper.queryMySQL(
            "SELECT carrierNumber FROM User WHERE email = 'test@test.com' LIMIT 1"
        )
        XCTAssertNotNil(user, "MySQL 應有用戶資料")
        XCTAssertEqual(user?["carrierNumber"] as? String, "/AAA1234", "MySQL carrierNumber 應為 /AAA1234")
    }

    // MARK: - PRF-003：Auth+Offline → 修改被阻擋

    func test_PRF003_auth_offline_editBlocked() {
        // API 登入取得 token
        let token = TestHelper.devLogin()
        XCTAssertNotNil(token, "API 登入失敗")

        // UI 登入
        devLogin()
        toggleOffline()

        // tap 名稱按鈕 → 應出現「無法連線」alert
        let nameBtn = app.buttons["btn_edit_name"]
        XCTAssertTrue(nameBtn.waitForExistence(timeout: 5), "名稱按鈕未出現")
        nameBtn.tap()

        // 驗證「無法連線」alert 出現
        let alert = app.alerts["無法連線"]
        XCTAssertTrue(alert.waitForExistence(timeout: 3), "應顯示「無法連線」alert")
        alert.buttons["好"].tap()
    }

    // MARK: - PRF-004：Guest 個人頁面

    func test_PRF004_guest_profileView() {
        // Guest 模式（不登入），直接切到個人 Tab
        let profileTab = app.tabBars.buttons["個人"]
        XCTAssertTrue(profileTab.waitForExistence(timeout: 10), "個人 Tab 未出現")
        profileTab.tap()

        // 驗證 GuestProfileView 顯示
        XCTAssertTrue(
            app.staticTexts["Life"].waitForExistence(timeout: 5),
            "應顯示品牌名稱「Life」"
        )
        XCTAssertTrue(
            app.staticTexts["記錄你的生活"].waitForExistence(timeout: 3),
            "應顯示「記錄你的生活」"
        )

        // LOCAL 環境應有開發者登入按鈕
        XCTAssertTrue(
            app.buttons["btn_dev_login"].waitForExistence(timeout: 3),
            "應顯示開發者登入按鈕"
        )

        // Guest 不應有登出按鈕
        XCTAssertFalse(
            app.buttons["btn_sign_out"].exists,
            "Guest 不應有登出按鈕"
        )
    }
}
