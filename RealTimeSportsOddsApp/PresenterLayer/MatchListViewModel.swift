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
    
    // MARK: - Published Properties
    @Published private(set) var matchesWithOdds: [MatchWithOdds] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    
    // MARK: - Dependencies
    private let getMatchesUseCase: GetMatchesUseCaseProtocol
    private let getOddsUseCase: GetOddsUseCaseProtocol
    private let batchUpdateUseCase: BatchUpdateUseCaseProtocol
    
    // MARK: - State Management
    private var cancellables = Set<AnyCancellable>()
    private var matchesDict: [Int: MatchWithOdds] = [:]
    
    // MARK: - UI Interaction
    @Published private(set) var isScrolling = false
    
    // MARK: - Callbacks
    var onBatchOddsUpdate: (([Int: Odds]) -> Void)?
    
    // MARK: - Performance Metrics
    private var dataUpdateCount = 0
    
    // MARK: - Initialization
    init(
        getMatchesUseCase: GetMatchesUseCaseProtocol,
        getOddsUseCase: GetOddsUseCaseProtocol,
        batchUpdateUseCase: BatchUpdateUseCaseProtocol
    ) {
        self.getMatchesUseCase = getMatchesUseCase
        self.getOddsUseCase = getOddsUseCase
        self.batchUpdateUseCase = batchUpdateUseCase
        
        setupBatchUpdateUseCase()
        
        print("🎯 MatchListViewModel 初始化完成 (使用 BatchUpdateUseCase)")
    }
    
    deinit {
        // 直接調用非 MainActor 方法
        batchUpdateUseCase.stopBatchProcessing()
        print("🗑️ MatchListViewModel 已釋放")
    }
}

// MARK: - Public API
extension MatchListViewModel {
    
    /// 重試連接
    func retryConnection() {
        print("🔄 重試連接")
        batchUpdateUseCase.startBatchProcessing()
    }
    
    /// 加載數據
    func loadData() {
        guard !isLoading else {
            print("⚠️ 正在加載中，跳過重復請求")
            return
        }
        
        isLoading = true
        errorMessage = nil
        resetDataUpdateCount()
        
        Task {
            await performDataLoading()
        }
    }
    
    /// 設置滾動狀態
    func setScrolling(_ scrolling: Bool) {
        guard isScrolling != scrolling else { return }
        
        isScrolling = scrolling
        
        // 委託給 BatchUpdateUseCase 處理滾動狀態
        batchUpdateUseCase.setScrolling(scrolling)
        
        print("📱 滾動狀態更新: \(scrolling ? "開始滾動" : "停止滾動")")
    }
    
    /// 獲取統計信息
    var statisticsInfo: String {
        let batchStats = batchUpdateUseCase.statisticsInfo
        return "\(batchStats) | 數據更新: \(dataUpdateCount)"
    }
}

// MARK: - Private Implementation
private extension MatchListViewModel {
    
    // 設置批次更新用例
    func setupBatchUpdateUseCase() {
        // 設置批次更新回調
        batchUpdateUseCase.setBatchUpdateCallback { [weak self] updates in
            self?.handleBatchOddsUpdate(updates)
        }
        
        print("🔗 BatchUpdateUseCase 回調設置完成")
    }
    
    /// 執行數據加載
    func performDataLoading() async {
        do {
            print("🚀 開始加載數據...")
            let startTime = Date()
            
            // 並行加載比賽和賠率數據
            let (matchesResult, oddsResult) = try await loadMatchesAndOdds()
            
            // 背景處理數據合併
            let processedData = await processMatchesWithOdds(matches: matchesResult, odds: oddsResult)
            
            // 更新數據模型
            await updateDataModel(with: processedData)
            
            // 開始批次處理
            batchUpdateUseCase.startBatchProcessing()
            
            isLoading = false
            
            let loadTime = Date().timeIntervalSince(startTime)
            print("✅ 數據加載完成，耗時: \(String(format: "%.2f", loadTime)) 秒")
            
        } catch {
            await handleLoadingError(error)
        }
    }
    
    /// 並行加載比賽和賠率數據
    func loadMatchesAndOdds() async throws -> ([Match], [Odds]) {
        return try await Task.detached(priority: .userInitiated) {
            async let matches = self.getMatchesUseCase.execute()
            async let odds = self.getOddsUseCase.execute()
            return try await (matches, odds)
        }.value
    }
    
    /// 處理數據合併
    func processMatchesWithOdds(matches: [Match], odds: [Odds]) async -> [Int: MatchWithOdds] {
        return await Task.detached(priority: .userInitiated) {
            let oddsDict = Dictionary(uniqueKeysWithValues: odds.map { ($0.matchID, $0) })
            
            let matchesDict = Dictionary(uniqueKeysWithValues: matches.map { match in
                let matchWithOdds = MatchWithOdds(match: match, odds: oddsDict[match.matchID])
                return (match.matchID, matchWithOdds)
            })
            
            return matchesDict
        }.value
    }
    
    /// 更新數據模型
    func updateDataModel(with newData: [Int: MatchWithOdds]) async {
        matchesDict = newData
        await updatePublishedMatches()
        dataUpdateCount += 1
        
        print("📊 數據模型更新完成: \(newData.count) 筆數據")
    }
    
    /// 處理加載錯誤
    func handleLoadingError(_ error: Error) async {
        print("❌ 數據加載失敗: \(error)")
        isLoading = false
        errorMessage = error.localizedDescription
    }
    
    /// 處理批次賠率更新
    func handleBatchOddsUpdate(_ updates: [Int: Odds]) {
        print("🎯 ViewModel 接收到批次更新: \(updates.count) 筆")
        
        // 更新內部數據模型
        updateInternalDataWithOdds(updates)
        
        // 更新發佈的數據
        Task {
            await updatePublishedMatches()
        }
        
        // 通知 UI 層
        onBatchOddsUpdate?(updates)
        
        dataUpdateCount += updates.count
    }
    
    /// 使用新賠率更新內部數據
    func updateInternalDataWithOdds(_ updates: [Int: Odds]) {
        for (matchID, newOdds) in updates {
            if var existingMatch = matchesDict[matchID] {
                existingMatch.odds = newOdds
                matchesDict[matchID] = existingMatch
            }
        }
    }
    
    /// 更新發佈的比賽數據
    func updatePublishedMatches() async {
        let sortedMatches = await Task.detached(priority: .userInitiated) {
            return await Array(self.matchesDict.values)
                .sorted { $0.match.startTime > $1.match.startTime }
        }.value
        
        matchesWithOdds = sortedMatches
    }
    
    /// 重置數據更新計數
    func resetDataUpdateCount() {
        dataUpdateCount = 0
    }
}
