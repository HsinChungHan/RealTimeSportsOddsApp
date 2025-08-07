
//
//  BatchUpdateUseCaseTests.swift
//  RealTimeSportsOddsAppTests
//
//  Created by Chung Han Hsin on 2025/8/7.
//

import XCTest
@testable import RealTimeSportsOddsApp


final class BatchUpdateUseCaseTests: XCTestCase {
    
    // MARK: - Mock Repository
    final class MockMatchRepository: MatchRepositoryProtocol {
        
        private var oddsUpdatesContinuation: AsyncStream<Odds>.Continuation?
        private var oddsUpdatesStream: AsyncStream<Odds>?
        
        var shouldReturnEmptyStream = false
        var fetchMatchesCalled = false
        var fetchOddsCalled = false
        
        func getMatches() async throws -> [Match] {
            fetchMatchesCalled = true
            return [
                Match(matchID: 1, teamA: "TeamA", teamB: "TeamB", startTime: Date())
            ]
        }
        
        func getOdds() async throws -> [Odds] {
            fetchOddsCalled = true
            return [
                Odds(matchID: 1, teamAOdds: 1.5, teamBOdds: 2.0)
            ]
        }
        
        func observeOddsUpdates() -> AsyncStream<Odds> {
            if shouldReturnEmptyStream {
                return AsyncStream { $0.finish() }
            }
            
            let (stream, continuation) = AsyncStream<Odds>.makeStream()
            self.oddsUpdatesContinuation = continuation
            self.oddsUpdatesStream = stream
            return stream
        }
        
        // 測試用方法：發送模擬更新
        func sendOddsUpdate(_ odds: Odds) {
            oddsUpdatesContinuation?.yield(odds)
        }
        
        // 測試用方法：結束流
        func finishOddsStream() {
            oddsUpdatesContinuation?.finish()
            oddsUpdatesContinuation = nil
        }
        
        deinit {
            finishOddsStream()
        }
    }
    
    // MARK: - Properties
    var batchUpdateUseCase: BatchUpdateUseCase!
    var mockRepository: MockMatchRepository!
    var receivedBatchUpdates: [[Int: Odds]] = []
    
    // MARK: - Setup & Teardown
    override func setUp() async throws {
        try await super.setUp()
        mockRepository = MockMatchRepository()
        batchUpdateUseCase = BatchUpdateUseCase(repository: mockRepository)
        receivedBatchUpdates = []
        
        // 設置批次更新回調
        batchUpdateUseCase.setBatchUpdateCallback { [weak self] updates in
            self?.receivedBatchUpdates.append(updates)
        }
    }
    
    override func tearDown() async throws {
        await batchUpdateUseCase.stopBatchProcessing()
        batchUpdateUseCase = nil
        mockRepository = nil
        receivedBatchUpdates = []
        try await super.tearDown()
    }
    
    // MARK: - 基本功能測試
    
    @MainActor
    func test_StartBatchProcessing_ShouldBeginObservingUpdates() async throws {
        // Given
        batchUpdateUseCase.startBatchProcessing()
        let testOdds = Odds(matchID: 1, teamAOdds: 1.8, teamBOdds: 2.2)
        
        // When - 直接調用 handleOddsUpdate
        batchUpdateUseCase.handleOddsUpdate(testOdds)
        
        // Then
        try await Task.sleep(nanoseconds: 100_000_000)
        
        let stats = batchUpdateUseCase.statisticsInfo
        XCTAssertTrue(stats.contains("接收: 1"), "直接調用應該工作，實際: \(stats)")
        XCTAssertEqual(receivedBatchUpdates.count, 1, "應該收到 1 次批次更新")
        XCTAssertEqual(receivedBatchUpdates[0][1]?.matchID, 1)
        XCTAssertEqual(receivedBatchUpdates[0][1]?.teamAOdds, 1.8)
    }
    
    @MainActor
    func test_StopBatchProcessing_ShouldStopObservingUpdates() async throws {
        // Given
        batchUpdateUseCase.startBatchProcessing()
        
        let testOdds = Odds(matchID: 1, teamAOdds: 1.8, teamBOdds: 2.2)
        mockRepository.sendOddsUpdate(testOdds)
        
        try await Task.sleep(nanoseconds: 100_000_000)
        
        let statsBeforeStop = batchUpdateUseCase.statisticsInfo
        
        // When
        batchUpdateUseCase.stopBatchProcessing()
        
        // 嘗試發送更多更新
        mockRepository.sendOddsUpdate(Odds(matchID: 2, teamAOdds: 2.0, teamBOdds: 1.5))
        
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Then
        let statsAfterStop = batchUpdateUseCase.statisticsInfo
        XCTAssertEqual(statsBeforeStop, statsAfterStop, "停止後不應該接收更多更新")
    }
    
