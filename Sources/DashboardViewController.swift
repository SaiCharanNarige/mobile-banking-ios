import UIKit

@MainActor
final class DashboardViewController: UITableViewController {
    var onSessionEnded: ((String?) -> Void)?
    private let session: BankSession
    private let service: BankServing
    private let mode: ServiceMode
    private var account: BankAccount?
    private var transactions: [BankTransaction] = []
    private var loading = false
    private var signingOut = false
    private let spinner = UIActivityIndicatorView(style: .large)

    init(session: BankSession, service: BankServing, mode: ServiceMode) {
        self.session = session; self.service = service; self.mode = mode
        super.init(style: .insetGrouped)
    }
    required init?(coder: NSCoder) { fatalError("Use programmatic initialization") }
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Overview"
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Sign out", style: .plain, target: self, action: #selector(signOut))
        refreshControl = UIRefreshControl()
        refreshControl?.addTarget(self, action: #selector(refresh), for: .valueChanged)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 88
        Task { await reload() }
    }
    @objc private func refresh() { Task { await reload() } }
    private func reload() async {
        guard !loading, !signingOut else { return }
        guard !session.isExpired else { onSessionEnded?(BankError.unauthorized.localizedDescription); return }
        loading = true
        if account == nil { tableView.backgroundView = spinner; spinner.startAnimating() }
        defer { loading = false; spinner.stopAnimating(); tableView.backgroundView = nil; refreshControl?.endRefreshing() }
        do {
            async let accountResult = service.account(token: session.accessToken)
            async let transactionResult = service.transactions(token: session.accessToken)
            let result = try await (accountResult, transactionResult)
            guard !signingOut else { return }
            account = result.0
            transactions = result.1.sorted { $0.date > $1.date }
            tableView.reloadData()
        } catch BankError.unauthorized { onSessionEnded?(BankError.unauthorized.localizedDescription) }
        catch {
            guard !signingOut else { return }
            let alert = UIAlertController(title: "Could not load account", message: error.localizedDescription, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Retry", style: .default) { [weak self] _ in self?.refresh() })
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            present(alert, animated: true)
        }
    }
    @objc private func signOut() {
        guard !signingOut else { return }
        signingOut = true
        navigationItem.rightBarButtonItem?.isEnabled = false
        Task {
            var message: String?
            do { try await service.logout(token: session.accessToken) }
            catch { message = "Signed out locally. Server revocation could not be confirmed; the demo token expires after 15 minutes." }
            onSessionEnded?(message)
        }
    }

    override func numberOfSections(in tableView: UITableView) -> Int { 2 }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? 1 : max(1, transactions.count)
    }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        section == 0 ? "Account summary" : "Recent transactions"
    }
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        section == 0 ? "\(mode.title) • Fictional account • USD" : "Sample recent activity, not a full account ledger. No transfers or payments."
    }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "row") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "row")
        var content = cell.defaultContentConfiguration()
        if indexPath.section == 0 {
            if let account {
                content.text = Money.format(cents: account.balanceCents, currency: account.currency)
                content.textProperties.font = .preferredFont(forTextStyle: .largeTitle)
                content.secondaryText = "\(account.owner)\n\(account.name) \(account.maskedNumber)"
                content.image = UIImage(systemName: "creditcard.fill")
            } else { content.text = "Pull down to load your account" }
        } else if transactions.isEmpty {
            content.text = account == nil ? "Transactions will appear after loading" : "No recent transactions"
            content.image = UIImage(systemName: "list.bullet.rectangle")
        } else {
            let transaction = transactions[indexPath.row]
            content.text = "\(transaction.merchant)\n\(Money.format(cents: transaction.amountCents, currency: transaction.currency))"
            content.secondaryText = "\(transaction.category) • \(transaction.date.formatted(date: .abbreviated, time: .omitted))"
            content.image = UIImage(systemName: transaction.amountCents > 0 ? "arrow.down.circle.fill" : "arrow.up.circle")
        }
        content.textProperties.numberOfLines = 0
        content.secondaryTextProperties.numberOfLines = 0
        content.imageProperties.tintColor = .systemIndigo
        cell.contentConfiguration = content; cell.selectionStyle = .none
        return cell
    }
}
