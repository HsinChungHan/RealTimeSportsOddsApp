//
//  GetOddsUseCaseProtocol.swift
//  RealTimeSportsOddsApp
//
//  Created by Chung Han Hsin on 2025/8/3.
//

import Foundation
protocol GetOddsUseCaseProtocol {
    // 獲取賠率資料
    func execute() async throws -> [Odds]
}