    @MainActor
    func test_HandleOddsUpdate_InIdleMode_ShouldProcessImmediately() async throws {
        // Given
        batchUpdateUseCase.startBatchProcessing()
        let testOdds = Odds(matchID: 1, teamAOdds: 1.8, teamBOdds: 2.2)
        
        // When (待機模式下)
        batchUpdateUseCase.handleOddsUpdate(testOdds)
        
        // Then
        try await Task.sleep(nanoseconds: 100_000_000)
        
        XCTAssertEqual(receivedBatchUpdates.count, 1, "應該立即處理 1 筆更新")
        XCTAssertEqual(receivedBatchUpdates[0][1]?.matchID, 1)
        XCTAssertEqual(receivedBatchUpdates[0][1]?.teamAOdds, 1.8)
    }
    
    @MainActor
    func test_HandleOddsUpdate_InScrollingMode_ShouldAccumulate() async throws {
        // Given
        batchUpdateUseCase.startBatchProcessing()
        batchUpdateUseCase.setScrolling(true)
        
        let testOdds1 = Odds(matchID: 1, teamAOdds: 1.8, teamBOdds: 2.2)
        let testOdds2 = Odds(matchID: 2, teamAOdds: 2.0, teamBOdds: 1.7)
        
        // When (滾動模式下)
        batchUpdateUseCase.handleOddsUpdate(testOdds1)
        batchUpdateUseCase.handleOddsUpdate(testOdds2)
        
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Then (滾動中不應該立即處理)
        XCTAssertEqual(receivedBatchUpdates.count, 0, "滾動中不應該立即處理更新")
        
        // 停止滾動
        batchUpdateUseCase.setScrolling(false)
        
        try await Task.sleep(nanoseconds: 200_000_000) // 等待處理
        
        // 應該批次處理累積的更新
        XCTAssertEqual(receivedBatchUpdates.count, 1, "停止滾動後應該批次處理")
        XCTAssertEqual(receivedBatchUpdates[0].count, 2, "應該包含 2 筆累積的更新")
    }
    
    // MARK: - 滾動狀態管理測試
    
    @MainActor
    func test_SetScrolling_ShouldUpdateScrollingState() async throws {
        // Given
        batchUpdateUseCase.startBatchProcessing()
        
        // When
        batchUpdateUseCase.setScrolling(true)
        
        let testOdds = Odds(matchID: 1, teamAOdds: 1.8, teamBOdds: 2.2)
        batchUpdateUseCase.handleOddsUpdate(testOdds)
        
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Then
        XCTAssertEqual(receivedBatchUpdates.count, 0, "滾動時不應該立即處理")
        
        // 停止滾動
        batchUpdateUseCase.setScrolling(false)
        try await Task.sleep(nanoseconds: 200_000_000)
        
        XCTAssertEqual(receivedBatchUpdates.count, 1, "停止滾動後應該處理累積更新")
    }
    
    @MainActor
    func test_SetScrolling_WithSameState_ShouldNotTriggerChange() async throws {
        // Given
        batchUpdateUseCase.startBatchProcessing()
        batchUpdateUseCase.setScrolling(true)
        
        let testOdds = Odds(matchID: 1, teamAOdds: 1.8, teamBOdds: 2.2)
        batchUpdateUseCase.handleOddsUpdate(testOdds)
        
        // When (重複設置相同狀態)
        batchUpdateUseCase.setScrolling(true)
        batchUpdateUseCase.setScrolling(true)
        
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Then
        XCTAssertEqual(receivedBatchUpdates.count, 0, "重複設置相同狀態不應該觸發處理")
    }
    
    // MARK: - 批次更新回調測試
    
    @MainActor
    func test_SetBatchUpdateCallback_ShouldReceiveUpdates() async throws {
        // Given
        var callbackReceived: [Int: Odds]?
        
        batchUpdateUseCase.setBatchUpdateCallback { updates in
            callbackReceived = updates
        }
        
        batchUpdateUseCase.startBatchProcessing()
        
        // When
        let testOdds = Odds(matchID: 1, teamAOdds: 1.8, teamBOdds: 2.2)
        batchUpdateUseCase.handleOddsUpdate(testOdds)
        
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Then
        XCTAssertNotNil(callbackReceived, "應該接收到回調")
        XCTAssertEqual(callbackReceived?[1]?.matchID, 1)
        XCTAssertEqual(callbackReceived?[1]?.teamAOdds, 1.8)
    }
    
    // MARK: - 統計信息測試
    
