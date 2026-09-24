import Foundation

struct Account: Decodable {
    let userId: String
    let username: String
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
    let data: [OpenPosition]
}

struct OpenPosition: Decodable {
    let copy: CopiedPosition?
    let trader: FollowedTrader?

    var isOpenCopy: Bool { copy?.status.lowercased() == "open" }
    var symbol: String { copy?.symbol ?? trader?.symbol ?? "Unknown" }
    var traderName: String { trader?.name ?? "Unknown trader" }
}

struct CopiedPosition: Decodable {
    let symbol: String?
    let isLong: Bool
    let size: Decimal
    let unrealizedPnl: Decimal
    let status: String
}

struct FollowedTrader: Decodable {
    let name: String?
    let symbol: String?
}

enum Money {
    static func whole(_ amount: Decimal) -> String {
        format(amount, fractionDigits: 0)
    }

    static func signed(_ amount: Decimal) -> String {
        let prefix = amount > 0 ? "+" : ""
        return prefix + format(amount, fractionDigits: 2)
    }

    private static func format(_ amount: Decimal, fractionDigits: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.minimumFractionDigits = fractionDigits
        formatter.maximumFractionDigits = fractionDigits
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "$0"
    }
}
