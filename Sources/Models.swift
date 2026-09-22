import Foundation

struct BankSession: Codable {
    let accessToken: String
    let expiresAt: Date
    var isExpired: Bool { expiresAt <= Date() }
}

struct BankAccount: Codable {
    let owner: String
    let name: String
    let maskedNumber: String
    let balanceCents: Int
    let currency: String
}

struct BankTransaction: Codable, Identifiable {
    let id: String
    let merchant: String
    let date: Date
    let amountCents: Int
    let currency: String
    let category: String
}

enum Money {
    static func format(cents: Int, currency: String = "USD") -> String {
        (Decimal(cents) / 100).formatted(.currency(code: currency))
    }
}

enum BankError: LocalizedError {
    case invalidCredentials, unauthorized, server(Int), invalidResponse, keychain(Int32)
    var errorDescription: String? {
        switch self {
        case .invalidCredentials: return "The demo email or password is incorrect."
        case .unauthorized: return "Your session expired. Please sign in again."
        case .server(let code): return "The server returned error \(code). Please retry."
        case .invalidResponse: return "The server response could not be read."
        case .keychain(let code): return "Secure storage is unavailable (\(code)). Please try again."
        }
    }
}

enum ServiceMode: Int {
    case demo = 0, localAPI = 1
    var title: String { self == .demo ? "Bundled demo" : "Local REST API" }
    func makeService() -> BankServing {
        if self == .demo { return DemoBankService() }
        return RESTBankService()
    }
}
