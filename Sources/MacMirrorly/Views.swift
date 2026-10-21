import AppKit
import SwiftUI

private enum Palette {
    static let accent = Color(red: 196.0 / 255, green: 62.0 / 255, blue: 137.0 / 255)
    // sRGB equivalents of the portal's positive and negative OKLCH tokens.
    static func positive(in scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 96.0 / 255, green: 248.0 / 255, blue: 130.0 / 255) : .green
    }

    static func negative(in scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 222.0 / 255, green: 83.0 / 255, blue: 83.0 / 255) : .red
    }
}

private func pnlColor(_ amount: Decimal, in scheme: ColorScheme) -> Color {
    amount > 0 ? Palette.positive(in: scheme) : amount < 0 ? Palette.negative(in: scheme) : .primary
}

private func leverageColor(_ leverage: Decimal, in scheme: ColorScheme) -> Color {
    leverage <= 1 ? Palette.positive(in: scheme) : leverage < 3 ? .orange : Palette.negative(in: scheme)
}

private func displayedValue(_ value: String, hidden: Bool) -> String {
    hidden ? "••••" : value
}

struct MenuPopover: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Group {
            switch model.sessionState {
            case .checking:
                VStack(spacing: 14) {
                    BrandHeader()
                    ProgressView("Checking your session…")
                        .frame(maxWidth: .infinity, minHeight: 64)
                }
            case .connectionError:
                VStack(alignment: .leading, spacing: 14) {
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
        .padding(16)
        .frame(width: 284)
    }
}

private struct BrandHeader: View {
    var showPortalLink = false

    var body: some View {
        HStack(spacing: 9) {
            Image("MirrorlyMark")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(Palette.accent)
                .frame(width: 32, height: 32)
            Text("MacMirrorly")
                .font(.headline)
            Spacer()
            if showPortalLink {
                Link("Portal ↗", destination: URL(string: "https://portal.mirrorly.xyz/")!)
                    .font(.caption)
                    .tint(Palette.accent)
            }
        }
    }
}

private struct SummaryMetric: View {
    let title: String
    let value: String
    var color: Color = .primary
    var valuesHidden = false
    var onToggleVisibility: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
                Text(title.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                if let onToggleVisibility {
                    Button(action: onToggleVisibility) {
                        Image(systemName: valuesHidden ? "eye.slash" : "eye")
                            .font(.caption2)
                            .offset(y: -1)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(valuesHidden ? "Show values" : "Hide values")
                    .help(valuesHidden ? "Show values" : "Hide values")
                }
            }
            Text(displayedValue(value, hidden: valuesHidden))
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(valuesHidden ? .primary : color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct WarningBanner: View {
    @Environment(\.colorScheme) private var colorScheme
    let message: String
    var isError = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(message)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.caption)
        .foregroundStyle(isError ? Palette.negative(in: colorScheme) : .orange)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SignInView: View {
    @ObservedObject var model: AppModel
    @State private var email = ""
    @State private var password = ""
    @State private var rememberMe = true

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            BrandHeader()
            Text("Sign in to see your copytraders")
                .font(.subheadline.weight(.semibold))
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
            .controlSize(.small)
            .tint(Palette.accent)
            .disabled(email.isEmpty || password.isEmpty || model.isSigningIn)
            Text("Email and password accounts only. Google, Web3, and two-factor sign-in are not supported yet.")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Link("Open Mirrorly portal ↗", destination: URL(string: "https://portal.mirrorly.xyz/")!)
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
                    .buttonStyle(.borderless)
            }
            .font(.caption)
            .controlSize(.small)
        }
    }
}

private struct DashboardView: View {
    @ObservedObject var model: AppModel
    @Environment(\.openSettings) private var openSettings
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            BrandHeader(showPortalLink: true)
            if let dataWarning = model.dataWarning {
                WarningBanner(message: dataWarning, isError: model.refreshError != nil)
            }
            HStack(spacing: 14) {
                SummaryMetric(
                    title: "Total equity",
                    value: Money.whole(model.selectedEquity),
                    valuesHidden: model.valuesHidden,
                    onToggleVisibility: model.toggleValuesHidden
                )
                Divider().frame(height: 36)
                SummaryMetric(
                    title: "24h PnL",
                    value: model.pnl24H.map(Money.signed) ?? "—",
                    color: model.pnl24H.map { pnlColor($0, in: colorScheme) } ?? .primary,
                    valuesHidden: model.valuesHidden
                )
            }

