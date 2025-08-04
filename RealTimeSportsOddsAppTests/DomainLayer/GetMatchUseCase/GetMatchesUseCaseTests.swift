//
//  GetMatchesUseCaseTests.swift
//  RealTimeSportsOddsAppTests
//
//  Created by Chung Han Hsin on 2025/8/4.
//

import XCTest
@testable import RealTimeSportsOddsApp

final class GetMatchesUseCaseTests: XCTestCase {
    
    // MARK: - Mock Repository
    final class MockMatchRepository: MatchRepositoryProtocol {
        var shouldThrowError = false
        var matchesToReturn: [Match] = []

        func getMatches() async throws -> [Match] {
            if shouldThrowError {
                throw NSError(domain: "TestError", code: 1, userInfo: nil)
            }
            return matchesToReturn
        }

        func getOdds() async throws -> [Odds] {
            return []
        }

        func observeOddsUpdates() -> AsyncStream<Odds> {
            AsyncStream { $0.finish() }
        }
    }
    
    // MARK: - Properties
    var useCase: GetMatchesUseCase!
    var mockRepository: MockMatchRepository!

    override func setUp() {
        super.setUp()
        mockRepository = MockMatchRepository()
        useCase = GetMatchesUseCase(repository: mockRepository)
    }

    override func tearDown() {
        useCase = nil
        mockRepository = nil
        super.tearDown()
    }

    // MARK: - Tests

    func testExecuteReturnsMatchesFromRepository() async throws {
        let expectedMatches = [
            Match(matchID: 1, teamA: "Alpha", teamB: "Beta", startTime: Date())
        ]
        mockRepository.matchesToReturn = expectedMatches

        let result = try await useCase.execute()

        XCTAssertEqual(result, expectedMatches)
    }

    func testExecuteThrowsErrorWhenRepositoryFails() async {
        mockRepository.shouldThrowError = true

        do {
            _ = try await useCase.execute()
            XCTFail("Expected error but got success")
        } catch let error as NSError {
            XCTAssertEqual(error.domain, "TestError")
            XCTAssertEqual(error.code, 1)
        }
    }

}
