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
            if let errorBody = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = errorBody["message"] as? String {
                throw WatchAPIError.serverError(statusCode: httpResponse.statusCode, message: message)
            }
            throw WatchAPIError.serverError(statusCode: httpResponse.statusCode, message: "Request failed")
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw WatchAPIError.decodingError
        }
    }

    func get<T: Decodable>(path: String, token: String, responseType: T.Type) async throws -> T {
        return try await request(method: "GET", path: path, token: token, responseType: responseType)
    }

    func post<T: Decodable>(path: String, body: [String: Any]?, token: String, responseType: T.Type) async throws -> T {
        return try await request(method: "POST", path: path, body: body, token: token, responseType: responseType)
    }
}
