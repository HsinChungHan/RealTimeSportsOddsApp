//
//  Match.swift
//  RealTimeSportsOddsApp
//
//  Created by Chung Han Hsin on 2025/8/3.
//

import Foundation
struct Match: Codable, Equatable {
    let matchID: Int
    let teamA: String
    let teamB: String
    let startTime: Date
}
