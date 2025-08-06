//
//  MockMatchDataSourceTests.swift
//  RealTimeSportsOddsApp
//
//  Created by Chung Han Hsin on 2025/8/4.
//

import XCTest
@testable import RealTimeSportsOddsApp

final class MockMatchDataSourceTests: XCTestCase {
    var dataSource: WebSocketDataSource!

    override func setUp() {
        super.setUp()
        dataSource = WebSocketDataSource()
    }

    override func tearDown() {
        dataSource = nil
        super.tearDown()
    }

    // 🎯 測試 fetchMatches()
    func test_FetchMatches_ReturnsMockData() async throws {
        let matches = try await dataSource.fetchMatches()
        
        // 驗證資料筆數（預設 100 筆）
        XCTAssertEqual(matches.count, 100, "應該回傳 100 筆比賽資料")
        
        // 驗證每筆資料的基本結構
        for match in matches {
            XCTAssertTrue(match.matchID >= 1001, "Match ID 應該從 1001 開始")
            XCTAssertFalse(match.teamA.isEmpty, "隊伍 A 名稱不應為空")
            XCTAssertFalse(match.teamB.isEmpty, "隊伍 B 名稱不應為空")
            XCTAssertNotEqual(match.teamA, match.teamB, "兩隊名稱應該不同")
            XCTAssertGreaterThan(match.startTime, Date(), "比賽時間應該在未來")
        }
        
        // 驗證資料已按時間排序
        for i in 0..<(matches.count - 1) {
            XCTAssertLessThanOrEqual(
                matches[i].startTime,
                matches[i + 1].startTime,
                "比賽應該按開始時間升序排列"
            )
        }
        
        // 驗證 Match ID 的唯一性
        let matchIDs = Set(matches.map { $0.matchID })
        XCTAssertEqual(matchIDs.count, matches.count, "所有 Match ID 應該是唯一的")
        
        print("✅ fetchMatches 測試通過：\(matches.count) 筆資料")
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
