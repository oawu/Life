import Foundation

enum WatchAPIError: LocalizedError {
    case noToken
    case invalidURL
    case invalidResponse
    case serverError(statusCode: Int, message: String)
    case decodingError
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .noToken:
            return "No authentication token"
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response"
        case .serverError(_, let message):
            return message
        case .decodingError:
            return "Failed to decode response"
        case .networkError(let error):
            return error.localizedDescription
        }
    }

    var isUnauthorized: Bool {
        if case .serverError(let code, _) = self, code == 401 {
            return true
        }
        return false
    }
}

final class WatchAPIClient {
    static let shared = WatchAPIClient()

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        session = URLSession(configuration: config)
    }

    func request<T: Decodable>(
        method: String,
        path: String,
        body: [String: Any]? = nil,
        token: String,
        responseType: T.Type
    ) async throws -> T {
        let urlString = AppEnvironment.apiBaseURL + path

        guard let url = URL(string: urlString) else {
            throw WatchAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let body = body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        // 請求 log
        let bodyStr = body.flatMap { try? JSONSerialization.data(withJSONObject: $0) }.flatMap { String(data: $0, encoding: .utf8) } ?? "nil"
        print("[WatchAPI] → \(method) \(urlString)")
        print("[WatchAPI]   body: \(bodyStr)")
        print("[WatchAPI]   token: \(String(token.prefix(20)))...")

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            print("[WatchAPI] ✗ 網路錯誤：\(error)")
            throw WatchAPIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw WatchAPIError.invalidResponse
        }

        let responseStr = String(data: data, encoding: .utf8) ?? "nil"
        print("[WatchAPI] ← \(httpResponse.statusCode) \(responseStr.prefix(500))")

        if httpResponse.statusCode < 200 || httpResponse.statusCode >= 300 {
            let message = Self.parseErrorMessage(from: data)
            throw WatchAPIError.serverError(statusCode: httpResponse.statusCode, message: message)
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            print("[WatchAPI] ✗ decode 失敗，原始回應：\(responseStr)")
            throw WatchAPIError.decodingError
        }
    }

    func get<T: Decodable>(path: String, token: String, responseType: T.Type) async throws -> T {
        return try await request(method: "GET", path: path, token: token, responseType: responseType)
    }

    func post<T: Decodable>(path: String, body: [String: Any]?, token: String, responseType: T.Type) async throws -> T {
        return try await request(method: "POST", path: path, body: body, token: token, responseType: responseType)
    }

    func postIgnoringResponse(path: String, body: [String: Any]?, token: String) async throws {
        let urlString = AppEnvironment.apiBaseURL + path

        guard let url = URL(string: urlString) else {
            throw WatchAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let body = body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw WatchAPIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw WatchAPIError.invalidResponse
        }

        if httpResponse.statusCode < 200 || httpResponse.statusCode >= 300 {
            let message = Self.parseErrorMessage(from: data)
            throw WatchAPIError.serverError(statusCode: httpResponse.statusCode, message: message)
        }
    }

    // MARK: - Error Parsing

    private static func parseErrorMessage(from data: Data) -> String {
        guard let errorBody = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return String(data: data, encoding: .utf8) ?? "Request failed"
        }
        // Maple 框架格式：{ "messages": ["..."] }
        if let messages = errorBody["messages"] as? [String], let first = messages.first {
            return first
        }
        // 一般格式：{ "message": "..." }
        if let message = errorBody["message"] as? String {
            return message
        }
        return "Request failed"
    }
}
