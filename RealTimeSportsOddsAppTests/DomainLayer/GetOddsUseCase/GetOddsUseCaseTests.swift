//
//  GetOddsUseCaseTests.swift
//  RealTimeSportsOddsAppTests
//
//  Created by Chung Han Hsin on 2025/8/4.
//

import XCTest
@testable import RealTimeSportsOddsApp

final class GetOddsUseCaseTests: XCTestCase {
    
    // MARK: - Mock Repository
    final class MockMatchRepository: MatchRepositoryProtocol {
        var shouldThrowError = false
        var oddsToReturn: [Odds] = []

        func getOdds() async throws -> [Odds] {
            if shouldThrowError {
                throw NSError(domain: "TestError", code: 1001, userInfo: nil)
            }
            return oddsToReturn
        }

        func getMatches() async throws -> [Match] {
            return []
        }

        func observeOddsUpdates() -> AsyncStream<Odds> {
            AsyncStream { $0.finish() }
        }
    }

    // MARK: - Properties
    var useCase: GetOddsUseCase!
    var mockRepository: MockMatchRepository!

    override func setUp() {
        super.setUp()
        mockRepository = MockMatchRepository()
        useCase = GetOddsUseCase(repository: mockRepository)
    }

    override func tearDown() {
        useCase = nil
        mockRepository = nil
        super.tearDown()
    }

    // MARK: - 測試成功取得 Odds
    func testExecuteReturnsOddsFromRepository() async throws {
        let expectedOdds = [
            Odds(matchID: 1, teamAOdds: 1.85, teamBOdds: 2.10)
        ]
        mockRepository.oddsToReturn = expectedOdds

        let result = try await useCase.execute()

        XCTAssertEqual(result, expectedOdds)
    }

    // MARK: - 測試 Repository 拋錯時會正確 throw
    func testExecuteThrowsErrorWhenRepositoryFails() async {
        mockRepository.shouldThrowError = true

        do {
            _ = try await useCase.execute()
            XCTFail("Expected error but got success")
        } catch let error as NSError {
            XCTAssertEqual(error.domain, "TestError")
            XCTAssertEqual(error.code, 1001)
        }
    }
}