            PositionsCard(model: model)

            Divider()
            HStack(spacing: 8) {
                Button {
                    openSettings()
                    NSApp.activate(ignoringOtherApps: true)
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                Spacer()
                Button {
                    NSApp.terminate(nil)
                } label: {
                    Label("Quit", systemImage: "power")
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
            }
        }
    }
}

private struct PositionsCard: View {
    @ObservedObject var model: AppModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var scrollMetrics = PositionScrollMetrics()
    @State private var scrollController = PositionScrollController()
    @State private var contentHeight: CGFloat?

    private func visiblePositions(for copytrader: Copytrader) -> [OpenPosition] {
        OpenPosition.newestCopiedFirst(model.positionsByCopytrader[copytrader.id] ?? [])
    }

    private var positionCount: Int {
        model.selectedCopytraders.reduce(0) {
            $0 + visiblePositions(for: $1).count
        }
    }

    private var totals: PositionTotals {
        PositionTotals(metas: model.selectedCopytraders.compactMap {
            model.positionMetaByCopytrader[$0.id]
        })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(spacing: 5) {
                PositionTotalRow(title: "OPEN POSITIONS", value: String(positionCount), valuesHidden: model.valuesHidden)
                PositionTotalRow(title: "NOTIONAL", value: Money.twoDecimals(totals.notional), valuesHidden: model.valuesHidden)
                PositionTotalRow(
                    title: "UPNL",
                    value: Money.signed(totals.unrealizedPnL),
                    color: pnlColor(totals.unrealizedPnL, in: colorScheme),
                    valuesHidden: model.valuesHidden
                )
                PositionTotalRow(
                    title: "LEVERAGE",
                    value: Money.leverage(totals.leverage),
                    color: leverageColor(totals.leverage, in: colorScheme),
                    valuesHidden: model.valuesHidden
                )
            }
            .padding(.bottom, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if model.selectedCopytraders.isEmpty {
                        Text("Select a copytrader in Settings to see positions.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(model.selectedCopytraders) { copytrader in
                            CopytraderPositionsGroup(
                                copytrader: copytrader,
                                positions: visiblePositions(for: copytrader),
                                error: model.positionErrorsByCopytrader[copytrader.id],
                                valuesHidden: model.valuesHidden
                            )
                        }
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .onGeometryChange(for: CGFloat.self) { geometry in
                    geometry.size.height
                } action: { height in
                    contentHeight = height
                }
                .background(
                    NativeScrollerHider(controller: scrollController) { metrics in
                        scrollMetrics = metrics
                    }
                    .frame(width: 0, height: 0)
                )
            }
            .scrollIndicators(.hidden)
            .frame(height: min(contentHeight ?? 260, 260))
            // Keep the scrollbar gutter outside the scrollable content's layout.
            .padding(.trailing, 16)
            .overlay(alignment: .topTrailing) {
                if scrollMetrics.height > scrollMetrics.viewportHeight + 1,
                   scrollMetrics.viewportHeight > 0 {
                    PositionScrollbar(metrics: scrollMetrics) { offset in
                        scrollController.scroll(to: offset)
                    }
                }
            }
        }
        .padding(11)
        .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.primary.opacity(0.08)))
    }
}

private struct PositionTotalRow: View {
    let title: String
    let value: String
    var color: Color = .primary
    var valuesHidden = false

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(displayedValue(value, hidden: valuesHidden))
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .foregroundStyle(valuesHidden ? .primary : color)
        }
    }
}

private struct PositionScrollbar: View {
    let metrics: PositionScrollMetrics
    let onScroll: (CGFloat) -> Void
    @State private var dragStartOffset: CGFloat?

