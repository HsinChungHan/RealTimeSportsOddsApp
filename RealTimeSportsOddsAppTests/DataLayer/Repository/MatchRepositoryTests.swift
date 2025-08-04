//
//  MatchRepositoryTests.swift
//  RealTimeSportsOddsAppTests
//
//  Created by Chung Han Hsin on 2025/8/4.
//

import XCTest
@testable import RealTimeSportsOddsApp

final class MatchRepositoryTests: XCTestCase {
    final class MockCacheService: CacheServiceProtocol {
        var storage: [String: Any] = [:]
        
        func get<T: Codable>(key: String) -> T? {
            return storage[key] as? T
        }

        func set<T: Codable>(key: String, value: T, expiry: TimeInterval) {
            storage[key] = value
        }

        func remove(key: String) {
            storage.removeValue(forKey: key)
        }

        func clear() {
            storage.removeAll()
        }
    }

    final class MockDataSource: MatchDataSourceProtocol {
        var fetchMatchesCalled = false
        var fetchOddsCalled = false
        
        var matchesToReturn: [Match] = []
        var oddsToReturn: [Odds] = []

        func fetchMatches() async throws -> [Match] {
            fetchMatchesCalled = true
            return matchesToReturn
        }

        func fetchOdds() async throws -> [Odds] {
            fetchOddsCalled = true
            return oddsToReturn
        }

        func observeOddsUpdates() -> AsyncStream<Odds> {
            AsyncStream { continuation in
                continuation.yield(Odds(matchID: 1, teamAOdds: 1.5, teamBOdds: 2.0))
                continuation.finish()
            }
        }
    }

    var repository: MatchRepository!
    var cache: MockCacheService!
    var dataSource: MockDataSource!

    override func setUp() {
        super.setUp()
        cache = MockCacheService()
        dataSource = MockDataSource()
        repository = MatchRepository(dataSource: dataSource, cacheService: cache)
    }

    // MARK: - 測試 getMatches()

    func test_GetMatches_UsesCacheIfAvailable() async throws {
        let cachedMatches = [Match(matchID: 1, teamA: "A", teamB: "B", startTime: Date())]
        cache.storage["matches"] = cachedMatches

        let result = try await repository.getMatches()

        XCTAssertEqual(result, cachedMatches)
        XCTAssertFalse(dataSource.fetchMatchesCalled)
    }

    func test_GetMatches_FetchesFromDataSourceAndCaches() async throws {
        let newMatches = [Match(matchID: 2, teamA: "C", teamB: "D", startTime: Date())]
        dataSource.matchesToReturn = newMatches

        let result = try await repository.getMatches()

        XCTAssertEqual(result, newMatches)
        XCTAssertTrue(dataSource.fetchMatchesCalled)

        let cached: [Match]? = cache.get(key: "matches")
        XCTAssertEqual(cached, newMatches)
    }

    // MARK: - 測試 getOdds()

    func test_GetOdds_UsesCacheIfAvailable() async throws {
        let cachedOdds = [Odds(matchID: 1, teamAOdds: 1.8, teamBOdds: 2.1)]
        cache.storage["odds"] = cachedOdds

        let result = try await repository.getOdds()

        XCTAssertEqual(result, cachedOdds)
        XCTAssertFalse(dataSource.fetchOddsCalled)
    }

    func test_GetOdds_FetchesFromDataSourceAndCaches() async throws {
        let newOdds = [Odds(matchID: 2, teamAOdds: 2.2, teamBOdds: 1.7)]
        dataSource.oddsToReturn = newOdds

        let result = try await repository.getOdds()

        XCTAssertEqual(result, newOdds)
        XCTAssertTrue(dataSource.fetchOddsCalled)

        let cached: [Odds]? = cache.get(key: "odds")
        XCTAssertEqual(cached, newOdds)
    }

    // MARK: - 測試 observeOddsUpdates()

    func test_ObserveOddsUpdates_PassesThrough() async throws {
        var received: [Odds] = []

        let stream = repository.observeOddsUpdates()

        for try await odds in stream {
            received.append(odds)
        }

        XCTAssertEqual(received.count, 1)
        XCTAssertEqual(received.first?.matchID, 1)
    }
}
