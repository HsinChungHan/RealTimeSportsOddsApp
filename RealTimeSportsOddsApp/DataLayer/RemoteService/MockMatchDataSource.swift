//
//  MockMatchDataSource.swift
//  RealTimeSportsOddsApp
//
//  Created by Chung Han Hsin on 2025/8/3.
//

import Foundation

// Can move to an independant Swift Package
class MockMatchDataSource: MatchDataSourceProtocol {
    private lazy var dateFormatter = makeDateFormatter()
    
    // 🎯 模擬 GET /matches
    func fetchMatches() async throws -> [Match] {
        // 模擬網路延遲
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 秒
        
        print("📊 Mock API: 獲取比賽列表 (\(MockData.matches.count) 筆資料)")
        return MockData.matches
    }
    
    // 🎯 模擬 GET /odds
    func fetchOdds() async throws -> [Odds] {
        // 模擬網路延遲
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 秒
        
        // 模擬初始賠率，稍微變化一下
        let odds = MockData.initialOdds.map { initialOdds in
            Odds(
                matchID: initialOdds.matchID,
                teamAOdds: initialOdds.teamAOdds + Double.random(in: -0.1...0.1),
                teamBOdds: initialOdds.teamBOdds + Double.random(in: -0.1...0.1)
            )
        }
        
        print("📊 Mock API: 獲取賠率資料 (\(odds.count) 筆資料)")
        return odds
    }
    
    // 🎯 模擬 WebSocket 即時推播
    func observeOddsUpdates() -> AsyncStream<Odds> {
        print("🔄 Mock WebSocket: 開始監聽賠率更新")
        
        return AsyncStream { continuation in
            // 使用 Task 替代 Timer 解決 Sendable 問題
            // Use Task beacuse Task is Sendable, rather then caputure timer(it's not Sendable)
            // Sendable: it means this type can pass in the concurrency environment
            let task = Task {
                var updateCount = 0
                
                while !Task.isCancelled {
                    // 每 0.1 秒檢查一次 (每秒 10 次機會)
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    
                    guard !Task.isCancelled else { break }
                    
                    // 隨機產生 1-10 筆更新
                    let updatesCount = Int.random(in: 1...10)
                    
                    for _ in 0..<updatesCount {
                        let randomMatchID = MockData.matches.randomElement()?.matchID ?? 1001
                        
                        // 基於初始賠率產生較真實的變化
                        let baseOdds = MockData.initialOdds.first { $0.matchID == randomMatchID }
                        let teamABase = baseOdds?.teamAOdds ?? 2.0
                        let teamBBase = baseOdds?.teamBOdds ?? 2.0
                        
                        let odds = Odds(
                            matchID: randomMatchID,
                            teamAOdds: max(1.1, teamABase + Double.random(in: -0.3...0.3)),
                            teamBOdds: max(1.1, teamBBase + Double.random(in: -0.3...0.3))
                        )
                        
                        continuation.yield(odds)
                        updateCount += 1
                        
                        // 每 100 次更新記錄一次
                        if updateCount % 100 == 0 {
                            print("⚡ Mock WebSocket: 已推播 \(updateCount) 次賠率更新")
                        }
                    }
                }
                
                print("🛑 Mock WebSocket: 停止推播")
                continuation.finish()
            }
            
            continuation.onTermination = { _ in
                print("🔌 Mock WebSocket: 連線終止")
                task.cancel()
            }
        }
    }
}

private extension MockMatchDataSource {
    private func makeDateFormatter() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }
}
