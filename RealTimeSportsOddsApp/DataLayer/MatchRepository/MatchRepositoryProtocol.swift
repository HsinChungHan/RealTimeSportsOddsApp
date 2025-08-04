//
//  MatchRepositoryProtocol.swift
//  RealTimeSportsOddsApp
//
//  Created by Chung Han Hsin on 2025/8/3.
//

import Foundation
protocol MatchRepositoryProtocol {
    func getMatches() async throws -> [Match]
    func getOdds() async throws -> [Odds]
    func observeOddsUpdates() -> AsyncStream<Odds>
}
