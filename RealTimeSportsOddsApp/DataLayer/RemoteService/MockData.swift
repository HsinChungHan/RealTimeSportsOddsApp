//
//  MockData.swift
//  RealTimeSportsOddsApp
//
//  Created by Chung Han Hsin on 2025/8/3.
//

import Foundation
struct MockData {
    static let matches = [
        Match(matchID: 1001, teamA: "Eagles", teamB: "Tigers", startTime: Calendar.current.date(byAdding: .hour, value: 1, to: Date())!),
        Match(matchID: 1002, teamA: "Lions", teamB: "Bears", startTime: Calendar.current.date(byAdding: .hour, value: 2, to: Date())!),
        Match(matchID: 1003, teamA: "Wolves", teamB: "Sharks", startTime: Calendar.current.date(byAdding: .hour, value: 3, to: Date())!),
        Match(matchID: 1004, teamA: "Hawks", teamB: "Panthers", startTime: Calendar.current.date(byAdding: .hour, value: 4, to: Date())!),
        Match(matchID: 1005, teamA: "Dragons", teamB: "Phoenix", startTime: Calendar.current.date(byAdding: .hour, value: 5, to: Date())!),
        Match(matchID: 1006, teamA: "Thunder", teamB: "Lightning", startTime: Calendar.current.date(byAdding: .day, value: 1, to: Date())!),
        Match(matchID: 1007, teamA: "Fire", teamB: "Ice", startTime: Calendar.current.date(byAdding: .day, value: 1, to: Date())!),
        Match(matchID: 1008, teamA: "Storm", teamB: "Breeze", startTime: Calendar.current.date(byAdding: .day, value: 1, to: Date())!)
    ]
    
    static let initialOdds = [
        Odds(matchID: 1001, teamAOdds: 1.95, teamBOdds: 2.10),
        Odds(matchID: 1002, teamAOdds: 2.05, teamBOdds: 1.90),
        Odds(matchID: 1003, teamAOdds: 1.80, teamBOdds: 2.25),
        Odds(matchID: 1004, teamAOdds: 2.15, teamBOdds: 1.85),
        Odds(matchID: 1005, teamAOdds: 1.75, teamBOdds: 2.30),
        Odds(matchID: 1006, teamAOdds: 1.90, teamBOdds: 2.05),
        Odds(matchID: 1007, teamAOdds: 2.20, teamBOdds: 1.80),
        Odds(matchID: 1008, teamAOdds: 1.85, teamBOdds: 2.15)
    ]
}
