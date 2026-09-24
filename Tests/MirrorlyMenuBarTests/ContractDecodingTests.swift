import Foundation
import XCTest
@testable import MirrorlyMenuBar

final class ContractDecodingTests: XCTestCase {
    func testCopytraderSummaryAndActiveAlarms() throws {
        let data = Data(#"{"copytraders":[{"copytraderId":"20f18ec3-36e9-4e90-9bb7-5b15a3744f58","name":"Atlas","mode":"reduceOnly","equity":24800.5,"unrealizedPnL":345.25,"exchangeRef":"Hyperliquid","alarms":[{"status":"Active","message":"Exchange connection warning","type":"connection"},{"status":"Resolved","message":"Old warning","type":"connection"}]}]}"#.utf8)

        let list = try JSONDecoder().decode(CopytraderList.self, from: data)
        let copytrader = try XCTUnwrap(list.copytraders?.first)

        XCTAssertEqual(copytrader.displayMode, "Reduce only")
        XCTAssertEqual(copytrader.equity, Decimal(string: "24800.5"))
        XCTAssertEqual(copytrader.activeAlarms.count, 1)
        XCTAssertEqual(copytrader.activeAlarms.first?.displayMessage, "Exchange connection warning")
    }

    func testOnlyCopiedOpenPositionIsShown() throws {
        let data = Data(#"{"data":[{"copy":{"symbol":"BTC","isLong":true,"size":8400,"unrealizedPnl":420,"status":"open"},"trader":{"name":"Northstar","symbol":"BTC"}},{"copy":{"symbol":"ETH","isLong":false,"size":3200,"unrealizedPnl":-75,"status":"waitingForSizeToOpen"},"trader":{"name":"Helix","symbol":"ETH"}},{"trader":{"name":"Leader only","symbol":"SOL"}}]}"#.utf8)

        let response = try JSONDecoder().decode(OpenPositionsResponse.self, from: data)
        let openCopies = response.data.filter(\.isOpenCopy)

        XCTAssertEqual(openCopies.count, 1)
        XCTAssertEqual(openCopies.first?.traderName, "Northstar")
        XCTAssertEqual(openCopies.first?.copy?.size, 8400)
    }
}
