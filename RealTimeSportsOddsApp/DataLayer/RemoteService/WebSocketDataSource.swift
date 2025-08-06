//
//  MockMatchDataSource.swift
//  RealTimeSportsOddsApp
//
//  Created by Chung Han Hsin on 2025/8/3.
//

import Foundation

class WebSocketDataSource: WebSocketDataSourceProtocol {
    
    private let matchCount: Int
    private lazy var dateFormatter = makeDateFormatter()
    
    init(matchCount: Int = 100) {
        self.matchCount = matchCount
        print("🌐 模擬真實 WebSocket DataSource 初始化：\(matchCount) 筆比賽")
    }
    
    func fetchMatches() async throws -> [Match] {
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 秒
        
        let matches = MockData.getMatches(count: matchCount)
        print("📊 Mock API: 獲取比賽列表 (\(matches.count) 筆資料)")
        return matches
    }
    
    func fetchOdds() async throws -> [Odds] {
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 秒
        
        let baseOdds = MockData.getOdds(count: matchCount)
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
    
    // 🚀 關鍵：模擬真實 WebSocket 每秒推送 10 筆更新
    func observeOddsUpdates() -> AsyncStream<Odds> {
        print("🌐 模擬真實 WebSocket: 每秒推送 10 筆賠率更新")
        
        return AsyncStream { continuation in
            let task = Task {
                var updateCount = 0
                var secondCounter = 0
                
                while !Task.isCancelled {
                    let startTime = Date()
                    
                    // 🎯 每秒推送 10 筆更新
                    for i in 0..<10 {
                        guard !Task.isCancelled else { break }
                        
                        let odds = MockData.getRandomOddsUpdate()
                        continuation.yield(odds)
                        updateCount += 1
                        
                        // 在一秒內平均分配 10 筆更新 (每 100ms 一筆)
                        if i < 9 { // 最後一筆不需要等待
                            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
                        }
                    }
                    
                    secondCounter += 1
                    let elapsedTime = Date().timeIntervalSince(startTime)
                    
                    // 確保整個循環接近 1 秒
                    let remainingTime = 1.0 - elapsedTime
                    if remainingTime > 0 {
                        try? await Task.sleep(nanoseconds: UInt64(remainingTime * 1_000_000_000))
                    }
                    
                    // 每 10 秒記錄一次統計
                    if secondCounter % 10 == 0 {
                        let actualRate = Double(updateCount) / Double(secondCounter)
                        print("📊 WebSocket 統計: 已運行 \(secondCounter) 秒，總更新 \(updateCount) 筆，實際速率: \(String(format: "%.1f", actualRate)) 筆/秒")
                    }
                }
                
                print("🛑 WebSocket 模擬停止")
                continuation.finish()
            }
            
            continuation.onTermination = { _ in
                print("🔌 WebSocket 連線終止")
                task.cancel()
            }
        }
    }
}

private extension WebSocketDataSource {
    private func makeDateFormatter() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }
}
