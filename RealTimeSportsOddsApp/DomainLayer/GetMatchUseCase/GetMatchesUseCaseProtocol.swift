//
//  GetMatchesUseCaseProtocol.swift
//  RealTimeSportsOddsApp
//
//  Created by Chung Han Hsin on 2025/8/3.
//

import Foundation
protocol GetMatchesUseCaseProtocol {
    // 獲取比賽資料
    func execute() async throws -> [Match]
}
