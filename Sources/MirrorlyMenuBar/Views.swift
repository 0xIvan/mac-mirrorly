import AppKit
import SwiftUI

private enum Palette {
    static let blue = Color(red: 0.04, green: 0.41, blue: 0.87)
    static let green = Color(red: 0.09, green: 0.51, blue: 0.29)
    static let orange = Color(red: 0.62, green: 0.38, blue: 0.02)
    static let red = Color(red: 0.75, green: 0.25, blue: 0.25)
    static let secondary = Color(red: 0.47, green: 0.49, blue: 0.52)
    static let card = Color(red: 0.975, green: 0.978, blue: 0.982)
}

private func pnlColor(_ amount: Decimal) -> Color {
    amount > 0 ? Palette.green : amount < 0 ? Palette.red : .primary
}

struct MenuPopover: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Group {
            switch model.sessionState {
            case .checking:
                VStack(spacing: 18) {
                    BrandHeader()
                    ProgressView("Checking your session…")
                        .frame(maxWidth: .infinity, minHeight: 110)
                }
            case .connectionError:
                VStack(alignment: .leading, spacing: 18) {
                    BrandHeader()
                    WarningBanner(message: model.sessionError ?? "Could not reach Mirrorly", isError: true)
                    Button("Retry connection") { Task { await model.restoreSession() } }
                }
            case .signedOut:
                SignInView(model: model)
            case .signedIn:
                DashboardView(model: model)
            }
        }
        .padding(22)
        .frame(width: 490)
        .background(.white)
    }
}

private struct BrandHeader: View {
    var body: some View {
        HStack(spacing: 13) {
            Text("M")
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(Palette.blue)
                .frame(width: 43, height: 43)
                .background(.white, in: RoundedRectangle(cornerRadius: 11))
                .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(Color.gray.opacity(0.2)))
            Text("Mirrorly")
                .font(.system(size: 21, weight: .bold))
            Spacer()
        }
    }
}

private struct SummaryMetric: View {
    let title: String
    let value: String
    var accent = false

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .bold))
                .tracking(0.7)
                .foregroundStyle(Palette.secondary)
            Text(value)
                .font(.system(size: 23, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(accent ? Palette.blue : .primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct WarningBanner: View {
    let message: String
    var isError = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(message)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(isError ? Palette.red : Palette.orange)
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isError ? Palette.red.opacity(0.08) : Palette.orange.opacity(0.09), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct SignInView: View {
    @ObservedObject var model: AppModel
    @State private var email = ""
    @State private var password = ""
    @State private var rememberMe = true

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            BrandHeader()
            Text("Sign in to see your copytraders")
                .font(.system(size: 17, weight: .semibold))
                .padding(.top, 6)
            TextField("Email", text: $email)
                .textFieldStyle(.roundedBorder)
                .textContentType(.emailAddress)
            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)
                .textContentType(.password)
            Toggle("Stay signed in on this Mac", isOn: $rememberMe)
                .toggleStyle(.checkbox)
            if let loginError = model.loginError {
                WarningBanner(message: loginError, isError: true)
            }
            Button {
                Task { await model.signIn(email: email, password: password, rememberMe: rememberMe) }
            } label: {
                if model.isSigningIn { ProgressView().controlSize(.small) }
                else { Text("Sign in") }
            }
            .buttonStyle(.borderedProminent)
            .disabled(email.isEmpty || password.isEmpty || model.isSigningIn)
            Text("Email and password accounts only. Google, Web3, and two-factor sign-in are not supported yet.")
                .font(.system(size: 11))
                .foregroundStyle(Palette.secondary)
            HStack {
                Link("Open Mirrorly portal ↗", destination: URL(string: "https://portal.mirrorly.xyz/")!)
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
                    .buttonStyle(.plain)
                    .foregroundStyle(Palette.secondary)
            }
            .font(.system(size: 12))
            .padding(.top, 8)
        }
    }
}

private struct DashboardView: View {
    @ObservedObject var model: AppModel
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            BrandHeader()
            if let dataWarning = model.dataWarning {
                WarningBanner(message: dataWarning, isError: model.refreshError != nil)
                    .padding(.top, 16)
            }
            HStack(alignment: .top, spacing: 25) {
                SummaryMetric(title: "Total equity", value: Money.whole(model.selectedEquity), accent: true)
                Rectangle()
                    .fill(Color.gray.opacity(0.24))
                    .frame(width: 1, height: 48)
                SummaryMetric(title: "Unrealized PnL", value: Money.signed(model.selectedUnrealizedPnL))
            }
            .padding(.vertical, 24)

            PositionsCard(model: model)

            Divider().padding(.top, 20)
            HStack(spacing: 14) {
                Button {
                    openSettings()
                    NSApp.activate(ignoringOtherApps: true)
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
                .buttonStyle(.bordered)
                Spacer()
                Link("Open portal ↗", destination: URL(string: "https://portal.mirrorly.xyz/")!)
                    .fontWeight(.semibold)
                Button {
                    NSApp.terminate(nil)
                } label: {
                    Label("Quit", systemImage: "power")
                }
                .buttonStyle(.plain)
                .foregroundStyle(Palette.secondary)
            }
            .padding(.top, 17)
        }
    }
}

