import XCTest

final class SimpleTests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    // 測試 1：App 啟動後，首頁的「記帳」Tab 出現
    func test_homeScreen_shows() {
        let tab = app.tabBars.buttons["記帳"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10), "記帳 Tab 應該出現")
    }

    // 測試 2：首頁的「儲存」按鈕存在
    func test_saveButton_exists() {
        let saveBtn = app.buttons["btn_save_expense"]
        XCTAssertTrue(saveBtn.waitForExistence(timeout: 5), "儲存按鈕應該存在")
    }

    // 測試 3：點「個人」Tab 可以切換到個人頁面
    func test_switchToProfileTab() {
        let profileTab = app.tabBars.buttons["個人"]
        XCTAssertTrue(profileTab.waitForExistence(timeout: 5), "個人 Tab 應該出現")
        profileTab.tap()

        // 個人頁面應該有「Life」文字
        let title = app.staticTexts["Life"]
        XCTAssertTrue(title.waitForExistence(timeout: 5), "個人頁面應該顯示 Life")
    }

    // 測試 4：輸入 3×5，選第二頁分類，儲存
    func test_addExpense_3x5() {
        // 等首頁載入
        let tab = app.tabBars.buttons["記帳"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10), "首頁未載入")

        // === 步驟 1：輸入 3 × 5 ===
        // 按鈕的 identifier 是 "calc_3", "calc_×", "calc_5"
        app.buttons["calc_3"].tap()
        app.buttons["calc_×"].tap()
        app.buttons["calc_5"].tap()
        // 按 = 計算結果（得到 15）
        app.buttons["calc_="].tap()

        // === 步驟 2：滑到第二頁分類 ===
        // 第一頁：早餐、午餐、晚餐、甜點、飲料、租金、衣服、日用品
        // 第二頁：醫療、購物、交通、汽車、加油、停車、大眾運輸、娛樂
        // 在分類區域向左滑
        let firstCategory = app.buttons["cat_breakfast"]
        XCTAssertTrue(firstCategory.waitForExistence(timeout: 3), "分類未出現")
        firstCategory.swipeLeft()

        // === 步驟 3：選擇第二頁的「醫療」分類 ===
        let medicalCategory = app.buttons["cat_medical"]
        XCTAssertTrue(medicalCategory.waitForExistence(timeout: 3), "第二頁分類未出現")
        medicalCategory.tap()

        // === 步驟 4：儲存 ===
        let saveBtn = app.buttons["btn_save_expense"]
        XCTAssertTrue(saveBtn.exists, "儲存按鈕不存在")
        saveBtn.tap()

        // === 驗證：儲存成功後計算機歸零 ===
        sleep(2)
        let display = app.staticTexts.matching(identifier: "calc_display").firstMatch
        XCTAssertTrue(display.waitForExistence(timeout: 3), "計算機顯示區未找到")
        XCTAssertEqual(display.label, "0", "儲存後金額應歸零")
    }
}
