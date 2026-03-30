import Foundation
import XCTest

enum TestHelper {
    static let apiBaseURL = "http://local-api-life.iwi.tw"

    /// 重設後端資料庫（truncate 所有資料表）
    static func resetBackend() {
        let url = URL(string: "\(apiBaseURL)/api/test/reset")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let expectation = XCTestExpectation(description: "Reset backend")
        var responseError: Error?
        var statusCode: Int?

        let task = URLSession.shared.dataTask(with: request) { _, response, error in
            responseError = error
            statusCode = (response as? HTTPURLResponse)?.statusCode
            expectation.fulfill()
        }
        task.resume()

        let result = XCTWaiter.wait(for: [expectation], timeout: 10)
        if result != .completed {
            XCTFail("後端重設逾時")
        }
        if let error = responseError {
            XCTFail("後端重設失敗: \(error.localizedDescription)")
        }
        if let code = statusCode, code != 200 {
            XCTFail("後端重設回傳非 200: \(code)")
        }
    }

    /// 開發者登入，回傳 token
    static func devLogin(email: String = "test@test.com") -> String? {
        let url = URL(string: "\(apiBaseURL)/api/auth/apple/callback")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["isDev": true, "identityToken": email]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let expectation = XCTestExpectation(description: "Dev login")
        var token: String?

        let task = URLSession.shared.dataTask(with: request) { data, _, _ in
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let t = json["token"] as? String {
                token = t
            }
            expectation.fulfill()
        }
        task.resume()

        let result = XCTWaiter.wait(for: [expectation], timeout: 10)
        if result != .completed {
            XCTFail("開發者登入逾時")
        }
        if token == nil {
            XCTFail("開發者登入失敗：未取得 token")
        }

        return token
    }

    /// 透過後端 API 查詢 MySQL，回傳第一筆結果
    static func queryMySQL(_ sql: String) -> [String: Any]? {
        let url = URL(string: "\(apiBaseURL)/api/test/query")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["sql": sql]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let expectation = XCTestExpectation(description: "Query MySQL")
        var firstRow: [String: Any]?

        let task = URLSession.shared.dataTask(with: request) { data, _, _ in
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let rows = json["rows"] as? [[String: Any]],
               let row = rows.first {
                firstRow = row
            }
            expectation.fulfill()
        }
        task.resume()

        let result = XCTWaiter.wait(for: [expectation], timeout: 10)
        if result != .completed {
            XCTFail("MySQL 查詢逾時")
        }

        return firstRow
    }

    /// 查詢 MySQL 回傳所有 rows
    static func queryMySQLAll(_ sql: String) -> [[String: Any]] {
        let url = URL(string: "\(apiBaseURL)/api/test/query")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["sql": sql]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let expectation = XCTestExpectation(description: "Query MySQL All")
        var rows: [[String: Any]] = []

        let task = URLSession.shared.dataTask(with: request) { data, _, _ in
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let result = json["rows"] as? [[String: Any]] {
                rows = result
            }
            expectation.fulfill()
        }
        task.resume()

        let result = XCTWaiter.wait(for: [expectation], timeout: 10)
        if result != .completed {
            XCTFail("MySQL 查詢逾時")
        }

        return rows
    }

    /// 通用 API POST，回傳 JSON dict
    static func apiPost(path: String, token: String? = nil, body: [String: Any]? = nil) -> [String: Any]? {
        let url = URL(string: "\(apiBaseURL)\(path)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body = body {
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }

        let expectation = XCTestExpectation(description: "API POST \(path)")
        var responseJSON: [String: Any]?

        let task = URLSession.shared.dataTask(with: request) { data, _, _ in
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                responseJSON = json
            }
            expectation.fulfill()
        }
        task.resume()

        let result = XCTWaiter.wait(for: [expectation], timeout: 10)
        if result != .completed {
            XCTFail("API POST \(path) 逾時")
        }

        return responseJSON
    }

    /// 通用 API GET，回傳 JSON dict
    static func apiGet(path: String, token: String? = nil) -> [String: Any]? {
        let url = URL(string: "\(apiBaseURL)\(path)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let expectation = XCTestExpectation(description: "API GET \(path)")
        var responseJSON: [String: Any]?

        let task = URLSession.shared.dataTask(with: request) { data, _, _ in
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                responseJSON = json
            }
            expectation.fulfill()
        }
        task.resume()

        let result = XCTWaiter.wait(for: [expectation], timeout: 10)
        if result != .completed {
            XCTFail("API GET \(path) 逾時")
        }

        return responseJSON
    }

    /// 建立群組帳本（POST /api/ledgers），回傳帳本 JSON
    static func createGroupLedger(token: String, name: String) -> [String: Any]? {
        let response = apiPost(
            path: "/api/ledgers",
            token: token,
            body: ["name": name]
        )
        return response?["ledger"] as? [String: Any]
    }

    /// 加入帳本（POST /api/ledgers/join）
    static func joinLedgerViaAPI(token: String, inviteCode: String) -> [String: Any]? {
        let response = apiPost(
            path: "/api/ledgers/join",
            token: token,
            body: ["inviteCode": inviteCode]
        )
        return response?["ledger"] as? [String: Any]
    }

    /// 結清帳本（POST /api/ledgers/:id/settle）
    static func settleViaAPI(token: String, ledgerId: Int, transfers: [[String: Any]] = []) -> [String: Any]? {
        let response = apiPost(
            path: "/api/ledgers/\(ledgerId)/settle",
            token: token,
            body: ["transfers": transfers]
        )
        return response?["settlement"] as? [String: Any]
    }

    /// 透過 API 新增開銷（POST /api/ledgers/:id/expenses/batch）
    static func addExpenseViaAPI(token: String, ledgerId: Int, amount: Int, paidByUserId: Int? = nil) -> [String: Any]? {
        var expenseData: [String: Any] = ["amount": amount]
        if let paidByUserId = paidByUserId {
            expenseData["paidByUserId"] = paidByUserId
        }
        let response = apiPost(
            path: "/api/ledgers/\(ledgerId)/expenses/batch",
            token: token,
            body: ["expenses": [expenseData]]
        )
        if let expenses = response?["expenses"] as? [[String: Any]] {
            return expenses.first
        }
        return nil
    }

    /// 透過 API 新增固定開銷
    static func addRecurringExpenseViaAPI(
        token: String,
        ledgerId: Int,
        amount: Int,
        frequencyType: String = "daily",
        frequencyValue: Any? = nil,
        memo: String = "",
        categoryId: Int? = nil
    ) -> [String: Any]? {
        var body: [String: Any] = [
            "amount": amount,
            "frequencyType": frequencyType,
            "memo": memo,
            "isEnabled": true
        ]
        if let frequencyValue = frequencyValue {
            body["frequencyValue"] = frequencyValue
        }
        if let categoryId = categoryId {
            body["categoryId"] = categoryId
        }
        let response = apiPost(
            path: "/api/ledgers/\(ledgerId)/recurring-expenses",
            token: token,
            body: body
        )
        return response?["recurringExpense"] as? [String: Any]
    }

    /// 查詢用戶 ID（透過 MySQL）
    static func getUserId(email: String) -> Int? {
        let row = queryMySQL("SELECT id FROM User WHERE email = '\(email)' LIMIT 1")
        if let idStr = row?["id"] as? String, let id = Int(idStr) {
            return id
        }
        return row?["id"] as? Int
    }
}
