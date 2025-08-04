//
//  ObserveOddsUpdatesUseCaseProtocol.swift
//  RealTimeSportsOddsApp
//
//  Created by Chung Han Hsin on 2025/8/3.
//

import Foundation
protocol ObserveOddsUpdatesUseCaseProtocol {
    // 處理即時賠率更新
    func execute() -> AsyncStream<Odds>
}
