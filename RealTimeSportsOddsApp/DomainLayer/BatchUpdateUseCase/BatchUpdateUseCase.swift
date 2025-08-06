//
//  BatchUpdateUseCase.swift
//  RealTimeSportsOddsApp
//
//  Created by Chung Han Hsin on 2025/8/6.
//
import Foundation

class BatchUpdateUseCase: BatchUpdateUseCaseProtocol {
    
    // MARK: - Dependencies
    private let observeOddsUpdatesUseCase: ObserveOddsUpdatesUseCaseProtocol
    
    // MARK: - State Management
    private var isProcessing = false
    private var isScrolling = false
    private var oddsUpdateTask: Task<Void, Never>?
    
    // MARK: - Batch Update Logic
    private var pendingUpdates: [Int: Odds] = [:]
    private var debounceTimer: Timer?
    private let debounceInterval: TimeInterval = 0.3
    
    // MARK: - Callbacks
    private var batchUpdateCallback: (([Int: Odds]) -> Void)?
    
    // MARK: - Performance Metrics
    private var totalUpdatesReceived = 0
    private var batchUpdatesProcessed = 0
    
    // MARK: - Configuration
    private struct Config {
        static let debounceInterval: TimeInterval = 0.3
        static let maxBatchSize = 50
        static let statisticsLogInterval = 100
        static let scrollEndDelay: TimeInterval = 0.1
    }
    
    // MARK: - Initialization
    init(observeOddsUpdatesUseCase: ObserveOddsUpdatesUseCaseProtocol) {
        self.observeOddsUpdatesUseCase = observeOddsUpdatesUseCase
        print("📦 BatchUpdateUseCase 初始化完成")
    }
    
    deinit {
        cleanupResources()
        print("🗑️ BatchUpdateUseCase 已釋放")
    }
}

// MARK: - Public API Implementation
extension BatchUpdateUseCase {
    
    func startBatchProcessing() {
        guard !isProcessing else {
            print("⚠️ 批次處理已在運行中")
            return
        }
        
        isProcessing = true
        resetStatistics()
        startObservingOddsUpdates()
        
        print("🚀 BatchUpdateUseCase 開始批次處理")
    }
    
    @MainActor func stopBatchProcessing() {
        guard isProcessing else { return }
        
        isProcessing = false
        
        cleanupResources()
        
        // 處理剩餘的更新
        if !pendingUpdates.isEmpty {
            processPendingUpdatesImmediately()
        }
        
        print("🛑 BatchUpdateUseCase 停止批次處理")
        printFinalStatistics()
    }
    
    @MainActor
    func handleOddsUpdate(_ odds: Odds) {
        guard isProcessing else { return }
        
        totalUpdatesReceived += 1
        
        if isScrolling {
            handleScrollingModeUpdate(odds)
        } else {
            handleIdleModeUpdate(odds)
        }
        
        logStatisticsIfNeeded()
    }
    
    @MainActor
    func setScrolling(_ scrolling: Bool) {
        guard isScrolling != scrolling else { return }
        
        let previousState = isScrolling
        isScrolling = scrolling
        
        print("📱 滾動狀態變更: \(previousState ? "滾動中" : "待機") -> \(scrolling ? "滾動中" : "待機")")
        
        if scrolling {
            handleScrollingStart()
        } else {
            handleScrollingEnd()
        }
    }
    
    func setBatchUpdateCallback(_ callback: @escaping ([Int: Odds]) -> Void) {
        self.batchUpdateCallback = callback
    }
    
    var statisticsInfo: String {
        return "接收: \(totalUpdatesReceived) | 批次: \(batchUpdatesProcessed) | 待處理: \(pendingUpdates.count)"
    }
}

// MARK: - Private Implementation
private extension BatchUpdateUseCase {
    
    // MARK: - Resource Management
    func cleanupResources() {
        // 取消監聽任務
        oddsUpdateTask?.cancel()
        oddsUpdateTask = nil
        
        // 清理定時器
        debounceTimer?.invalidate()
        debounceTimer = nil
    }
    
    // MARK: - Odds Updates Observation
    func startObservingOddsUpdates() {
        oddsUpdateTask?.cancel()
        
        oddsUpdateTask = Task { [weak self] in
            print("⚡ 開始監聽賠率更新")
            
            for await oddsUpdate in self?.observeOddsUpdatesUseCase.execute() ?? AsyncStream<Odds>.makeEmpty() {
                await self?.handleOddsUpdate(oddsUpdate)
            }
        }
    }
    