    var body: some View {
        let viewportHeight = metrics.viewportHeight
        let thumbHeight = min(viewportHeight, max(22, viewportHeight * viewportHeight / metrics.height))
        let scrollRange = metrics.height - viewportHeight
        let thumbTravel = viewportHeight - thumbHeight
        let progress = min(max(metrics.offset / scrollRange, 0), 1)
        let thumbOffset = progress * thumbTravel

        ZStack(alignment: .top) {
            Capsule()
                .fill(Color.secondary.opacity(0.18))
                .frame(width: 4, height: viewportHeight)
            Capsule()
                .fill(Color.secondary.opacity(0.7))
                .frame(width: 4, height: thumbHeight)
                .offset(y: thumbOffset)
        }
        .frame(width: 12, height: viewportHeight)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    guard thumbTravel > 0 else { return }
                    if dragStartOffset == nil {
                        let startedOnThumb = value.startLocation.y >= thumbOffset
                            && value.startLocation.y <= thumbOffset + thumbHeight
                        dragStartOffset = startedOnThumb
                            ? thumbOffset
                            : value.startLocation.y - thumbHeight / 2
                    }
                    let offset = (dragStartOffset ?? 0) + value.translation.height
                    onScroll(min(max(offset / thumbTravel, 0), 1) * scrollRange)
                }
                .onEnded { _ in dragStartOffset = nil }
        )
        .accessibilityLabel("Positions scroll position")
        .accessibilityValue("\(Int(progress * 100)) percent")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: onScroll(min(metrics.offset + viewportHeight, scrollRange))
            case .decrement: onScroll(max(metrics.offset - viewportHeight, 0))
            @unknown default: break
            }
        }
    }
}

final class PositionScrollController {
    weak var scrollView: NSScrollView?

    func scroll(to offset: CGFloat) {
        guard let scrollView, let documentView = scrollView.documentView else { return }
        let clipView = scrollView.contentView
        let range = max(0, documentView.frame.height - clipView.bounds.height)
        let clampedOffset = min(max(offset, 0), range)
        let y = documentView.isFlipped ? clampedOffset : range - clampedOffset
        let bounds = NSRect(origin: NSPoint(x: clipView.bounds.minX, y: y), size: clipView.bounds.size)
        clipView.scroll(to: clipView.constrainBoundsRect(bounds).origin)
        scrollView.reflectScrolledClipView(clipView)
    }
}

struct NativeScrollerHider: NSViewRepresentable {
    var controller: PositionScrollController? = nil
    var onMetricsChange: ((PositionScrollMetrics) -> Void)?

    func makeNSView(context: Context) -> NativeScrollerHiderView { NativeScrollerHiderView() }

    func updateNSView(_ nsView: NativeScrollerHiderView, context: Context) {
        nsView.controller = controller
        nsView.onMetricsChange = onMetricsChange
        nsView.hideScroller()
    }
}

final class NativeScrollerHiderView: NSView {
    var controller: PositionScrollController?
    private weak var configuredScrollView: NSScrollView?
    private var scrollerObservation: NSKeyValueObservation?
    private var scrollObservation: NSObjectProtocol?
    private var contentObservation: NSObjectProtocol?
    private var lastMetrics = PositionScrollMetrics()
    var onMetricsChange: ((PositionScrollMetrics) -> Void)?

    deinit {
        if let scrollObservation { NotificationCenter.default.removeObserver(scrollObservation) }
        if let contentObservation { NotificationCenter.default.removeObserver(contentObservation) }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        hideScroller()
    }

    func hideScroller() {
        DispatchQueue.main.async { [weak self] in
            guard let self, let scrollView = self.enclosingScrollView else { return }
            self.controller?.scrollView = scrollView
            if self.configuredScrollView !== scrollView {
                if let scrollObservation = self.scrollObservation { NotificationCenter.default.removeObserver(scrollObservation) }
                if let contentObservation = self.contentObservation { NotificationCenter.default.removeObserver(contentObservation) }
                self.scrollerObservation = scrollView.observe(\.hasVerticalScroller, options: [.new]) { [weak self] _, _ in
                    self?.hideScroller()
                }
                self.configuredScrollView = scrollView
                scrollView.contentView.postsBoundsChangedNotifications = true
                self.scrollObservation = NotificationCenter.default.addObserver(
                    forName: NSView.boundsDidChangeNotification,
                    object: scrollView.contentView,
                    queue: .main
                ) { [weak self] _ in self?.updateMetrics() }
                if let documentView = scrollView.documentView {
                    documentView.postsFrameChangedNotifications = true
                    self.contentObservation = NotificationCenter.default.addObserver(
                        forName: NSView.frameDidChangeNotification,
                        object: documentView,
                        queue: .main
                    ) { [weak self] _ in self?.updateMetrics() }
                }
            }
            if scrollView.hasVerticalScroller {
                scrollView.hasVerticalScroller = false
            }
            self.updateMetrics()
        }
    }