private struct PositionsCard: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("OPEN POSITIONS")
                .font(.system(size: 12, weight: .bold))
                .tracking(0.7)
                .foregroundStyle(Palette.secondary)
                .padding(.bottom, 12)

            HStack(spacing: 5) {
                Text("Symbol").frame(width: 75, alignment: .leading)
                Text("Trader").frame(maxWidth: .infinity, alignment: .leading)
                Text("Notional").frame(width: 80, alignment: .trailing)
                Text("Unrealized").frame(width: 91, alignment: .trailing)
            }
            .font(.system(size: 11))
            .foregroundStyle(Palette.secondary)
            Divider().padding(.top, 7)

            ScrollView {
                if model.selectedCopytraders.isEmpty {
                    Text("Select a copytrader in Settings to see positions.")
                        .foregroundStyle(Palette.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 16)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(model.selectedCopytraders) { copytrader in
                            CopytraderPositionsGroup(
                                copytrader: copytrader,
                                positions: model.positionsByCopytrader[copytrader.id] ?? []
                            )
                        }
                    }
                }
            }
            .frame(maxHeight: 310)
        }
        .padding(18)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.gray.opacity(0.18)))
    }
}

private struct CopytraderPositionsGroup: View {
    let copytrader: Copytrader
    let positions: [OpenPosition]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 7) {
                Text(copytrader.displayName).fontWeight(.bold)
                if copytrader.displayMode != "Enabled" {
                    ModeBadge(mode: copytrader.displayMode)
                }
                if !copytrader.activeAlarms.isEmpty {
                    Text("\(copytrader.activeAlarms.count) alert\(copytrader.activeAlarms.count == 1 ? "" : "s")")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Palette.orange)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Palette.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 5))
                }
            }
            .font(.system(size: 12))
            .padding(.top, 9)

            ForEach(copytrader.activeAlarms.indices, id: \.self) { index in
                Label(copytrader.activeAlarms[index].displayMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if positions.isEmpty {
                Text("No open copied positions")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.secondary)
                    .padding(.vertical, 5)
            } else {
                ForEach(positions.indices, id: \.self) { index in
                    PositionRow(position: positions[index])
                }
            }
            Divider().padding(.top, 4)
        }
    }
}

private struct PositionRow: View {
    let position: OpenPosition

    var body: some View {
        if let copy = position.copy {
            HStack(spacing: 5) {
                HStack(spacing: 4) {
                    Image(systemName: copy.isLong ? "arrow.up.right" : "arrow.down.right")
                        .fontWeight(.bold)
                        .foregroundStyle(copy.isLong ? Palette.green : Palette.red)
                        .accessibilityLabel(copy.isLong ? "Long" : "Short")
                    Text(position.symbol).fontWeight(.semibold)
                }
                .frame(width: 75, alignment: .leading)
                Text(position.traderName)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(Money.whole(copy.size))
                    .frame(width: 80, alignment: .trailing)
                Text(Money.signed(copy.unrealizedPnl))
                    .foregroundStyle(pnlColor(copy.unrealizedPnl))
                    .frame(width: 91, alignment: .trailing)
            }
            .font(.system(size: 12))
            .monospacedDigit()
            .padding(.vertical, 5)
        }
    }
}

