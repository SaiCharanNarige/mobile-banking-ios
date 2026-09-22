# PocketBank — Mobile Banking Prototype

A UIKit portfolio application with sign-in, a fictional account summary, transaction history, and Keychain-backed session storage.

**Stack:** Swift · UIKit · Auto Layout · URLSession · REST · Security/Keychain · XCTest  
**Target:** iOS 16+ · Xcode 15+ · Python 3.10+ for the optional local backend  
**Dependencies:** Apple frameworks and Python standard library only

## Run immediately in demo mode

1. Open `MobileBanking.xcodeproj` on a Mac with Xcode and an iOS Simulator runtime.
2. Select the **MobileBanking** scheme and an **iPhone simulator**, then press **⌘R**.
3. Leave **Demo** selected on the sign-in screen.
4. Use **demo@example.com** and **Demo123!**. These public, fictional demo credentials are prefilled.
5. Review the account summary and recent transactions. Pull down to refresh or select Sign out.

Demo mode simulates asynchronous service calls without making network requests. Local API mode uses real HTTP requests to the included mock backend. All names, account numbers, balances, and transactions are fictional.

For device builds, set a signing team and unique bundle identifier. The localhost backend instructions below target the iOS Simulator on the same Mac, not a physical phone.

## Run with the local REST API

In Terminal, from this project directory:

```bash
python3 backend/server.py
```

Keep that terminal open. In the app, sign out if needed, select **Local API**, and sign in with the same demo credentials. The simulator reaches the Mac's loopback server at `http://localhost:8000`.

The server only binds to `127.0.0.1`. The app's development HTTP exception is scoped to `localhost`. No global insecure transport exception is enabled. For a deployed backend, use HTTPS and remove the localhost exception; this mock server is not intended for public deployment.

## Implemented features

- UIKit login, account summary, and transaction history screens.
- Programmatic Auto Layout, scrollable sign-in form, keyboard avoidance, and Dynamic Type.
- URLSession REST client with HTTP status validation and typed JSON decoding.
- Bearer-token authentication; server-side expiry and logout revocation in local API mode.
- Keychain storage of the session token, expiry, and selected service mode.
- Session restoration, expiry timer, foreground expiry checks, and 401 handling.
- Loading indicators, sign-in validation, API error alerts, and retry actions.
- Integer-cent money representation and formatted amounts.
- A privacy cover while the app is inactive to obscure the app-switcher snapshot.
- XCTest cases, Python REST integration tests, and GitHub Actions configuration.

## Architecture

```text
Sources/
  AppDelegate.swift              App lifecycle, routing, session expiry
  Models.swift                   Account, transaction, session, and errors
  BankService.swift              Protocol, bundled demo, REST implementation
  SessionStore.swift             Keychain save/load/delete
  LoginViewController.swift      Auto Layout sign-in interface
  DashboardViewController.swift  Summary, transactions, refresh, sign out
Tests/
  BankingTests.swift             Session, demo service, JSON contract tests
backend/
  server.py                     Dependency-free loopback REST API
  test_server.py                HTTP integration tests
```

Controllers depend on `BankServing`. The selected implementation is either `DemoBankService` or `RESTBankService`. AppDelegate owns navigation and session persistence. This intentionally small project uses UIKit controllers with an extracted service layer rather than claiming a full MVVM architecture.

The REST client's ephemeral URLSession disables URL caching for account responses. Credentials are submitted only during login and are never saved. Only the returned session is saved in Keychain using `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`. The client does not log tokens or passwords.

## REST contract

| Method | Path | Authentication | Result |
| --- | --- | --- | --- |
| GET | `/health` | None | Health status |
| POST | `/auth/login` | Demo email/password JSON | Opaque token + ISO-8601 expiry |
| GET | `/account` | Bearer token | Fictional account summary |
| GET | `/transactions` | Bearer token | Fictional recent transactions |
| POST | `/auth/logout` | Bearer token | Revokes token |

Login request:

```json
{"email":"demo@example.com","password":"Demo123!"}
```

The server returns `accessToken` and `expiresAt`. Protected requests carry `Authorization: Bearer <token>`. Tokens expire after 15 minutes. Server sessions live in memory; restarting the server invalidates existing API sessions. The client returns to sign-in when the API responds with 401.

The bundled demo mode only simulates authentication, with client-managed expiry and no remote revocation. It must not be described as production authentication. Account balances are fixtures; the short transaction list is not a complete ledger.

## Tests

Run iOS tests using **⌘U** in Xcode. Run backend tests with:

```bash
python3 -m unittest discover -s backend -v
```

The eight backend tests cover successful login/account retrieval, incorrect credentials, missing/unknown tokens, expired tokens, logout revocation, transaction schema, invalid request shapes, and unknown routes. They use a temporary loopback port without requiring a separately running server.

Manual iOS checks:

1. Try an incorrect password and confirm the inline error.
2. Sign in using Demo, then relaunch to verify session restoration.
3. Sign out and relaunch to confirm the app stays signed out.
4. Start the backend, choose Local API, sign in, and refresh.
5. Stop the backend and refresh; confirm the retry alert.
6. Restart the backend and refresh; confirm an invalid session returns to sign-in.
7. Check dark mode, large text, keyboard behavior, VoiceOver, and the app-switcher privacy cover.

## GitHub

Create an empty repository named `mobile-banking-ios`. In this project folder:

```bash
git init -b main
git add .
git commit -m "Add UIKit banking prototype and mock REST API"
git remote add origin https://github.com/YOUR_USERNAME/mobile-banking-ios.git
git push -u origin main
```

Replace `YOUR_USERNAME` with your GitHub username. The included workflow runs Xcode tests on an available iPhone simulator and tests the Python backend.

Suggested repository description: **UIKit banking prototype with token authentication, Keychain session storage, account summaries, transaction history, and a local REST backend.**

Suggested topics: `swift` `uikit` `ios` `keychain` `rest-api` `autolayout` `xctest`.

After running the app, add your own simulator screenshots of sign-in, account summary, and transaction history. Demonstrate both an API error and a successful retry in a short screen recording.

## Scope and validation

This is a learning/portfolio prototype, not software for real banking. It has no real bank integration, payment execution, biometric sign-in, MFA, token refresh, production identity provider, audit service, or security assessment. The local backend has one fictional user and no production rate limiting or database.

**Validation completed:** all eight Python backend integration tests passed; project configuration and referenced files were checked. **Not run here:** iOS compilation, XCTest, simulator UI, VoiceOver, or device Keychain behavior, because this environment has no Xcode or Apple SDKs. Run the app and tests on your Mac before publishing verified functionality claims.

Reference: [Apple Keychain accessibility](https://developer.apple.com/documentation/security/ksecattraccessiblewhenunlockedthisdeviceonly).