    private func updateMetrics() {
        guard let scrollView = configuredScrollView,
              let documentView = scrollView.documentView else { return }
        let visibleRect = scrollView.documentVisibleRect
        let height = documentView.frame.height
        let offset = documentView.isFlipped
            ? visibleRect.minY
            : max(0, height - visibleRect.maxY)
        let metrics = PositionScrollMetrics(
            offset: offset,
            height: height,
            viewportHeight: visibleRect.height
        )
        guard metrics != lastMetrics else { return }
        lastMetrics = metrics
        DispatchQueue.main.async { [weak self] in
            self?.onMetricsChange?(metrics)
        }
    }
}

private struct CopytraderPositionsGroup: View {
    let copytrader: Copytrader
    let positions: [OpenPosition]
    let error: String?
    let valuesHidden: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Text(copytrader.displayName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                if copytrader.displayMode != "Enabled" {
                    ModeBadge(mode: copytrader.displayMode)
                }
            }
            .padding(.top, 6)

            if !copytrader.activeAlarms.isEmpty {
                Text(valuesHidden
                     ? "Alerts active"
                     : "\(copytrader.activeAlarms.count) alert\(copytrader.activeAlarms.count == 1 ? "" : "s")")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.orange)
            }

            ForEach(copytrader.activeAlarms.indices, id: \.self) { index in
                Label(valuesHidden ? "Alert active" : copytrader.activeAlarms[index].displayMessage,
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let error {
                Label("Positions unavailable: \(error)", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if positions.isEmpty && error == nil {
                Text("No open positions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 5)
            } else {
                ForEach(positions.indices, id: \.self) { index in
                    PositionRow(position: positions[index], valuesHidden: valuesHidden)
                }
            }
        }
    }
}

private struct PositionRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let position: OpenPosition
    let valuesHidden: Bool

    var body: some View {
        if let copy = position.copy {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        TrendArrow(isLong: copy.isLong)
                            .stroke(style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                            .frame(width: 16, height: 14)
                            .foregroundStyle(copy.isLong ? Palette.positive(in: colorScheme) : Palette.negative(in: colorScheme))
                            .accessibilityLabel(copy.isLong ? "Long" : "Short")
                        Text(position.symbol).fontWeight(.semibold)
                    }
                    Text(position.traderName)
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                    if let statusLabel = position.statusLabel {
                        Text(statusLabel)
                            .foregroundStyle(.orange)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .trailing, spacing: 3) {
                    Text(displayedValue(Money.twoDecimals(copy.size), hidden: valuesHidden))
                    Text(displayedValue(Money.signed(copy.unrealizedPnl), hidden: valuesHidden))
                        .foregroundStyle(valuesHidden ? .primary : pnlColor(copy.unrealizedPnl, in: colorScheme))
                }
                .monospacedDigit()
            }
            .font(.caption)
            .padding(.vertical, 5)
        }
    }
}

private struct TrendArrow: Shape {
    let isLong: Bool

    func path(in rect: CGRect) -> Path {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * (isLong ? y : 1 - y))
        }

        var path = Path()
        path.move(to: point(0.06, 0.82))
        path.addLine(to: point(0.32, 0.55))
        path.addLine(to: point(0.52, 0.65))
        path.addLine(to: point(0.88, 0.18))
        path.move(to: point(0.68, 0.18))
        path.addLine(to: point(0.88, 0.18))
        path.addLine(to: point(0.88, 0.39))
        return path
    }
}

struct PositionScrollMetrics: Equatable {
    var offset: CGFloat = 0
    var height: CGFloat = 0
    var viewportHeight: CGFloat = 0
}