    @MainActor
    func test_StatisticsInfo_ShouldReflectCurrentState() async throws {
        // Given
        batchUpdateUseCase.startBatchProcessing()
        
        // Initial state
        var stats = batchUpdateUseCase.statisticsInfo
        XCTAssertTrue(stats.contains("接收: 0"), "初始狀態應該顯示 0 筆接收")
        
        // When
        let testOdds1 = Odds(matchID: 1, teamAOdds: 1.8, teamBOdds: 2.2)
        let testOdds2 = Odds(matchID: 2, teamAOdds: 2.0, teamBOdds: 1.7)
        
        batchUpdateUseCase.handleOddsUpdate(testOdds1)
        batchUpdateUseCase.handleOddsUpdate(testOdds2)
        
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Then
        stats = batchUpdateUseCase.statisticsInfo
        XCTAssertTrue(stats.contains("接收: 2"), "應該顯示接收 2 筆更新，實際: \(stats)")
        XCTAssertTrue(stats.contains("批次: 2"), "應該顯示處理 2 次批次，實際: \(stats)")
    }
    
    // MARK: - 複雜場景測試
    
    @MainActor
    func test_ComplexScrollingScenario_ShouldHandleCorrectly() async throws {
        // Given
        batchUpdateUseCase.startBatchProcessing()
        
        // 待機模式下處理一些更新
        let idleOdds1 = Odds(matchID: 1, teamAOdds: 1.5, teamBOdds: 2.0)
        let idleOdds2 = Odds(matchID: 2, teamAOdds: 1.7, teamBOdds: 1.9)
        
        batchUpdateUseCase.handleOddsUpdate(idleOdds1)
        batchUpdateUseCase.handleOddsUpdate(idleOdds2)
        
        try await Task.sleep(nanoseconds: 100_000_000)
        
        XCTAssertEqual(receivedBatchUpdates.count, 2, "待機模式應該立即處理每筆更新")
        
        // 開始滾動並累積更新
        batchUpdateUseCase.setScrolling(true)
        
        let scrollOdds1 = Odds(matchID: 3, teamAOdds: 2.1, teamBOdds: 1.6)
        let scrollOdds2 = Odds(matchID: 4, teamAOdds: 1.8, teamBOdds: 2.2)
        let scrollOdds3 = Odds(matchID: 5, teamAOdds: 1.9, teamBOdds: 2.0)
        
        batchUpdateUseCase.handleOddsUpdate(scrollOdds1)
        batchUpdateUseCase.handleOddsUpdate(scrollOdds2)
        batchUpdateUseCase.handleOddsUpdate(scrollOdds3)
        
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // 滾動中不應該有新的批次處理
        XCTAssertEqual(receivedBatchUpdates.count, 2, "滾動中不應該處理更新")
        
        // 停止滾動
        batchUpdateUseCase.setScrolling(false)
        
        try await Task.sleep(nanoseconds: 300_000_000) // 等待處理完成
        
        // 應該批次處理滾動期間累積的 3 筆更新
        XCTAssertEqual(receivedBatchUpdates.count, 3, "停止滾動後應該有新的批次處理")
        XCTAssertEqual(receivedBatchUpdates[2].count, 3, "最後一次批次應該包含 3 筆更新")
        
        // 驗證累積的更新內容
        let lastBatch = receivedBatchUpdates[2]
        XCTAssertEqual(lastBatch[3]?.teamAOdds, 2.1)
        XCTAssertEqual(lastBatch[4]?.teamAOdds, 1.8)
        XCTAssertEqual(lastBatch[5]?.teamAOdds, 1.9)
    }
    
    @MainActor
    func test_OverwritePendingUpdates_ShouldKeepLatest() async throws {
        // Given
        batchUpdateUseCase.startBatchProcessing()
        batchUpdateUseCase.setScrolling(true)
        
        // When (同一 matchID 的多次更新)
        let odds1 = Odds(matchID: 1, teamAOdds: 1.5, teamBOdds: 2.0)
        let odds2 = Odds(matchID: 1, teamAOdds: 1.8, teamBOdds: 2.2) // 覆蓋前一個
        let odds3 = Odds(matchID: 1, teamAOdds: 2.0, teamBOdds: 1.8) // 覆蓋前兩個
        
        batchUpdateUseCase.handleOddsUpdate(odds1)
        batchUpdateUseCase.handleOddsUpdate(odds2)
        batchUpdateUseCase.handleOddsUpdate(odds3)
        
        // 停止滾動以觸發批次處理
        batchUpdateUseCase.setScrolling(false)
        
        try await Task.sleep(nanoseconds: 200_000_000)
        
        // Then
        XCTAssertEqual(receivedBatchUpdates.count, 1, "應該有一次批次處理")
        XCTAssertEqual(receivedBatchUpdates[0].count, 1, "應該只有一筆更新（最新的）")
        XCTAssertEqual(receivedBatchUpdates[0][1]?.teamAOdds, 2.0, "應該保留最新的賠率")
        XCTAssertEqual(receivedBatchUpdates[0][1]?.teamBOdds, 1.8, "應該保留最新的賠率")
    }
    
