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
    
    // 🚀 RunLoop 和批次更新優化
    private var pendingUpdates: [Int: Odds] = [:]
    private var debounceTimer: Timer?
    private let debounceInterval: TimeInterval = 0.3
    
    // 🎯 滾動狀態管理
    @Published private(set) var isScrolling = false
    
    // 🎯 UI 更新回調 - 通知 ViewController 更新特定 cells
    var onBatchOddsUpdate: (([Int: Odds]) -> Void)?
    
    // 📊 效能統計
    private var totalUpdatesReceived = 0
    private var batchUpdatesProcessed = 0
    
    init(
        getMatchesUseCase: GetMatchesUseCaseProtocol,
        getOddsUseCase: GetOddsUseCaseProtocol,
        observeOddsUpdatesUseCase: ObserveOddsUpdatesUseCaseProtocol
    ) {
        self.getMatchesUseCase = getMatchesUseCase
        self.getOddsUseCase = getOddsUseCase
        self.observeOddsUpdatesUseCase = observeOddsUpdatesUseCase
    }
    
    deinit {
        oddsUpdateTask?.cancel()
        debounceTimer?.invalidate()
    }
}

// MARK: - Public APIs
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
                
                // 並行載入比賽和賠率資料
                let (matchesResult, oddsResult) = try await Task.detached(priority: .userInitiated) {
                    async let matches = self.getMatchesUseCase.execute()
                    async let odds = self.getOddsUseCase.execute()
                    return try await (matches, odds)
                }.value
                
                // 背景處理資料合併
                let processedData = await Task.detached(priority: .userInitiated) {
                    return await self.processMatchesWithOdds(matches: matchesResult, odds: oddsResult)
                }.value
                
                // 主線程更新狀態
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
    
    // 🎯 滾動狀態管理 - 由 ViewController 呼叫
    func setScrolling(_ scrolling: Bool) {
        guard isScrolling != scrolling else { return }
        
        isScrolling = scrolling
        
        if scrolling {
            print("📱 開始滾動 - 暫停 UI 更新")
            // 取消現有的 debounce timer
            debounceTimer?.invalidate()
            debounceTimer = nil
        } else {
            print("📱 停止滾動 - 恢復 UI 更新")
            // 🚀 修正：立即處理滾動期間累積的更新
            if !pendingUpdates.isEmpty {
                let updates = pendingUpdates
                pendingUpdates.removeAll()  // 立即清空
                
                print("⚡ 滾動結束，立即處理 \(updates.count) 筆累積更新")
                
                // 立即更新，不使用 debounce
                batchUpdatesProcessed += 1
                updatePublishedMatches()
                onBatchOddsUpdate?(updates)
            }
        }
    }
    
    // 📊 統計資訊
    var statisticsInfo: String {
        return "接收: \(totalUpdatesReceived) | 批次: \(batchUpdatesProcessed) | 待處理: \(pendingUpdates.count)"
    }
}

// MARK: - Private Methods
private extension MatchListViewModel {
    
    // 🚀 開始監聽賠率更新
    private func startObservingOddsUpdates() {
        oddsUpdateTask?.cancel()
        
        oddsUpdateTask = Task {
            print("⚡ 開始監聽賠率更新")
            
            for await oddsUpdate in observeOddsUpdatesUseCase.execute() {
                await handleOddsUpdate(oddsUpdate)
            }
        }
    }
    
    // 🎯 處理每筆賠率更新
    private func handleOddsUpdate(_ newOdds: Odds) async {
        totalUpdatesReceived += 1
        
        // 🎯 步驟1：更新內部資料模型（總是更新，不管是否滾動）
        if var existingMatch = matchesDict[newOdds.matchID] {
            existingMatch.odds = newOdds
            matchesDict[newOdds.matchID] = existingMatch
        }
        
        // 🎯 步驟2：根據滾動狀態決定處理策略
        if isScrolling {
            // 滾動中：累積更新，不觸發 UI 更新
            pendingUpdates[newOdds.matchID] = newOdds
            if totalUpdatesReceived % 20 == 0 {
                print("📱 滾動中，累積了 \(pendingUpdates.count) 筆待處理更新")
            }
        } else {
            // 🚀 關鍵修正：待機時立即處理，不累積
            let immediateUpdate = [newOdds.matchID: newOdds]
            
            // 取消任何現有的 debounce timer
            debounceTimer?.invalidate()
            debounceTimer = nil
            
            // 立即更新 Published 資料
            updatePublishedMatches()
            
            // 立即通知 ViewController 更新 UI
            onBatchOddsUpdate?(immediateUpdate)
            
            batchUpdatesProcessed += 1
            
            if totalUpdatesReceived % 50 == 0 {
                print("⚡ 待機中立即處理：第 \(batchUpdatesProcessed) 次更新")
            }
        }
        
        // 📊 定期統計
        if totalUpdatesReceived % 100 == 0 {
            print("📊 \(statisticsInfo)")
        }
    }
    
    // 🎯 安排 debounce 更新（非滾動時）
    private func scheduleDebounceUpdate() {
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: debounceInterval, repeats: false) { [weak self] _ in
            self?.processPendingUpdates()
        }
    }
    
    // 🎯 安排立即更新（滾動結束時）
    private func scheduleImmediateUpdate() {
        // 使用 RunLoop.main.perform 確保在 default mode 執行
        RunLoop.main.perform(inModes: [.default]) {
            Task { @MainActor in
                self.processPendingUpdates()
            }
        }
    }
    
    // 🚀 處理批次更新 - 核心方法
    private func processPendingUpdates() {
        guard !pendingUpdates.isEmpty else { return }
        guard !isScrolling else {
            print("⚠️ 處理時發現正在滾動，跳過 UI 更新")
            return
        }
        
        let updates = pendingUpdates
        pendingUpdates.removeAll()
        
        batchUpdatesProcessed += 1
        
        print("⚡ 批次更新 #\(batchUpdatesProcessed): \(updates.count) 筆賠率")
        
        // 🎯 步驟1：更新 Published 資料（觸發 SwiftUI/Combine 更新）
        updatePublishedMatches()
        
        // 🎯 步驟2：通知 ViewController 更新特定 cells
        onBatchOddsUpdate?(updates)
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
    
    // 🚀 背景執行緒處理排序
    private func updatePublishedMatches() {
        Task {
            let sortedMatches = await Task.detached(priority: .userInitiated) {
                return await Array(self.matchesDict.values)
                    .sorted { $0.match.startTime < $1.match.startTime }
            }.value
            
            matchesWithOdds = sortedMatches
        }
    }
    
    private func updateMatchesDict(with newDict: [Int: MatchWithOdds]) {
        matchesDict = newDict
        
        Task {
            await updatePublishedMatches()
        }
    }
}
