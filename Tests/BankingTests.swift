import XCTest
@testable import MobileBanking

final class BankingTests: XCTestCase {
    func testSessionExpiry() {
        XCTAssertTrue(BankSession(accessToken: "test", expiresAt: .distantPast).isExpired)
        XCTAssertFalse(BankSession(accessToken: "test", expiresAt: .distantFuture).isExpired)
    }
    func testIncorrectDemoCredentialsFail() async {
        do {
            _ = try await DemoBankService().login(email: "demo@example.com", password: "wrong")
            XCTFail("Incorrect password should be rejected")
        } catch BankError.invalidCredentials {} catch { XCTFail("Unexpected error: \(error)") }
    }
    func testDemoLoginLoadsAccountAndSignedTransactions() async throws {
        let service = DemoBankService()
        let session = try await service.login(email: "demo@example.com", password: "Demo123!")
        let account = try await service.account(token: session.accessToken)
        let transactions = try await service.transactions(token: session.accessToken)
        XCTAssertEqual(account.balanceCents, 428075)
        XCTAssertTrue(transactions.contains { $0.amountCents < 0 })
        XCTAssertTrue(transactions.contains { $0.amountCents > 0 })
    }
    func testRESTDateAndIntegerMoneyContract() throws {
        let data = Data(#"{"id":"1","merchant":"Coffee","date":"2026-09-01T10:00:00Z","amountCents":-575,"currency":"USD","category":"Dining"}"#.utf8)
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let transaction = try decoder.decode(BankTransaction.self, from: data)
        XCTAssertEqual(transaction.amountCents, -575)
        XCTAssertEqual(transaction.merchant, "Coffee")
    }
}
