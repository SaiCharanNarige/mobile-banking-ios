import UIKit

@MainActor
final class LoginViewController: UIViewController {
    var onLogin: ((BankSession, ServiceMode, BankServing) throws -> Void)?
    private let email = UITextField()
    private let password = UITextField()
    private let mode = UISegmentedControl(items: ["Demo", "Local API"])
    private let button = UIButton(type: .system)
    private let status = UILabel()
    private let spinner = UIActivityIndicatorView(style: .medium)
    private let initialMessage: String?

    init(message: String?) { initialMessage = message; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError("Use programmatic initialization") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "PocketBank"
        view.backgroundColor = .systemGroupedBackground
        let scroll = UIScrollView()
        scroll.keyboardDismissMode = .interactive
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor)
        ])
        let heading = label("Your money.\nA clearer view.", style: .largeTitle)
        let explanation = label("A UIKit banking portfolio prototype. All accounts and transactions are fictional.", style: .body)
        explanation.textColor = .secondaryLabel
        configure(email, placeholder: "Email", secure: false)
        email.keyboardType = .emailAddress; email.textContentType = .username
        email.text = "demo@example.com"
        configure(password, placeholder: "Password", secure: true)
        password.textContentType = .password; password.text = "Demo123!"
        mode.selectedSegmentIndex = 0
        mode.accessibilityLabel = "Data source"
        button.configuration = .filled()
        button.configuration?.title = "Sign in"
        button.addTarget(self, action: #selector(signIn), for: .touchUpInside)
        status.numberOfLines = 0; status.font = .preferredFont(forTextStyle: .footnote)
        status.adjustsFontForContentSizeCategory = true; status.textColor = .secondaryLabel
        status.text = initialMessage ?? "Demo: demo@example.com / Demo123!\nLocal API: start backend/server.py on your Mac, then use the iOS Simulator."
        let stack = UIStackView(arrangedSubviews: [heading, explanation, mode, email, password, button, spinner, status])
        stack.axis = .vertical; stack.spacing = 22; stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 32),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -24),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -32),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -48),
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 50)
        ])
    }

    private func configure(_ field: UITextField, placeholder: String, secure: Bool) {
        field.placeholder = placeholder; field.accessibilityLabel = placeholder
        field.borderStyle = .roundedRect; field.isSecureTextEntry = secure
        field.autocapitalizationType = .none; field.autocorrectionType = .no
        field.font = .preferredFont(forTextStyle: .body); field.adjustsFontForContentSizeCategory = true
        field.heightAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
    }
    private func label(_ text: String, style: UIFont.TextStyle) -> UILabel {
        let label = UILabel(); label.text = text; label.numberOfLines = 0
        label.font = .preferredFont(forTextStyle: style); label.adjustsFontForContentSizeCategory = true
        return label
    }
    @objc private func signIn() {
        view.endEditing(true)
        let emailValue = (email.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let passwordValue = password.text ?? ""
        guard !emailValue.isEmpty, !passwordValue.isEmpty else { status.text = "Enter your email and password."; return }
        let selected = ServiceMode(rawValue: mode.selectedSegmentIndex) ?? .demo
        let service = selected.makeService()
        setLoading(true)
        status.text = "Signing in…"
        Task {
            defer { setLoading(false) }
            do {
                let session = try await service.login(email: emailValue, password: passwordValue)
                try onLogin?(session, selected, service)
                password.text = ""
            } catch {
                status.text = error.localizedDescription
                UIAccessibility.post(notification: .announcement, argument: status.text)
            }
        }
    }
    private func setLoading(_ loading: Bool) {
        button.isEnabled = !loading; mode.isEnabled = !loading
        email.isEnabled = !loading; password.isEnabled = !loading
        if loading { spinner.startAnimating() } else { spinner.stopAnimating() }
    }
}
