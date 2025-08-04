//
//  GetOddsUseCase.swift
//  RealTimeSportsOddsApp
//
//  Created by Chung Han Hsin on 2025/8/3.
//

import Foundation
class GetOddsUseCase: GetOddsUseCaseProtocol {
    private let repository: MatchRepositoryProtocol
    
    init(repository: MatchRepositoryProtocol) {
        self.repository = repository
    }
    
    func execute() async throws -> [Odds] {
        return try await repository.getOdds()
    }
}
