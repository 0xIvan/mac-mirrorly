import Foundation

enum APIError: LocalizedError {
    case unauthorized
    case twoFactorRequired
    case invalidCopytraderID
    case server(Int, String)

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Your session has expired. Sign in again."
        case .twoFactorRequired:
            return "This account requires two-factor authentication, which this app does not support yet."
        case .invalidCopytraderID:
            return "The server returned an invalid copytrader ID."
        case let .server(status, message):
            return message.isEmpty ? "Mirrorly returned HTTP \(status)." : message
        }
    }
}

final class APIClient {
    private let baseURL = URL(string: "https://portal.mirrorly.xyz/api")!
    private let session: URLSession

    init() {
        let configuration = URLSessionConfiguration.default
        configuration.httpCookieStorage = .shared
        configuration.httpShouldSetCookies = true
        configuration.httpCookieAcceptPolicy = .always
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 15
        session = URLSession(configuration: configuration)
    }

    func account() async throws -> Account {
        try await get("/account/me")
    }

    func copytraders() async throws -> [Copytrader] {
        let response: CopytraderList = try await get("/copytrader")
        return response.copytraders ?? []
    }

    func positions(for copytraderID: String) async throws -> [OpenPosition] {
        guard UUID(uuidString: copytraderID) != nil else { throw APIError.invalidCopytraderID }
        let response: OpenPositionsResponse = try await get("/copytrader/\(copytraderID)/position/open")
        return response.data.filter(\.isOpenCopy)
    }

    func login(email: String, password: String, rememberMe: Bool) async throws {
        let payload = LoginRequest(email: email, password: password, rememberMe: rememberMe)
        let data = try JSONEncoder().encode(payload)
        let responseData = try await send("/auth/login", method: "POST", body: data)
        if let nextStep = try? JSONDecoder().decode(LoginNextStep.self, from: responseData),
           nextStep.nextStep?.lowercased() == "2fa" {
            clearCookies()
            throw APIError.twoFactorRequired
        }
    }

    func logout() async {
        _ = try? await send("/auth/logout", method: "POST")
        clearCookies()
    }

    func clearCookies() {
        // The cookie store belongs to this app; remove Mirrorly cookies after logout or incomplete 2FA.
        for cookie in HTTPCookieStorage.shared.cookies ?? [] where cookie.domain.hasSuffix("mirrorly.xyz") {
            HTTPCookieStorage.shared.deleteCookie(cookie)
        }
    }

    private func get<T: Decodable>(_ path: String) async throws -> T {
        let data = try await send(path, method: "GET")
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func send(_ path: String, method: String, body: Data? = nil) async throws -> Data {
        var request = URLRequest(url: URL(string: baseURL.absoluteString + path)!)
        request.httpMethod = method
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if body != nil { request.setValue("application/json", forHTTPHeaderField: "Content-Type") }

        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw APIError.server(0, "Mirrorly returned an invalid response.")
        }
        if response.statusCode == 401 { throw APIError.unauthorized }
        guard (200...299).contains(response.statusCode) else {
            let problem = try? JSONDecoder().decode(ProblemDetails.self, from: data)
            throw APIError.server(response.statusCode, problem?.detail ?? problem?.title ?? "")
        }
        return data
    }
}

private struct LoginRequest: Encodable {
    let email: String
    let password: String
    let rememberMe: Bool
}

private struct LoginNextStep: Decodable {
    let nextStep: String?
}

private struct ProblemDetails: Decodable {
    let title: String?
    let detail: String?
}