private struct ModeBadge: View {
    let mode: String

    private var color: Color {
        switch mode {
        case "Enabled": return Palette.green
        case "Reduce only": return Palette.orange
        case "Disabled": return Palette.red
        default: return Palette.secondary
        }
    }

    var body: some View {
        Text(mode)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(color.opacity(0.11), in: RoundedRectangle(cornerRadius: 5))
    }
}

struct SettingsWindow: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            BrandHeader()
            if model.sessionState != .signedIn {
                Text("Sign in from the menu bar to choose copytraders.")
                    .foregroundStyle(Palette.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack(alignment: .top, spacing: 28) {
                    SummaryMetric(title: "Total equity", value: Money.whole(model.totalEquity), accent: true)
                    Rectangle().fill(Color.gray.opacity(0.24)).frame(width: 1, height: 48)
                    SummaryMetric(title: "Selected equity", value: Money.whole(model.selectedEquity))
                }
                .padding(.vertical, 24)

                VStack(alignment: .leading, spacing: 0) {
                    Text("YOUR COPYTRADERS")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(0.7)
                        .foregroundStyle(Palette.secondary)
                        .padding(.bottom, 14)
                    SettingsTableHeader()
                    Divider().padding(.top, 7)
                    ScrollView {
                        ForEach(model.copytraders) { copytrader in
                            SettingsCopytraderRow(model: model, copytrader: copytrader)
                        }
                    }
                }
                .padding(18)
                .background(Palette.card, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.gray.opacity(0.18)))
            }
            Divider().padding(.top, 18)
            HStack {
                Button("Sign out") { Task { await model.signOut() } }
                    .buttonStyle(.plain)
                    .disabled(model.sessionState != .signedIn)
                Spacer()
                Link("Open Mirrorly portal ↗", destination: URL(string: "https://portal.mirrorly.xyz/")!)
            }
            .font(.system(size: 12))
            .padding(.top, 15)
        }
        .padding(22)
        .frame(minWidth: 690, minHeight: 390)
        .background(.white)
    }
}

private struct SettingsTableHeader: View {
    var body: some View {
        HStack(spacing: 8) {
            Text("Show").frame(width: 40, alignment: .leading)
            Text("Copytrader").frame(width: 132, alignment: .leading)
            Text("Status").frame(width: 92, alignment: .leading)
            Text("Exchange").frame(width: 102, alignment: .leading)
            Text("Equity").frame(width: 89, alignment: .trailing)
            Text("UPnL").frame(width: 89, alignment: .trailing)
            Spacer(minLength: 0)
        }
        .font(.system(size: 11))
        .foregroundStyle(Palette.secondary)
    }
}

private struct SettingsCopytraderRow: View {
    @ObservedObject var model: AppModel
    let copytrader: Copytrader

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Toggle("Show \(copytrader.displayName)", isOn: Binding(
                    get: { model.selectedIDs.contains(copytrader.id) },
                    set: { model.setSelected($0, for: copytrader.id) }
                ))
                .labelsHidden()
                .toggleStyle(.checkbox)
                .frame(width: 40, alignment: .leading)
                Text(copytrader.displayName)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .frame(width: 132, alignment: .leading)
                ModeBadge(mode: copytrader.displayMode)
                    .frame(width: 92, alignment: .leading)
                Text(copytrader.exchangeRef ?? "—")
                    .lineLimit(1)
                    .frame(width: 102, alignment: .leading)
                Text(Money.whole(copytrader.equity))
                    .frame(width: 89, alignment: .trailing)
                Text(Money.signed(copytrader.unrealizedPnL))
                    .foregroundStyle(pnlColor(copytrader.unrealizedPnL))
                    .frame(width: 89, alignment: .trailing)
                Spacer(minLength: 0)
            }
            .font(.system(size: 12))
            .monospacedDigit()
            .padding(.top, 11)
            .padding(.bottom, copytrader.activeAlarms.isEmpty ? 11 : 2)

            ForEach(copytrader.activeAlarms.indices, id: \.self) { index in
                Label(copytrader.activeAlarms[index].displayMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 48)
                    .padding(.bottom, 7)
            }
            Divider()
        }
    }
}
