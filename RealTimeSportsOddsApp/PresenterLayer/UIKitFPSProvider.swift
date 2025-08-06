//
//  UIKitFPSProvider.swift (Fixed Version)
//  RealTimeSportsOddsApp
//
//  Created by Chung Han Hsin on 2025/8/6.
//

import UIKit
import QuartzCore

// MARK: - UIKit FPS Provider Class (Fixed with Callback)
class UIKitFPSProvider: FPSProviderProtocol {
    
    // MARK: - Properties
    var onFPSUpdate: ((Double, Bool) -> Void)?  // 🔧 改用閉包回調
    
    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0
    private var frameCount: Int = 0
    private var accumulatedTime: CFTimeInterval = 0
    
    // 🎯 FPS 计算参数 (保持原有邏輯)
    private let targetFPS: Double = 60.0
    private let fpsThreshold: Double = 55.0
    private let measureInterval: TimeInterval = 1.0
    
    // MARK: - Public Methods
    
    func startMonitoring() {
        guard displayLink == nil else { return }
        
        print("🎯 UIKitFPSProvider 開始監控")
        
        // 创建 CADisplayLink (保持原有邏輯)
        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkCallback))
        displayLink?.preferredFramesPerSecond = 0  // 使用屏幕最大刷新率
        
        // 🚀 关键：将 DisplayLink 添加到主线程的 common modes (保持原有邏輯)
        // 这确保在滚动时也能正常工作
        displayLink?.add(to: .main, forMode: .common)
    }
    
    func stopMonitoring() {
        print("🛑 UIKitFPSProvider 停止監控")
        
        displayLink?.invalidate()
        displayLink = nil
        lastTimestamp = 0
        frameCount = 0
        accumulatedTime = 0
    }
    
    // MARK: - Private Methods (保持原有邏輯)
    
    @objc private func displayLinkCallback(_ displayLink: CADisplayLink) {
        let currentTime = displayLink.timestamp
        
        // 初始化时间戳 (保持原有邏輯)
        if lastTimestamp == 0 {
            lastTimestamp = currentTime
            return
        }
        
        // 计算帧间隔 (保持原有邏輯)
        let deltaTime = currentTime - lastTimestamp
        lastTimestamp = currentTime
        
        frameCount += 1
        accumulatedTime += deltaTime
        
        // 检测掉帧 - 如果帧间隔超过预期时间的 1.5 倍，认为是掉帧 (保持原有邏輯)
        let expectedFrameTime = 1.0 / targetFPS
        let isDropped = deltaTime > expectedFrameTime * 1.5
        
        // 每秒计算一次 FPS (保持原有邏輯)
        if accumulatedTime >= measureInterval {
            let fps = Double(frameCount) / accumulatedTime
            
            // 判断是否卡顿 (保持原有邏輯)
            let isFrameDropped = fps < fpsThreshold
            
            // 🔧 直接通过回调通知 (解決實時更新問題)
            onFPSUpdate?(fps, isFrameDropped)
            
            // 重置计数器 (保持原有邏輯)
            resetFrameCount()
        }
    }
    
    private func resetFrameCount() {
        frameCount = 0
        accumulatedTime = 0
    }
    
    // MARK: - Deinitializer
    deinit {
        stopMonitoring()
    }
}
