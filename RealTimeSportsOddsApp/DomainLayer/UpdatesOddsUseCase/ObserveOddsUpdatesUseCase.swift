//
//  ObserveOddsUpdatesUseCase.swift
//  RealTimeSportsOddsApp
//
//  Created by Chung Han Hsin on 2025/8/3.
//

import Foundation
class ObserveOddsUpdatesUseCase: ObserveOddsUpdatesUseCaseProtocol {
    private let repository: MatchRepositoryProtocol
    
    init(repository: MatchRepositoryProtocol) {
        self.repository = repository
    }
    
    func execute() -> AsyncStream<Odds> {
        return repository.observeOddsUpdates()
    }
}
