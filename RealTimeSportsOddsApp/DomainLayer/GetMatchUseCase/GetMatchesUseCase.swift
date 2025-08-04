//
//  GetMatchesUseCase.swift
//  RealTimeSportsOddsApp
//
//  Created by Chung Han Hsin on 2025/8/3.
//

import Foundation
class GetMatchesUseCase: GetMatchesUseCaseProtocol {
    private let repository: MatchRepositoryProtocol
    
    init(repository: MatchRepositoryProtocol) {
        self.repository = repository
    }
    
    func execute() async throws -> [Match] {
        return try await repository.getMatches()
    }
}
