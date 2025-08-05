//
//  MatchListViewModel.swift
//  RealTimeSportsOddsApp
//
//  Created by Chung Han Hsin on 2025/8/4.
//

import Foundation
import Combine

@MainActor
class MatchListViewModel: ObservableObject {
    @Published private(set) var matchesWithOdds: [MatchWithOdds] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    
    private let getMatchesUseCase: GetMatchesUseCaseProtocol
    private let getOddsUseCase: GetOddsUseCaseProtocol
    private let observeOddsUpdatesUseCase: ObserveOddsUpdatesUseCaseProtocol
    
    private var cancellables = Set<AnyCancellable>()
    private var oddsUpdateTask: Task<Void, Never>?
    private var matchesDict: [Int: MatchWithOdds] = [:]
    
    // 🚀 批次處理優化
    private var pendingOddsUpdates: [Int: Odds] = [:]
    private var batchUpdateTask: Task<Void, Never>?
    
    // 🚀 優化：添加節流機制
    private var lastUpdateTime = Date()
    private let minUpdateInterval: TimeInterval = 0.05 // 最小更新間隔 50ms
    
    init(getMatchesUseCase: GetMatchesUseCaseProtocol, getOddsUseCase: GetOddsUseCaseProtocol, observeOddsUpdatesUseCase: ObserveOddsUpdatesUseCaseProtocol) {
        self.getMatchesUseCase = getMatchesUseCase
        self.getOddsUseCase = getOddsUseCase
        self.observeOddsUpdatesUseCase = observeOddsUpdatesUseCase
    }
    
    deinit {
        oddsUpdateTask?.cancel()
        batchUpdateTask?.cancel()
    }
}

// MARK: - Internal APIs
extension MatchListViewModel {
    func retryConnection() {
        startObservingOddsUpdates()
    }
    
    func loadData() {
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                print("🚀 開始載入資料...")
                let startTime = Date()
                
                // 🚀 背景執行緒並行載入
                let (matchesResult, oddsResult) = try await Task.detached(priority: .userInitiated) {
                    print("📡 背景執行緒載入資料")
                    async let matches = self.getMatchesUseCase.execute()
                    async let odds = self.getOddsUseCase.execute()
                    return try await (matches, odds)
                }.value
                
                // 🚀 背景執行緒處理資料
                let processedData = await Task.detached(priority: .userInitiated) {
                    print("🔄 背景執行緒處理資料合併")
                    return await self.processMatchesWithOdds(matches: matchesResult, odds: oddsResult)
                }.value
                
                // 🎯 主執行緒更新狀態
                print("🎯 主執行緒更新 UI")
                updateMatchesDict(with: processedData)
                startObservingOddsUpdates()
                
                isLoading = false
                
                let loadTime = Date().timeIntervalSince(startTime)
                print("✅ 載入完成，耗時: \(String(format: "%.2f", loadTime))秒")
                
            } catch {
                print("❌ 載入失敗: \(error)")
                isLoading = false
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Private Helpers
private extension MatchListViewModel {
    private func startObservingOddsUpdates() {
        oddsUpdateTask?.cancel()
        
        oddsUpdateTask = Task {
            print("⚡ 開始監聽賠率更新")
            for await oddsUpdate in observeOddsUpdatesUseCase.execute() {
                handleOddsUpdate(oddsUpdate)
            }
        }
    }
    
    
    
    // 🚀 背景執行緒處理資料合併
    private func processMatchesWithOdds(matches: [Match], odds: [Odds]) async -> [Int: MatchWithOdds] {
        let oddsDict = Dictionary(uniqueKeysWithValues: odds.map { ($0.matchID, $0) })
        
        let matchesDict = Dictionary(uniqueKeysWithValues: matches.map { match in
            let matchWithOdds = MatchWithOdds(match: match, odds: oddsDict[match.matchID])
            return (match.matchID, matchWithOdds)
        })
        
        return matchesDict
    }
    
    private func handleOddsUpdate(_ newOdds: Odds) {
        // 收集待處理的更新
        pendingOddsUpdates[newOdds.matchID] = newOdds
        
        // 取消之前的批次任務
        batchUpdateTask?.cancel()
        
        // 🚀 優化：延長批次處理時間 (從 16ms 改為 100ms)
        // 這樣可以收集更多更新，減少 UI 刷新頻率
        // TODO: - 之後用 CADisplayLink 處理
        batchUpdateTask = Task {
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            
            guard !Task.isCancelled else { return }
            processBatchOddsUpdates()
        }
    }

    
    // 🚀 背景執行緒處理排序
    private func updatePublishedMatches() async {
        let sortedMatches = await Task.detached(priority: .userInitiated) {
            return await Array(self.matchesDict.values)
                .sorted { $0.match.startTime < $1.match.startTime }
        }.value
        
        matchesWithOdds = sortedMatches
    }
    
    private func processBatchOddsUpdates() {
        let updates = pendingOddsUpdates
        pendingOddsUpdates.removeAll()
        
        guard !updates.isEmpty else { return }
        
        // 🚀 節流：如果距離上次更新時間太短，則延遲處理
        let now = Date()
        if now.timeIntervalSince(lastUpdateTime) < minUpdateInterval {
            // 延遲到最小間隔後再處理
            Task {
                let delay = minUpdateInterval - now.timeIntervalSince(lastUpdateTime)
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                processBatchOddsUpdates()
            }
            return
        }
        
        lastUpdateTime = now
        
        Task {
            // 🚀 背景執行緒批次處理更新
            let updatedDict = await Task.detached(priority: .userInitiated) {
                var dict = await self.matchesDict
                
                for (matchID, odds) in updates {
                    if var existingMatch = dict[matchID] {
                        existingMatch.odds = odds
                        dict[matchID] = existingMatch
                    }
                }
                
                return dict
            }.value
            
            // 🎯 主執行緒更新資料
            matchesDict = updatedDict
            await updatePublishedMatches()
            
            print("⚡ 批次更新 \(updates.count) 筆賠率 (節流優化)")
        }
    }
    
    private func updateMatchesDict(with newDict: [Int: MatchWithOdds]) {
        matchesDict = newDict
        
        Task {
            await updatePublishedMatches()
        }
    }
    
}