    // MARK: - Scrolling Mode Handling
    @MainActor
    func handleScrollingStart() {
        // 取消任何現有的 debounce timer
        debounceTimer?.invalidate()
        debounceTimer = nil
        
        print("📱 開始滾動 - 切換到累積模式")
    }
    
    @MainActor
    func handleScrollingEnd() {
        print("📱 停止滾動 - 處理累積的更新")
        
        // 延遲一小段時間確保滾動完全結束
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(Config.scrollEndDelay * 1_000_000_000))
            self.processPendingUpdatesImmediately()
        }
    }
    
    @MainActor
    func handleScrollingModeUpdate(_ odds: Odds) {
        // 滾動中：累積更新，不立即處理
        pendingUpdates[odds.matchID] = odds
        
        if totalUpdatesReceived % 20 == 0 {
            print("📱 滾動中累積更新: \(pendingUpdates.count) 筆待處理")
        }
    }
    
    @MainActor
    func handleIdleModeUpdate(_ odds: Odds) {
        // 待機時：立即處理單個更新，不累積
        let immediateUpdate = [odds.matchID: odds]
        
        // 取消任何現有的 debounce timer
        debounceTimer?.invalidate()
        debounceTimer = nil
        
        // 立即處理
        processBatchUpdate(immediateUpdate)
        batchUpdatesProcessed += 1
        
        if totalUpdatesReceived % 50 == 0 {
            print("⚡ 待機模式立即處理: 第 \(batchUpdatesProcessed) 次更新")
        }
    }
    
    // MARK: - Batch Processing
    @MainActor
    func processPendingUpdatesImmediately() {
        guard !pendingUpdates.isEmpty else { return }
        guard !isScrolling else {
            print("⚠️ 處理時發現正在滾動，跳過處理")
            return
        }
        
        let updates = pendingUpdates
        pendingUpdates.removeAll()
        
        batchUpdatesProcessed += 1
        
        print("⚡ 立即批次處理: \(updates.count) 筆賠率更新")
        
        processBatchUpdate(updates)
    }
    
    @MainActor
    func scheduleDebounceUpdate() {
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: Config.debounceInterval, repeats: false) { [weak self] _ in
            self?.processPendingUpdatesWithDebounce()
        }
    }
    
    @MainActor
    func processPendingUpdatesWithDebounce() {
        guard !pendingUpdates.isEmpty else { return }
        guard !isScrolling else {
            print("⚠️ Debounce 處理時發現正在滾動，重新調度")
            scheduleDebounceUpdate()
            return
        }
        
        let updates = pendingUpdates
        pendingUpdates.removeAll()
        
        batchUpdatesProcessed += 1
        
        print("⚡ Debounce 批次處理: \(updates.count) 筆賠率更新")
        
        processBatchUpdate(updates)
    }
    
    func processBatchUpdate(_ updates: [Int: Odds]) {
        // 通知外部處理批次更新
        batchUpdateCallback?(updates)
    }
    
    // MARK: - Statistics & Logging
    func resetStatistics() {
        totalUpdatesReceived = 0
        batchUpdatesProcessed = 0
        pendingUpdates.removeAll()
    }
    
    func logStatisticsIfNeeded() {
        if totalUpdatesReceived % Config.statisticsLogInterval == 0 {
            print("📊 批次更新統計: \(statisticsInfo)")
        }
    }
    
    func printFinalStatistics() {
        print("📊 BatchUpdateUseCase 最終統計:")
        print("   - 總接收更新: \(totalUpdatesReceived)")
        print("   - 批次處理次數: \(batchUpdatesProcessed)")
        print("   - 剩餘待處理: \(pendingUpdates.count)")
        
        if totalUpdatesReceived > 0 {
            let batchEfficiency = Double(batchUpdatesProcessed) / Double(totalUpdatesReceived) * 100
            print("   - 批次效率: \(String(format: "%.1f", 100 - batchEfficiency))% 減少")
        }
    }
}

// MARK: - AsyncStream Extension
extension AsyncStream {
    static func makeEmpty() -> AsyncStream<Element> {
        return AsyncStream { continuation in
            continuation.finish()
        }
    }
}
