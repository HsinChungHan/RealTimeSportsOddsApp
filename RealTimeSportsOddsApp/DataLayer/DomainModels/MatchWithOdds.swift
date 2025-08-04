//
//  MatchWithOdds.swift
//  RealTimeSportsOddsApp
//
//  Created by Chung Han Hsin on 2025/8/3.
//

import Foundation
struct MatchWithOdds: Codable, Equatable {
    let match: Match
    var odds: Odds?
}
