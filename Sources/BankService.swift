import Foundation

protocol BankServing {
    func login(email: String, password: String) async throws -> BankSession
    func account(token: String) async throws -> BankAccount
    func transactions(token: String) async throws -> [BankTransaction]
    func logout(token: String) async throws
}

struct DemoBankService: BankServing {
    func login(email: String, password: String) async throws -> BankSession {
        try await Task.sleep(nanoseconds: 350_000_000)
        guard email.lowercased() == "demo@example.com", password == "Demo123!" else { throw BankError.invalidCredentials }
        return BankSession(accessToken: "demo-" + UUID().uuidString, expiresAt: Date().addingTimeInterval(900))
    }
    func account(token: String) async throws -> BankAccount {
        guard token.hasPrefix("demo-") else { throw BankError.unauthorized }
        try await Task.sleep(nanoseconds: 250_000_000)
        return BankAccount(owner: "Alex Morgan", name: "Everyday Checking", maskedNumber: "•••• 4821", balanceCents: 428075, currency: "USD")
    }
    func transactions(token: String) async throws -> [BankTransaction] {
        guard token.hasPrefix("demo-") else { throw BankError.unauthorized }
        return [
            BankTransaction(id: "1", merchant: "Monthly payroll", date: Date().addingTimeInterval(-86400), amountCents: 325000, currency: "USD", category: "Income"),
            BankTransaction(id: "2", merchant: "Neighborhood Market", date: Date().addingTimeInterval(-172800), amountCents: -6842, currency: "USD", category: "Groceries"),
            BankTransaction(id: "3", merchant: "Morning Coffee", date: Date().addingTimeInterval(-259200), amountCents: -575, currency: "USD", category: "Dining"),
            BankTransaction(id: "4", merchant: "Internet bill", date: Date().addingTimeInterval(-345600), amountCents: -6500, currency: "USD", category: "Utilities")
        ]
    }
    func logout(token: String) async throws {}
}

struct RESTBankService: BankServing {
    // Simulator-only loopback endpoint. The included Python backend binds to 127.0.0.1.
    let baseURL: URL
    let session: URLSession
    init(baseURL: URL = URL(string: "http://localhost:8000")!, session: URLSession? = nil) {
        self.baseURL = baseURL
        let config = URLSessionConfiguration.ephemeral
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = session ?? URLSession(configuration: config)
    }
    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601; return decoder
    }

    func login(email: String, password: String) async throws -> BankSession {
        let body = try JSONEncoder().encode(["email": email, "password": password])
        return try await request("/auth/login", method: "POST", body: body)
    }
    func account(token: String) async throws -> BankAccount { try await request("/account", token: token) }
    func transactions(token: String) async throws -> [BankTransaction] { try await request("/transactions", token: token) }
    func logout(token: String) async throws {
        let _: LogoutResponse = try await request("/auth/logout", method: "POST", token: token)
    }
    private struct LogoutResponse: Decodable { let ok: Bool }

    private func request<T: Decodable>(_ path: String, method: String = "GET", token: String? = nil, body: Data? = nil) async throws -> T {
        let url = baseURL.appendingPathComponent(String(path.dropFirst()))
        var request = URLRequest(url: url)
        request.httpMethod = method; request.httpBody = body; request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw BankError.invalidResponse }
        if response.statusCode == 401 { throw path == "/auth/login" ? BankError.invalidCredentials : BankError.unauthorized }
        guard (200..<300).contains(response.statusCode) else { throw BankError.server(response.statusCode) }
        do { return try Self.decoder.decode(T.self, from: data) }
        catch { throw BankError.invalidResponse }
    }
}
