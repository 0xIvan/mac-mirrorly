import Foundation

struct Account: Decodable {
    let userId: String
    let username: String
}

struct AccountPnLStatistics: Decodable {
    let totalPnL24H: Decimal
}

struct CopytraderList: Decodable {
    let copytraders: [Copytrader]?
}

struct Copytrader: Decodable, Identifiable {
    let copytraderId: String
    let name: String?
    let mode: String?
    let equity: Decimal
    let unrealizedPnL: Decimal
    let exchangeRef: String?
    let alarms: [CopytraderAlarm]?

    var id: String { copytraderId }
    var displayName: String { name.flatMap { $0.isEmpty ? nil : $0 } ?? "Unnamed copytrader" }

    var displayMode: String {
        switch mode?.lowercased() {
        case "enabled": return "Enabled"
        case "reduceonly": return "Reduce only"
        case "disabled": return "Disabled"
        default: return mode ?? "Unknown"
        }
    }

    var activeAlarms: [CopytraderAlarm] {
        (alarms ?? []).filter { ["active", "critical", "error"].contains($0.status.lowercased()) }
    }
}

struct CopytraderAlarm: Decodable {
    let status: String
    let message: String?
    let type: String?

    var displayMessage: String {
        if let message, !message.isEmpty { return message }
        return type ?? "Copytrader needs attention"
    }
}

struct OpenPositionsResponse: Decodable {
    let meta: OpenPositionsMeta
    let data: [OpenPosition]
}

struct OpenPositionsMeta: Decodable {
    let equity: Decimal
    let leverage: Decimal
    let totalSize: Decimal
    let totalUnrealizedPnl: Decimal
}

struct PositionTotals {
    let notional: Decimal
    let unrealizedPnL: Decimal
    let leverage: Decimal

    init(metas: [OpenPositionsMeta]) {
        notional = metas.reduce(0) { $0 + $1.totalSize }
        unrealizedPnL = metas.reduce(0) { $0 + $1.totalUnrealizedPnl }
        let equity = metas.reduce(Decimal(0)) { $0 + $1.equity }
        leverage = equity == 0 ? 0 : notional / equity
    }
}

struct OpenPosition: Decodable {
    let copy: CopiedPosition?
    let trader: FollowedTrader?

    static func newestCopiedFirst(_ positions: [OpenPosition]) -> [OpenPosition] {
        positions.enumerated()
            .compactMap { index, position -> (index: Int, position: OpenPosition, opened: Date?)? in
                guard position.isCopied else { return nil }
                return (index, position, position.copy?.opened.flatMap(PositionDate.parse))
            }
            .sorted { lhs, rhs in
                switch (lhs.opened, rhs.opened) {
                case let (left?, right?) where left != right: return left > right
                case (_?, nil): return true
                case (nil, _?): return false
                default: return lhs.index < rhs.index
                }
            }
            .map(\.position)
    }

    var symbol: String { copy?.symbol ?? trader?.symbol ?? "Unknown" }
    var traderName: String { trader?.name ?? "Unknown trader" }
    var isCopied: Bool { copy != nil }

    var statusLabel: String? {
        guard let copy else { return nil }
        switch copy.status.lowercased() {
        case "open": return nil
        case "waitingforsizetoopen": return "Waiting to open"
        case "opening": return "Opening"
        case "ignored": return "Ignored"
        default: return "Status unknown"
        }
    }
}

struct CopiedPosition: Decodable {
    let symbol: String?
    let isLong: Bool
    let opened: String?
    let size: Decimal
    let unrealizedPnl: Decimal
    let status: String
}

private enum PositionDate {
    private static let fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    private static let wholeSeconds = ISO8601DateFormatter()

    static func parse(_ value: String) -> Date? {
        return fractional.date(from: value) ?? wholeSeconds.date(from: value)
    }
}

struct FollowedTrader: Decodable {
    let name: String?
    let symbol: String?
}

enum Money {
    static func whole(_ amount: Decimal) -> String {
        format(amount, fractionDigits: 0)
    }

    static func twoDecimals(_ amount: Decimal) -> String {
        format(amount, fractionDigits: 2)
    }

    static func signed(_ amount: Decimal) -> String {
        let prefix = amount > 0 ? "+" : ""
        return prefix + format(amount, fractionDigits: 2)
    }

    static func leverage(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        return (formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "0") + "×"
    }

    private static func format(_ amount: Decimal, fractionDigits: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = fractionDigits
        formatter.maximumFractionDigits = fractionDigits
        let magnitude = amount < 0 ? -amount : amount
        let value = formatter.string(from: NSDecimalNumber(decimal: magnitude)) ?? "0"
        return (amount < 0 ? "-$" : "$") + value
    }
}
