import Combine
import Foundation

enum SessionState: Equatable {
    case checking
    case signedOut
    case signedIn
    case connectionError
}

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var sessionState: SessionState = .checking
    @Published private(set) var copytraders: [Copytrader] = []
    @Published private(set) var positionsByCopytrader: [String: [OpenPosition]] = [:]
    @Published private(set) var selectedIDs: Set<String> = []
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var refreshError: String?
    @Published private(set) var sessionError: String?
    @Published private(set) var loginError: String?
    @Published private(set) var isSigningIn = false
    @Published private(set) var isRefreshing = false

    private let api = APIClient()
    private var userID: String?
    private var hasSavedSelection = false
    private var refreshQueued = false
    private var pollTask: Task<Void, Never>?

    init() {
        Task { await restoreSession() }
    }

    var selectedCopytraders: [Copytrader] {
        copytraders.filter { selectedIDs.contains($0.id) }
    }

    var totalEquity: Decimal {
        copytraders.reduce(0) { $0 + $1.equity }
    }

    var selectedEquity: Decimal {
        selectedCopytraders.reduce(0) { $0 + $1.equity }
    }

    var selectedUnrealizedPnL: Decimal {
        selectedCopytraders.reduce(0) { $0 + $1.unrealizedPnL }
    }

    var dataWarning: String? {
        if let refreshError {
            if lastUpdated == nil {
                return "Refresh failed · No data available. " + refreshError
            }
            return "Refresh failed · Showing last known values" + lastUpdatedDescription + ". " + refreshError
        }
        if let lastUpdated, Date().timeIntervalSince(lastUpdated) > 120 {
            return "Data delayed · Last updated " + lastUpdated.formatted(date: .omitted, time: .shortened)
        }
        return nil
    }

    private var lastUpdatedDescription: String {
        guard let lastUpdated else { return "" }
        return " from " + lastUpdated.formatted(date: .omitted, time: .shortened)
    }

    func restoreSession() async {
        sessionState = .checking
        sessionError = nil
        do {
            let account = try await api.account()
            setAccount(account)
            sessionState = .signedIn
            await refresh()
            startPolling()
        } catch APIError.unauthorized {
            sessionState = .signedOut
        } catch {
            sessionError = error.localizedDescription
            sessionState = .connectionError
        }
    }

    func signIn(email: String, password: String, rememberMe: Bool) async {
        guard !isSigningIn else { return }
        isSigningIn = true
        loginError = nil
        defer { isSigningIn = false }

        do {
            try await api.login(email: email, password: password, rememberMe: rememberMe)
            let account = try await api.account()
            setAccount(account)
            sessionState = .signedIn
            await refresh()
            startPolling()
        } catch {
            loginError = error.localizedDescription
        }
    }

    func signOut() async {
        pollTask?.cancel()
        pollTask = nil
        await api.logout()
        userID = nil
        copytraders = []
        positionsByCopytrader = [:]
        selectedIDs = []
        lastUpdated = nil
        refreshError = nil
        sessionState = .signedOut
    }

    func setSelected(_ selected: Bool, for copytraderID: String) {
        if selected {
            selectedIDs.insert(copytraderID)
        } else {
            selectedIDs.remove(copytraderID)
        }
        saveSelection()
        Task { await refresh() }
    }

    func refresh() async {
        guard sessionState == .signedIn else { return }
        guard !isRefreshing else {
            refreshQueued = true
            return
        }
        isRefreshing = true
        defer {
            isRefreshing = false
            if refreshQueued {
                refreshQueued = false
                Task { await refresh() }
            }
        }

        do {
            let latestCopytraders = try await api.copytraders()
            if !hasSavedSelection {
                selectedIDs = Set(latestCopytraders.map(\.id))
                hasSavedSelection = true
                saveSelection()
            }

            var latestPositions: [String: [OpenPosition]] = [:]
            for copytrader in latestCopytraders where selectedIDs.contains(copytrader.id) {
                latestPositions[copytrader.id] = try await api.positions(for: copytrader.id)
            }

            // Publish the list and its position snapshots together so totals never mix refresh cycles.
            copytraders = latestCopytraders.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
            positionsByCopytrader = latestPositions
            lastUpdated = Date()
            refreshError = nil
        } catch APIError.unauthorized {
            pollTask?.cancel()
            api.clearCookies()
            userID = nil
            copytraders = []
            positionsByCopytrader = [:]
            selectedIDs = []
            sessionState = .signedOut
        } catch {
            refreshError = error.localizedDescription
        }
    }

    private func setAccount(_ account: Account) {
        userID = account.userId
        if let saved = UserDefaults.standard.array(forKey: selectionKey) as? [String] {
            selectedIDs = Set(saved)
            hasSavedSelection = true
        } else {
            selectedIDs = []
            hasSavedSelection = false
        }
    }

    private var selectionKey: String {
        "selectedCopytraders." + (userID ?? "")
    }

    private func saveSelection() {
        guard userID != nil else { return }
        UserDefaults.standard.set(Array(selectedIDs), forKey: selectionKey)
    }

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(nanoseconds: 60_000_000_000) }
                catch { break }
                await self?.refresh()
            }
        }
    }
}
