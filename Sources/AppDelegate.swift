import UIKit

@main
@MainActor
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    private let store = SessionStore()
    private var session: StoredSession?
    private var privacyView: UIView?
    private var expiryTimer: Timer?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.tintColor = .systemIndigo
        self.window = window
        showLogin()
        window.makeKeyAndVisible()
        do {
            if let saved = try store.load() {
                if !saved.session.isExpired, let mode = ServiceMode(rawValue: saved.mode) { showDashboard(saved, service: mode.makeService()) }
                else { try store.clear() }
            }
        } catch { showLogin(message: error.localizedDescription) }
        return true
    }

    private func showLogin(message: String? = nil) {
        expiryTimer?.invalidate(); expiryTimer = nil
        session = nil
        let login = LoginViewController(message: message)
        login.onLogin = { [weak self] session, mode, service in
            guard let self else { return }
            let saved = StoredSession(session: session, mode: mode.rawValue)
            try self.store.save(saved)
            self.showDashboard(saved, service: service)
        }
        window?.rootViewController = UINavigationController(rootViewController: login)
    }

    private func showDashboard(_ saved: StoredSession, service: BankServing) {
        session = saved
        let controller = DashboardViewController(session: saved.session, service: service, mode: ServiceMode(rawValue: saved.mode) ?? .demo)
        controller.onSessionEnded = { [weak self] message in self?.endSession(message: message) }
        window?.rootViewController = UINavigationController(rootViewController: controller)
        expiryTimer?.invalidate()
        expiryTimer = Timer.scheduledTimer(withTimeInterval: max(0.1, saved.session.expiresAt.timeIntervalSinceNow), repeats: false) { [weak self] _ in
            Task { @MainActor in self?.endSession(message: "Your session expired. Please sign in again.") }
        }
    }

    private func endSession(message: String?) {
        do { try store.clear(); showLogin(message: message) }
        catch { showLogin(message: "Signed out of this screen. Could not clear secure storage: \(error.localizedDescription)") }
    }

    func applicationWillResignActive(_ application: UIApplication) {
        guard let window, privacyView == nil else { return }
        let cover = UIView(frame: window.bounds)
        cover.backgroundColor = .systemBackground
        cover.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        window.addSubview(cover); privacyView = cover
    }
    func applicationDidBecomeActive(_ application: UIApplication) {
        if session?.session.isExpired == true { endSession(message: "Your session expired. Please sign in again.") }
        privacyView?.removeFromSuperview(); privacyView = nil
    }
}
