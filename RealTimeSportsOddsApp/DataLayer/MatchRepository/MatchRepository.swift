//
//  MatchRepository.swift
//  RealTimeSportsOddsApp
//
//  Created by Chung Han Hsin on 2025/8/3.
//

import Foundation

class MatchRepository: MatchRepositoryProtocol {
    private let dataSource: MatchDataSourceProtocol
    private let cacheService: CacheServiceProtocol
    
    init(dataSource: MatchDataSourceProtocol, cacheService: CacheServiceProtocol) {
        self.dataSource = dataSource
        self.cacheService = cacheService
    }
    
    func getMatches() async throws -> [Match] {
        // Try cache first
        if let cachedMatches: [Match] = cacheService.get(key: "matches") {
            return cachedMatches
        }
        
        let matches = try await dataSource.fetchMatches()
        cacheService.set(key: "matches", value: matches, expiry: 300) // 5 minutes
        return matches
    }
    
    func getOdds() async throws -> [Odds] {
        if let cachedOdds: [Odds] = cacheService.get(key: "odds") {
            return cachedOdds
        }
        
        let odds = try await dataSource.fetchOdds()
        cacheService.set(key: "odds", value: odds, expiry: 60) // 1 minute
        return odds
    }
    
    func observeOddsUpdates() -> AsyncStream<Odds> {
        return dataSource.observeOddsUpdates()
    }
}
