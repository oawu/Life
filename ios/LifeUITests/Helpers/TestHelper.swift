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

        let body: [String: Any] = ["isDev": true, "email": email]
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
}
