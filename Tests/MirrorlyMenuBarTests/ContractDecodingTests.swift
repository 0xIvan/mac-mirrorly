import Foundation
import AppKit
import SwiftUI
import XCTest
@testable import MirrorlyMenuBar

final class ContractDecodingTests: XCTestCase {
    @MainActor
    func testNativePositionsScrollerIsDisabled() throws {
        var metrics = PositionScrollMetrics()
        let content = ScrollView {
            VStack {
                ForEach(0..<30, id: \.self) { index in Text("Position \(index)") }
            }
            .background(NativeScrollerHider { metrics = $0 }.frame(width: 0, height: 0))
        }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 250, height: 120), styleMask: [], backing: .buffered, defer: false)
        window.contentView = NSHostingView(rootView: content)
        window.contentView?.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))

        func scrollView(in view: NSView) -> NSScrollView? {
            if let scrollView = view as? NSScrollView { return scrollView }
            return view.subviews.lazy.compactMap(scrollView(in:)).first
        }
        let nativeScrollView = try XCTUnwrap(window.contentView.flatMap(scrollView(in:)))
        func hiderView(in view: NSView) -> NativeScrollerHiderView? {
            if let hider = view as? NativeScrollerHiderView { return hider }
            return view.subviews.lazy.compactMap(hiderView(in:)).first
        }
        let hider = try XCTUnwrap(window.contentView.flatMap(hiderView(in:)))
        XCTAssertNotNil(hider.enclosingScrollView)
        XCTAssertFalse(nativeScrollView.hasVerticalScroller)
        nativeScrollView.hasVerticalScroller = true
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        XCTAssertFalse(nativeScrollView.hasVerticalScroller)
        XCTAssertGreaterThan(metrics.height, metrics.viewportHeight)
        XCTAssertGreaterThan(metrics.viewportHeight, 0)
        nativeScrollView.contentView.scroll(to: NSPoint(x: 0, y: 100))
        nativeScrollView.reflectScrolledClipView(nativeScrollView.contentView)
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        XCTAssertGreaterThan(metrics.offset, 0)
    }

    func testMoneyUsesDollarSymbol() {
        let value = Money.whole(1234)
        XCTAssertTrue(value.hasPrefix("$"))
        XCTAssertFalse(value.contains("US$"))
        XCTAssertFalse(value.dropFirst().first?.isWhitespace ?? false)
        XCTAssertNotNil(Money.twoDecimals(12.5).range(of: #"^\$12[.,]50$"#, options: .regularExpression))
    }

    func testAccountPnLStatisticsUsesPortal24HourValue() throws {
        let data = Data(#"{"totalPnL24H":123.45,"totalPnL7D":456.78,"totalPnL30D":789.01}"#.utf8)
        let statistics = try JSONDecoder().decode(AccountPnLStatistics.self, from: data)

        XCTAssertEqual(statistics.totalPnL24H, Decimal(string: "123.45"))
    }

    func testCopytraderSummaryAndActiveAlarms() throws {
        let data = Data(#"{"copytraders":[{"copytraderId":"20f18ec3-36e9-4e90-9bb7-5b15a3744f58","name":"Atlas","mode":"reduceOnly","equity":24800.5,"unrealizedPnL":345.25,"exchangeRef":"Hyperliquid","alarms":[{"status":"Active","message":"Exchange connection warning","type":"connection"},{"status":"Resolved","message":"Old warning","type":"connection"}]}]}"#.utf8)

        let list = try JSONDecoder().decode(CopytraderList.self, from: data)
        let copytrader = try XCTUnwrap(list.copytraders?.first)

        XCTAssertEqual(copytrader.displayMode, "Reduce only")
        XCTAssertEqual(copytrader.equity, Decimal(string: "24800.5"))
        XCTAssertEqual(copytrader.activeAlarms.count, 1)
        XCTAssertEqual(copytrader.activeAlarms.first?.displayMessage, "Exchange connection warning")
    }

    func testOpenPositionsIncludePendingCopiesAndFollowedTraders() throws {
        let data = Data(#"{"meta":{"equity":10000,"leverage":1.2,"totalSize":11600,"totalUnrealizedPnl":345},"data":[{"copy":{"symbol":"BTC","isLong":true,"size":8400,"unrealizedPnl":420,"status":"open"},"trader":{"name":"Northstar","symbol":"BTC"}},{"copy":{"symbol":"ETH","isLong":false,"size":3200,"unrealizedPnl":-75,"status":"waitingForSizeToOpen"},"trader":{"name":"Helix","symbol":"ETH"}},{"trader":{"name":"Leader only","symbol":"SOL","isLong":false,"size":1000,"unrealizedPnl":50}}]}"#.utf8)

        let response = try JSONDecoder().decode(OpenPositionsResponse.self, from: data)

        XCTAssertEqual(response.data.count, 3)
        XCTAssertEqual(response.meta.totalSize, 11600)
        XCTAssertEqual(response.meta.totalUnrealizedPnl, 345)
        XCTAssertEqual(response.meta.equity, 10000)
        XCTAssertNil(response.data[0].statusLabel)
        XCTAssertEqual(response.data[1].statusLabel, "Waiting to open")
        XCTAssertNil(response.data[2].statusLabel)
        XCTAssertEqual(response.data.filter(\.isCopied).count, 2)
        XCTAssertEqual(response.data[0].copy?.size, 8400)
        XCTAssertEqual(response.data[0].copy?.unrealizedPnl, 420)

        let totals = PositionTotals(metas: [
            response.meta,
            OpenPositionsMeta(equity: 5000, leverage: 2, totalSize: 10000, totalUnrealizedPnl: -100)
        ])
        XCTAssertEqual(totals.notional, 21600)
        XCTAssertEqual(totals.unrealizedPnL, 245)
        XCTAssertEqual(totals.leverage, Decimal(string: "1.44"))
        XCTAssertNotNil(Money.leverage(totals.leverage).range(of: #"^1[.,]4×$"#, options: .regularExpression))
    }
}
