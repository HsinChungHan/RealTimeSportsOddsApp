//
//  Odds.swift
//  RealTimeSportsOddsApp
//
//  Created by Chung Han Hsin on 2025/8/3.
//

import Foundation

/*
 teamAOdds: 1.95 表示如果 A隊 獲勝，你下注 100 元可以獲得 195 元（含本金）
 teamBOdds: 2.10 表示如果 B隊 獲勝，你下注 100 元可以獲得 210 元（含本金
 */

struct Odds: Codable, Equatable {
    let matchID: Int
    let teamAOdds: Double // A隊獲勝的賠率
    let teamBOdds: Double // B隊獲勝的賠率
}
