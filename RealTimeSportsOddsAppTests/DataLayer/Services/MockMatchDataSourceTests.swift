//
//  MockMatchDataSourceTests.swift
//  RealTimeSportsOddsApp
//
//  Created by Chung Han Hsin on 2025/8/4.
//

import XCTest
@testable import RealTimeSportsOddsApp

final class MockMatchDataSourceTests: XCTestCase {
    var dataSource: MockMatchDataSource!

    override func setUp() {
        super.setUp()
        dataSource = MockMatchDataSource()
    }

    override func tearDown() {
        dataSource = nil
        super.tearDown()
    }

    // 🎯 測試 fetchMatches()
    func test_FetchMatches_ReturnsMockData() async throws {
        let matches = try await dataSource.fetchMatches()
        XCTAssertEqual(matches.count, MockData.matches.count)
        XCTAssertEqual(matches.first?.teamA, "Eagles")
    }

    // 🎯 測試 fetchOdds()
    func test_FetchOdds_ReturnsModifiedOdds() async throws {
        let odds = try await dataSource.fetchOdds()
        XCTAssertEqual(odds.count, MockData.initialOdds.count)
        
        let original = MockData.initialOdds[0]
        let modified = odds.first(where: { $0.matchID == original.matchID })
        XCTAssertNotNil(modified)
        XCTAssertNotEqual(modified!.teamAOdds, original.teamAOdds, accuracy: 0.0)
    }

    // 🎯 測試 observeOddsUpdates()
    func test_ObserveOddsUpdates_YieldsValues() async throws {
        let expectation = XCTestExpectation(description: "Receive odds updates")
        expectation.expectedFulfillmentCount = 3

        let stream = dataSource.observeOddsUpdates()

        let task = Task {
            var localCount = 0
            for await odds in stream {
                print("🔄 收到賠率更新：\(odds)")
                expectation.fulfill()
                localCount += 1
                if localCount >= 3 {
                    break
                }
            }
        }

        // 等待 expectation 被 fulfill 至少 3 次
        await fulfillment(of: [expectation], timeout: 3.0)

        // 為保險，測試結束後取消背景 stream
        task.cancel()
    }

}
