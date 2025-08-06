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
        // 直接调用非 MainActor 方法
        batchUpdateUseCase.stopBatchProcessing()
        print("🗑️ MatchListViewModel 已释放")
    }
}

// MARK: - Public API
extension MatchListViewModel {
    
    /// 重试连接
    func retryConnection() {
        print("🔄 重试连接")
        batchUpdateUseCase.startBatchProcessing()
    }
    
    /// 加载数据
    func loadData() {
        guard !isLoading else {
            print("⚠️ 正在加载中，跳过重复请求")
            return
        }
        
        isLoading = true
        errorMessage = nil
        resetDataUpdateCount()
        
        Task {
            await performDataLoading()
        }
    }
    
    /// 设置滚动状态
    func setScrolling(_ scrolling: Bool) {
        guard isScrolling != scrolling else { return }
        
        isScrolling = scrolling
        
        // 委托给 BatchUpdateUseCase 处理滚动状态
        batchUpdateUseCase.setScrolling(scrolling)
        
        print("📱 滚动状态更新: \(scrolling ? "开始滚动" : "停止滚动")")
    }
    
    /// 获取统计信息
    var statisticsInfo: String {
        let batchStats = batchUpdateUseCase.statisticsInfo
        return "\(batchStats) | 数据更新: \(dataUpdateCount)"
    }
}

// MARK: - Private Implementation
private extension MatchListViewModel {
    
    /// 设置批次更新用例
    func setupBatchUpdateUseCase() {
        // 设置批次更新回调
        batchUpdateUseCase.setBatchUpdateCallback { [weak self] updates in
            self?.handleBatchOddsUpdate(updates)
        }
        
        print("🔗 BatchUpdateUseCase 回调设置完成")
    }
    
    /// 执行数据加载
    func performDataLoading() async {
        do {
            print("🚀 开始加载数据...")
            let startTime = Date()
            
            // 并行加载比赛和赔率数据
            let (matchesResult, oddsResult) = try await loadMatchesAndOdds()
            
            // 背景处理数据合并
            let processedData = await processMatchesWithOdds(matches: matchesResult, odds: oddsResult)
            
            // 更新数据模型
            await updateDataModel(with: processedData)
            
            // 开始批次处理
            batchUpdateUseCase.startBatchProcessing()
            
            isLoading = false
            
            let loadTime = Date().timeIntervalSince(startTime)
            print("✅ 数据加载完成，耗时: \(String(format: "%.2f", loadTime)) 秒")
            
        } catch {
            await handleLoadingError(error)
        }
    }
    
    /// 并行加载比赛和赔率数据
    func loadMatchesAndOdds() async throws -> ([Match], [Odds]) {
        return try await Task.detached(priority: .userInitiated) {
            async let matches = self.getMatchesUseCase.execute()
            async let odds = self.getOddsUseCase.execute()
            return try await (matches, odds)
        }.value
    }
    
    /// 处理数据合并
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
    
    /// 更新数据模型
    func updateDataModel(with newData: [Int: MatchWithOdds]) async {
        matchesDict = newData
        await updatePublishedMatches()
        dataUpdateCount += 1
        
        print("📊 数据模型更新完成: \(newData.count) 笔数据")
    }
    
    /// 处理加载错误
    func handleLoadingError(_ error: Error) async {
        print("❌ 数据加载失败: \(error)")
        isLoading = false
        errorMessage = error.localizedDescription
    }
    
    /// 处理批次赔率更新
    func handleBatchOddsUpdate(_ updates: [Int: Odds]) {
        print("🎯 ViewModel 接收到批次更新: \(updates.count) 笔")
        
        // 更新内部数据模型
        updateInternalDataWithOdds(updates)
        
        // 更新发布的数据
        Task {
            await updatePublishedMatches()
        }
        
        // 通知 UI 层
        onBatchOddsUpdate?(updates)
        
        dataUpdateCount += updates.count
    }
    
    /// 使用新赔率更新内部数据
    func updateInternalDataWithOdds(_ updates: [Int: Odds]) {
        for (matchID, newOdds) in updates {
            if var existingMatch = matchesDict[matchID] {
                existingMatch.odds = newOdds
                matchesDict[matchID] = existingMatch
            }
        }
    }
    
    /// 更新发布的比赛数据
    func updatePublishedMatches() async {
        let sortedMatches = await Task.detached(priority: .userInitiated) {
            return await Array(self.matchesDict.values)
                .sorted { $0.match.startTime < $1.match.startTime }
        }.value
        
        matchesWithOdds = sortedMatches
    }
    
    /// 重置数据更新计数
    func resetDataUpdateCount() {
        dataUpdateCount = 0
    }
}
