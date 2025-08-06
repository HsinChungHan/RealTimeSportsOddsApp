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
    
    // 🎯 FPS 计算参数
    private let targetFPS: Double = 60.0  // 目标帧率
    private let fpsThreshold: Double = 55.0  // 低于此值视为卡顿
    private let measureInterval: TimeInterval = 1.0  // 每秒计算一次 FPS
    
    // 🎯 滚动状态监控
    private(set) var isMonitoring = false
    private var accumulatedTime: CFTimeInterval = 0
    
    // 📊 统计数据
    private var totalFrames = 0
    private var droppedFrames = 0
    private var monitoringStartTime: CFTimeInterval = 0
    
    // MARK: - Public Methods
    
    /// 开始监控 FPS
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        resetCounters()
        
        // 创建 CADisplayLink
        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkCallback))
        displayLink?.preferredFramesPerSecond = 0  // 使用屏幕最大刷新率
        
        // 🚀 关键：将 DisplayLink 添加到主线程的 common modes
        // 这确保在滚动时也能正常工作
        displayLink?.add(to: .main, forMode: .common)
        
        print("🎯 FPS Monitor 开始监控")
    }
    
    /// 停止监控 FPS
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        isMonitoring = false
        displayLink?.invalidate()
        displayLink = nil
        
        printFinalStatistics()
        print("🛑 FPS Monitor 停止监控")
    }
    
    /// 获取当前 FPS
    var currentFPS: Double {
        return fps
    }
    
    /// 获取统计信息
    var statisticsInfo: String {
        guard totalFrames > 0 else { return "暂无数据" }
        
        let dropRate = Double(droppedFrames) / Double(totalFrames) * 100
        let avgFPS = fps
        
        return String(format: "FPS: %.1f | 丢帧率: %.1f%% | 总帧数: %d",
                     avgFPS, dropRate, totalFrames)
    }
    
    // MARK: - Private Methods
    
    @objc private func displayLinkCallback(_ displayLink: CADisplayLink) {
        let currentTime = displayLink.timestamp
        
        // 初始化时间戳
        if lastTimestamp == 0 {
            lastTimestamp = currentTime
            monitoringStartTime = currentTime
            return
        }
        
        // 计算帧间隔
        let deltaTime = currentTime - lastTimestamp
        lastTimestamp = currentTime
        
        frameCount += 1
        totalFrames += 1
        accumulatedTime += deltaTime
        
        // 检测掉帧 - 如果帧间隔超过预期时间的 1.5 倍，认为是掉帧
        let expectedFrameTime = 1.0 / targetFPS
        if deltaTime > expectedFrameTime * 1.5 {
            droppedFrames += 1
        }
        
        // 每秒计算一次 FPS
        if accumulatedTime >= measureInterval {
            calculateFPS()
            resetFrameCount()
        }
    }
    
    private func calculateFPS() {
        // 计算实际 FPS
        fps = Double(frameCount) / accumulatedTime
        
        // 判断是否卡顿
        let isDropped = fps < fpsThreshold
        
        // 通知代理
        delegate?.fpsMonitor(self, didUpdateFPS: fps, isDropped: isDropped)
        
        // 调试信息
        if isDropped {
            print("⚠️ 检测到卡顿: FPS = \(String(format: "%.1f", fps))")
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
        
        print("📊 FPS Monitor 最终统计:")
        print("   - 监控时长: \(String(format: "%.2f", totalTime)) 秒")
        print("   - 总帧数: \(totalFrames)")
        print("   - 丢帧数: \(droppedFrames)")
        print("   - 平均 FPS: \(String(format: "%.1f", avgFPS))")
        print("   - 丢帧率: \(String(format: "%.2f", dropRate))%")
    }
    
    // MARK: - Deinitializer
    deinit {
        stopMonitoring()
    }
}