private struct ModeBadge: View {
    @Environment(\.colorScheme) private var colorScheme
    let mode: String

    private var color: Color {
        switch mode {
        case "Enabled": return Palette.positive(in: colorScheme)
        case "Reduce only": return .orange
        case "Disabled": return Palette.negative(in: colorScheme)
        default: return .secondary
        }
    }

    var body: some View {
        Text(mode)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12), in: Capsule())
    }
}

struct SettingsWindow: View {
    @ObservedObject var model: AppModel
    @ObservedObject var updater: AppUpdater

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            BrandHeader()
            if model.sessionState != .signedIn {
                Text("Sign in from the menu bar to choose copytraders.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(spacing: 14) {
                    SummaryMetric(title: "Total equity", value: Money.whole(model.totalEquity), valuesHidden: model.valuesHidden)
                    Divider().frame(height: 36)
                    SummaryMetric(title: "Selected equity", value: Money.whole(model.selectedEquity), valuesHidden: model.valuesHidden)
                }

                VStack(alignment: .leading, spacing: 0) {
                    Text("YOUR COPYTRADERS")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 8)
                    SettingsTableHeader()
                    Divider().padding(.top, 5)
                    ScrollView {
                        ForEach(model.copytraders) { copytrader in
                            SettingsCopytraderRow(model: model, copytrader: copytrader)
                        }
                    }
                    .frame(height: min(max(CGFloat(model.copytraders.count) * 50, 44), 250))
                }
                .padding(11)
                .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.primary.opacity(0.08)))
            }
            Divider()
            HStack {
                Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—")")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Check for Updates…", action: updater.checkForUpdates)
                    .disabled(!updater.canCheckForUpdates)
            }
            .font(.caption)
            .controlSize(.small)
            Divider()
            HStack(spacing: 8) {
                Button("Sign out") { Task { await model.signOut() } }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                    .disabled(model.sessionState != .signedIn)
                Spacer()
                Link("Open Mirrorly portal ↗", destination: URL(string: "https://portal.mirrorly.xyz/")!)
            }
            .font(.caption)
        }
        .padding(16)
        .frame(width: 582)
    }
}

private struct SettingsTableHeader: View {
    var body: some View {
        HStack(spacing: 8) {
            Text("Show").frame(width: 34, alignment: .leading)
            Text("Copytrader").frame(width: 120, alignment: .leading)
            Text("Status").frame(width: 80, alignment: .leading)
            Text("Exchange").frame(width: 90, alignment: .leading)
            Text("Equity").frame(width: 82, alignment: .trailing)
            Text("UPnL").frame(width: 82, alignment: .trailing)
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
}

private struct SettingsCopytraderRow: View {
    @ObservedObject var model: AppModel
    @Environment(\.colorScheme) private var colorScheme
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
                .tint(Palette.accent)
                .frame(width: 34, alignment: .leading)
                Text(copytrader.displayName)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .frame(width: 120, alignment: .leading)
                ModeBadge(mode: copytrader.displayMode)
                    .frame(width: 80, alignment: .leading)
                Text(copytrader.exchangeRef ?? "—")
                    .lineLimit(1)
                    .frame(width: 90, alignment: .leading)
                Text(displayedValue(Money.whole(copytrader.equity), hidden: model.valuesHidden))
                    .frame(width: 82, alignment: .trailing)
                Text(displayedValue(Money.signed(copytrader.unrealizedPnL), hidden: model.valuesHidden))
                    .foregroundStyle(model.valuesHidden ? .primary : pnlColor(copytrader.unrealizedPnL, in: colorScheme))
                    .frame(width: 82, alignment: .trailing)
            }
            .font(.caption)
            .monospacedDigit()
            .padding(.top, 11)
            .padding(.bottom, copytrader.activeAlarms.isEmpty ? 11 : 2)

            ForEach(copytrader.activeAlarms.indices, id: \.self) { index in
                Label(model.valuesHidden ? "Alert active" : copytrader.activeAlarms[index].displayMessage,
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 42)
                    .padding(.bottom, 7)
            }
            Divider()
        }
    }
}
