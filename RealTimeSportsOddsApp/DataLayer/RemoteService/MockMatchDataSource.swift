//
//  MockMatchDataSource.swift
//  RealTimeSportsOddsApp
//
//  Created by Chung Han Hsin on 2025/8/3.
//

import Foundation

class MockMatchDataSource: MatchDataSourceProtocol {
    
    // 🎯 可配置參數
    private let matchCount: Int
    private let updateInterval: TimeInterval
    private let maxUpdatesPerBatch: Int
    
    private lazy var dateFormatter = makeDateFormatter()
    
    // MARK: - 初始化
    init(
        matchCount: Int = 100,              // 比賽數量
        updateInterval: TimeInterval = 0.5,  // 更新間隔 (秒)
        maxUpdatesPerBatch: Int = 3         // 每次最多更新筆數
    ) {
        self.matchCount = matchCount
        self.updateInterval = updateInterval
        self.maxUpdatesPerBatch = maxUpdatesPerBatch
        
        print("🚀 Mock DataSource 初始化：\(matchCount) 筆比賽，每 \(updateInterval) 秒更新 1-\(maxUpdatesPerBatch) 筆賠率")
    }
    
    // MARK: - MatchDataSourceProtocol
    
    func fetchMatches() async throws -> [Match] {
        // 模擬網路延遲
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 秒
        
        let matches = MockData.getMatches(count: matchCount)
        print("📊 Mock API: 獲取比賽列表 (\(matches.count) 筆資料)")
        return matches
    }
    
    func fetchOdds() async throws -> [Odds] {
        // 模擬網路延遲
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 秒
        
        let baseOdds = MockData.getOdds(count: matchCount)
        
        // 稍微變化初始賠率
        let odds = baseOdds.map { initialOdds in
            Odds(
                matchID: initialOdds.matchID,
                teamAOdds: max(1.1, initialOdds.teamAOdds + Double.random(in: -0.1...0.1)),
                teamBOdds: max(1.1, initialOdds.teamBOdds + Double.random(in: -0.1...0.1))
            )
        }
        
        print("📊 Mock API: 獲取賠率資料 (\(odds.count) 筆資料)")
        return odds
    }
    
    func observeOddsUpdates() -> AsyncStream<Odds> {
        print("🔄 Mock WebSocket: 開始監聽賠率更新")
        print("⚙️ 配置：每 \(updateInterval) 秒，1-\(maxUpdatesPerBatch) 筆更新")
        
        return AsyncStream { continuation in
            let task = Task {
                var updateCount = 0
                
                while !Task.isCancelled {
                    // 根據配置的間隔時間等待
                    let nanoseconds = UInt64(updateInterval * 1_000_000_000)
                    try? await Task.sleep(nanoseconds: nanoseconds)
                    
                    guard !Task.isCancelled else { break }
                    
                    // 根據配置的最大更新數量隨機產生更新
                    let updatesCount = Int.random(in: 1...maxUpdatesPerBatch)
                    
                    for _ in 0..<updatesCount {
                        let odds = MockData.getRandomOddsUpdate()
                        continuation.yield(odds)
                        updateCount += 1
                    }
                    
                    // 每 50 次更新記錄一次
                    if updateCount % 50 == 0 {
                        print("⚡ Mock WebSocket: 已推播 \(updateCount) 次賠率更新")
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
