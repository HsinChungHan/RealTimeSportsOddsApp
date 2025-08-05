//
//  MockData.swift
//  RealTimeSportsOddsApp
//
//  Created by Chung Han Hsin on 2025/8/3.
//

import Foundation

struct MockData {
    
    // 🚀 球隊名稱資料庫
    private static let teamNames = [
        "Eagles", "Tigers", "Lions", "Bears", "Wolves", "Sharks", "Hawks", "Panthers",
        "Dragons", "Phoenix", "Thunder", "Lightning", "Fire", "Ice", "Storm", "Breeze",
        "Warriors", "Knights", "Rangers", "Hunters", "Guardians", "Defenders", "Crusaders", "Champions",
        "Bulls", "Rams", "Stallions", "Mustangs", "Colts", "Broncos", "Chargers", "Raiders",
        "Falcons", "Ravens", "Cardinals", "Orioles", "Blue Jays", "Robins", "Sparrows", "Owls",
        "Cobras", "Vipers", "Pythons", "Anacondas", "Mambas", "Rattlers", "Scorpions", "Spiders",
        "Titans", "Giants", "Cyclones", "Hurricanes", "Tornadoes", "Meteors", "Comets", "Stars",
        "Blazers", "Flames", "Inferno", "Magma", "Lava", "Ember", "Spark", "Flash",
        "Wolves", "Foxes", "Leopards", "Jaguars", "Pumas", "Lynx", "Wildcats", "Cougars",
        "Dolphins", "Whales", "Sharks", "Marlins", "Swordfish", "Barracudas", "Stingrays", "Piranhas",
        "Rockets", "Missiles", "Jets", "Bombers", "Fighters", "Interceptors", "Destroyers", "Cruisers",
        "Samurai", "Ninjas", "Ronin", "Shogun", "Daimyo", "Monks", "Priests", "Templars",
        "Aliens", "Robots", "Cyborgs", "Androids", "Mechs", "Drones", "Bots", "AI"
    ]
    
    // 🎯 生成 100 筆比賽資料
    static let matches: [Match] = {
        var matches: [Match] = []
        let calendar = Calendar.current
        let now = Date()
        
        for i in 1...100 {
            // 隨機選擇兩個不同的球隊
            let shuffledTeams = teamNames.shuffled()
            let teamA = shuffledTeams[0]
            let teamB = shuffledTeams[1]
            
            // 生成未來的比賽時間
            // 前50場：未來1-24小時內
            // 後50場：未來1-7天內
            let hoursToAdd = i <= 50 ? Int.random(in: 1...24) : Int.random(in: 24...168)
            let startTime = calendar.date(byAdding: .hour, value: hoursToAdd, to: now) ?? now
            
            let match = Match(
                matchID: 1000 + i,
                teamA: teamA,
                teamB: teamB,
                startTime: startTime
            )
            
            matches.append(match)
        }
        
        // 按開始時間排序 (最近的在前面)
        return matches.sorted { $0.startTime < $1.startTime }
    }()
    
    // 🎯 對應的初始賠率資料
    static let initialOdds: [Odds] = {
        return matches.map { match in
            // 生成合理的賠率 (通常在 1.1 ~ 3.0 之間)
            let teamAOdds = Double.random(in: 1.2...2.8)
            let teamBOdds = Double.random(in: 1.2...2.8)
            
            return Odds(
                matchID: match.matchID,
                teamAOdds: round(teamAOdds * 100) / 100, // 保留兩位小數
                teamBOdds: round(teamBOdds * 100) / 100
            )
        }
    }()
    
    // 🎯 便利方法：獲取指定數量的測試資料
    static func getMatches(count: Int) -> [Match] {
        return Array(matches.prefix(count))
    }
    
    static func getOdds(count: Int) -> [Odds] {
        return Array(initialOdds.prefix(count))
    }
    
    // 🎯 便利方法：獲取指定範圍的賠率變化
    static func getRandomOddsUpdate() -> Odds {
        let randomMatch = matches.randomElement()!
        let baseOdds = initialOdds.first { $0.matchID == randomMatch.matchID }!
        
        return Odds(
            matchID: randomMatch.matchID,
            teamAOdds: max(1.1, baseOdds.teamAOdds + Double.random(in: -0.3...0.3)),
            teamBOdds: max(1.1, baseOdds.teamBOdds + Double.random(in: -0.3...0.3))
        )
    }
}
