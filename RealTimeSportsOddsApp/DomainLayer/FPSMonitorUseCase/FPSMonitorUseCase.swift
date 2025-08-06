//
//  FPSMonitorUseCase.swift (Fixed Version)
//  RealTimeSportsOddsApp
//
//  Created by Chung Han Hsin on 2025/8/6.
//

import Foundation
import QuartzCore

// MARK: - FPS Provider Protocol (抽象 UIKit 依賴)
protocol FPSProviderProtocol {
    var onFPSUpdate: ((Double, Bool) -> Void)? { get set }  // 🔧 改用閉包回調
    func startMonitoring()
    func stopMonitoring()
}

// MARK: - FPS Monitor UseCase Class (Fixed)
class FPSMonitorUseCase: FPSMonitorUseCaseProtocol {
    
    // MARK: - Properties
    var onFPSUpdate: ((Double, Bool) -> Void)?  // 🔧 改用閉包回調
    
    private var fpsProvider: FPSProviderProtocol
    private var fps: Double = 0
    
    // 🎯 FPS 计算参数 (保持原有邏輯)
    private let targetFPS: Double = 60.0
    private let fpsThreshold: Double = 55.0
    
    // 🎯 滚动状态监控 (保持原有邏輯)
    private(set) var isMonitoring = false
    
    // 📊 统计数据 (保持原有邏輯)
    private var totalFrames = 0
    private var droppedFrames = 0
    private var monitoringStartTime: CFTimeInterval = 0
    
    // MARK: - Initialization
    init(fpsProvider: FPSProviderProtocol) {
        self.fpsProvider = fpsProvider
        
        // 🔧 直接設置 FPS Provider 的回調
        self.fpsProvider.onFPSUpdate = { [weak self] fps, isDropped in
            self?.handleFPSUpdate(fps: fps, isDropped: isDropped)
        }
    }
    
    // MARK: - Public Methods
    
    /// 开始监控 FPS (保持原有邏輯)
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        resetCounters()
        
        fpsProvider.startMonitoring()
        
        print("🎯 FPS Monitor 开始监控")
    }
    
    /// 停止监控 FPS (保持原有邏輯)
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        isMonitoring = false
        fpsProvider.stopMonitoring()
        
        printFinalStatistics()
        print("🛑 FPS Monitor 停止监控")
    }
    
    /// 获取当前 FPS (保持原有邏輯)
    var currentFPS: Double {
        return fps
    }
    
    /// 获取统计信息 (保持原有邏輯)
    var statisticsInfo: String {
        guard totalFrames > 0 else { return "暂无数据" }
        
        let dropRate = Double(droppedFrames) / Double(totalFrames) * 100
        let avgFPS = fps
        
        return String(format: "FPS: %.1f | 丢帧率: %.1f%% | 总帧数: %d",
                     avgFPS, dropRate, totalFrames)
    }
    
    // MARK: - Private Methods (保持原有邏輯)
    
    private func resetCounters() {
        fps = 0
        totalFrames = 0
        droppedFrames = 0
        monitoringStartTime = CACurrentMediaTime()
    }
    
    private func printFinalStatistics() {
        let totalTime = CACurrentMediaTime() - monitoringStartTime
        let avgFPS = totalTime > 0 ? Double(totalFrames) / totalTime : 0
        let dropRate = totalFrames > 0 ? Double(droppedFrames) / Double(totalFrames) * 100 : 0
        
        print("📊 FPS Monitor 最终统计:")
        print("   - 监控时长: \(String(format: "%.2f", totalTime)) 秒")
        print("   - 总帧数: \(totalFrames)")
        print("   - 丢帧数: \(droppedFrames)")
        print("   - 平均 FPS: \(String(format: "%.1f", avgFPS))")
        print("   - 丢帧率: \(String(format: "%.2f", dropRate))%")
    }
    
    // 🔧 處理 FPS 更新的內部方法
    private func handleFPSUpdate(fps: Double, isDropped: Bool) {
        self.fps = fps
        
        // 更新统计数据 (保持原有邏輯)
        totalFrames += 1
        if isDropped {
            droppedFrames += 1
        }
        
        // 通知外部 (保持原有邏輯)
        onFPSUpdate?(fps, isDropped)
        
        // 调试信息 (保持原有邏輯)
        if isDropped {
            print("⚠️ 检测到卡顿: FPS = \(String(format: "%.1f", fps))")
        }
    }
    
    // MARK: - Deinitializer
    deinit {
        stopMonitoring()
    }
}

// MARK: - Legacy Delegate Protocol (如果其他地方還需要)
protocol FPSMonitorDelegate: AnyObject {
    func fpsMonitor(_ monitor: FPSMonitorUseCaseProtocol, didUpdateFPS fps: Double, isDropped: Bool)
}
