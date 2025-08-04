//
//  ObserveOddsUpdatesUseCaseTests.swift
//  RealTimeSportsOddsAppTests
//
//  Created by Chung Han Hsin on 2025/8/4.
//

import XCTest
@testable import RealTimeSportsOddsApp

final class ObserveOddsUpdatesUseCaseTests: XCTestCase {
    
    // MARK: - Mock Repository
    final class MockMatchRepository: MatchRepositoryProtocol {
        var oddsToEmit: [Odds] = []

        func getMatches() async throws -> [Match] {
            return []
        }

        func getOdds() async throws -> [Odds] {
            return []
        }

        func observeOddsUpdates() -> AsyncStream<Odds> {
            AsyncStream { continuation in
                for odds in oddsToEmit {
                    continuation.yield(odds)
                }
                continuation.finish()
            }
        }
    }

    // MARK: - Properties
    var useCase: ObserveOddsUpdatesUseCase!
    var mockRepository: MockMatchRepository!

    override func setUp() {
        super.setUp()
        mockRepository = MockMatchRepository()
        useCase = ObserveOddsUpdatesUseCase(repository: mockRepository)
    }

    override func tearDown() {
        useCase = nil
        mockRepository = nil
        super.tearDown()
    }

    // MARK: - 測試流回傳
    func testExecuteReturnsStreamedOddsFromRepository() async {
        let expectedOdds = [
            Odds(matchID: 1, teamAOdds: 1.9, teamBOdds: 2.0),
            Odds(matchID: 2, teamAOdds: 2.1, teamBOdds: 1.8),
            Odds(matchID: 3, teamAOdds: 1.85, teamBOdds: 2.15)
        ]
        mockRepository.oddsToEmit = expectedOdds

        var received: [Odds] = []

        let stream = useCase.execute()

        for await odds in stream {
            received.append(odds)
        }

        XCTAssertEqual(received, expectedOdds)
    }
}

