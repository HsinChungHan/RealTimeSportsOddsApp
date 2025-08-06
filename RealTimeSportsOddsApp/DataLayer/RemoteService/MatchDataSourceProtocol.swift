//
//  MatchDataSourceProtocol.swift
//  RealTimeSportsOddsApp
//
//  Created by Chung Han Hsin on 2025/8/3.
//

import Foundation

// 獲取 API 資料
protocol WebSocketDataSourceProtocol {
    func fetchMatches() async throws -> [Match]
    func fetchOdds() async throws -> [Odds]
    func observeOddsUpdates() -> AsyncStream<Odds>
}