    // MARK: - 錯誤處理測試
    
    @MainActor
    func test_HandleOddsUpdate_WhenNotProcessing_ShouldIgnore() async throws {
        // Given (未啟動處理)
        let testOdds = Odds(matchID: 1, teamAOdds: 1.8, teamBOdds: 2.2)
        
        // When
        batchUpdateUseCase.handleOddsUpdate(testOdds)
        
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Then
        XCTAssertEqual(receivedBatchUpdates.count, 0, "未啟動處理時應該忽略更新")
        
        let stats = batchUpdateUseCase.statisticsInfo
        XCTAssertTrue(stats.contains("接收: 0"), "統計應該顯示 0 筆接收")
    }
    
    @MainActor
    func test_StartBatchProcessing_WhenAlreadyProcessing_ShouldNotRestart() async throws {
        // Given
        batchUpdateUseCase.startBatchProcessing()
        
        let testOdds = Odds(matchID: 1, teamAOdds: 1.8, teamBOdds: 2.2)
        batchUpdateUseCase.handleOddsUpdate(testOdds)
        
        try await Task.sleep(nanoseconds: 100_000_000)
        
        let initialStats = batchUpdateUseCase.statisticsInfo
        
        // When (重複啟動)
        batchUpdateUseCase.startBatchProcessing()
        
        // Then
        let finalStats = batchUpdateUseCase.statisticsInfo
        XCTAssertEqual(initialStats, finalStats, "重複啟動不應該重置統計")
    }
    
    // MARK: - 性能測試
    
    @MainActor
    func test_HighFrequencyUpdates_ShouldNotCrash() async throws {
        // Given
        batchUpdateUseCase.startBatchProcessing()
        
        // When (高頻率更新)
        for i in 1...100 {
            let odds = Odds(matchID: i, teamAOdds: Double(i) * 0.1 + 1.0, teamBOdds: 3.0 - Double(i) * 0.01)
            batchUpdateUseCase.handleOddsUpdate(odds)
        }
        
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 秒
        
        // Then
        let stats = batchUpdateUseCase.statisticsInfo
        XCTAssertTrue(stats.contains("接收: 100"), "應該接收到 100 筆更新，實際: \(stats)")
        XCTAssertGreaterThan(receivedBatchUpdates.count, 0, "應該有批次處理發生")
        
        // 驗證不會崩潰且有合理的性能
        let totalUpdatesProcessed = receivedBatchUpdates.reduce(0) { $0 + $1.count }
        XCTAssertEqual(totalUpdatesProcessed, 100, "總處理數量應該等於發送數量")
    }
    
    @MainActor
    func test_MixedScrollingAndIdleUpdates_ShouldHandleCorrectly() async throws {
        // Given
        batchUpdateUseCase.startBatchProcessing()
        
        // 待機模式
        batchUpdateUseCase.handleOddsUpdate(Odds(matchID: 1, teamAOdds: 1.5, teamBOdds: 2.0))
        try await Task.sleep(nanoseconds: 50_000_000)
        
        // 滾動模式
        batchUpdateUseCase.setScrolling(true)
        batchUpdateUseCase.handleOddsUpdate(Odds(matchID: 2, teamAOdds: 1.7, teamBOdds: 1.9))
        batchUpdateUseCase.handleOddsUpdate(Odds(matchID: 3, teamAOdds: 2.0, teamBOdds: 1.8))
        try await Task.sleep(nanoseconds: 50_000_000)
        
        // 回到待機模式
        batchUpdateUseCase.setScrolling(false)
        try await Task.sleep(nanoseconds: 200_000_000)
        
        batchUpdateUseCase.handleOddsUpdate(Odds(matchID: 4, teamAOdds: 1.6, teamBOdds: 2.1))
        try await Task.sleep(nanoseconds: 50_000_000)
        
        // Then
        XCTAssertGreaterThanOrEqual(receivedBatchUpdates.count, 3, "應該有至少 3 次批次處理")
        
        let totalUpdates = receivedBatchUpdates.reduce(0) { $0 + $1.count }
        XCTAssertEqual(totalUpdates, 4, "總計應該處理 4 筆更新")
        
        let stats = batchUpdateUseCase.statisticsInfo
        XCTAssertTrue(stats.contains("接收: 4"), "應該接收 4 筆更新")
    }
}

// MARK: - AsyncStream Extension
extension AsyncStream {
    static func makeStream() -> (AsyncStream<Element>, AsyncStream<Element>.Continuation) {
        var continuation: AsyncStream<Element>.Continuation!
        let stream = AsyncStream<Element> { cont in
            continuation = cont
        }
        return (stream, continuation)
    }
}
