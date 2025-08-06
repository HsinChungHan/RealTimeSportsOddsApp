//
//  FPSMonitor.swift
//  RealTimeSportsOddsApp
//
//  Created by Chung Han Hsin on 2025/8/6.
//
import UIKit

// MARK: - FPS Monitor Protocol
protocol FPSMonitorDelegate: AnyObject {
    func fpsMonitor(_ monitor: FPSMonitor, didUpdateFPS fps: Double, isDropped: Bool)
}

// MARK: - FPS Monitor Class
class FPSMonitor {
    
    // MARK: - Properties
    weak var delegate: FPSMonitorDelegate?
    
    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0
    private var frameCount: Int = 0
    private var fps: Double = 0
    
    // 🎯 FPS 計算參數
    private let targetFPS: Double = 60.0  // 目標幀率
    private let fpsThreshold: Double = 55.0  // 低於此值視為卡頓
    private let measureInterval: TimeInterval = 1.0  // 每秒計算一次 FPS
    
    // 🎯 滾動狀態監控
    private(set) var isMonitoring = false
    private var accumulatedTime: CFTimeInterval = 0
    
    // 📊 統計數據
    private var totalFrames = 0
    private var droppedFrames = 0
    private var monitoringStartTime: CFTimeInterval = 0
    
    // MARK: - Public Methods
    
    /// 開始監控 FPS
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        resetCounters()
        
        // 創建 CADisplayLink
        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkCallback))
        displayLink?.preferredFramesPerSecond = 0  // 使用屏幕最大刷新率
        
        // 🚀 關鍵：將 DisplayLink 添加到主線程的 common modes
        // 這確保在滾動時也能正常工作
        displayLink?.add(to: .main, forMode: .common)
        
        print("🎯 FPS Monitor 開始監控")
    }
    
    /// 停止監控 FPS
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        isMonitoring = false
        displayLink?.invalidate()
        displayLink = nil
        
        printFinalStatistics()
        print("🛑 FPS Monitor 停止監控")
    }
    
    /// 獲取當前 FPS
    var currentFPS: Double {
        return fps
    }
    
    /// 獲取統計信息
    var statisticsInfo: String {
        guard totalFrames > 0 else { return "暫無數據" }
        
        let dropRate = Double(droppedFrames) / Double(totalFrames) * 100
        let avgFPS = fps
        
        return String(format: "FPS: %.1f", avgFPS)
    }
    
    // MARK: - Private Methods
    
    @objc private func displayLinkCallback(_ displayLink: CADisplayLink) {
        let currentTime = displayLink.timestamp
        
        // 初始化時間戳
        if lastTimestamp == 0 {
            lastTimestamp = currentTime
            monitoringStartTime = currentTime
            return
        }
        
        // 計算幀間隔
        let deltaTime = currentTime - lastTimestamp
        lastTimestamp = currentTime
        
        frameCount += 1
        totalFrames += 1
        accumulatedTime += deltaTime
        
        // 檢測掉幀 - 如果幀間隔超過預期時間的 1.5 倍，認為是掉幀
        let expectedFrameTime = 1.0 / targetFPS
        if deltaTime > expectedFrameTime * 1.5 {
            droppedFrames += 1
        }
        
        // 每秒計算一次 FPS
        if accumulatedTime >= measureInterval {
            calculateFPS()
            resetFrameCount()
        }
    }
    
    private func calculateFPS() {
        // 計算實際 FPS
        fps = Double(frameCount) / accumulatedTime
        
        // 判斷是否卡頓
        let isDropped = fps < fpsThreshold
        
        // 通知代理
        delegate?.fpsMonitor(self, didUpdateFPS: fps, isDropped: isDropped)
        
        // 調試信息
        if isDropped {
            print("⚠️ 檢測到卡頓: FPS = \(String(format: "%.1f", fps))")
        }
    }
    
    private func resetFrameCount() {
        frameCount = 0
        accumulatedTime = 0
    }
    
    private func resetCounters() {
        lastTimestamp = 0
        frameCount = 0
        fps = 0
        accumulatedTime = 0
        totalFrames = 0
        droppedFrames = 0
        monitoringStartTime = 0
    }
    
    private func printFinalStatistics() {
        let totalTime = CACurrentMediaTime() - monitoringStartTime
        let avgFPS = totalTime > 0 ? Double(totalFrames) / totalTime : 0
        let dropRate = totalFrames > 0 ? Double(droppedFrames) / Double(totalFrames) * 100 : 0
        
        print("📊 FPS Monitor 最終統計:")
        print("   - 監控時長: \(String(format: "%.2f", totalTime)) 秒")
        print("   - 總幀數: \(totalFrames)")
        print("   - 丟幀數: \(droppedFrames)")
        print("   - 平均 FPS: \(String(format: "%.1f", avgFPS))")
        print("   - 丟幀率: \(String(format: "%.2f", dropRate))%")
    }
    
    // MARK: - Deinitializer
    deinit {
        stopMonitoring()
    }
}
