//
//  PerformanceMetrics.swift
//  RealTimeSportsOddsApp
//
//  Created by Chung Han Hsin on 2025/8/6.
//

import Foundation
import QuartzCore

// MARK: - Performance Metrics Class
class PerformanceMetrics {
    private var updateDurations: [TimeInterval] = []
    private var fpsValues: [Double] = []
    private var scrollSessions: [ScrollSession] = []
    private var frameDropCount = 0
    private var currentScrollSession: ScrollSession?
    
    struct ScrollSession {
        let startTime: TimeInterval
        var endTime: TimeInterval?
        var minFPS: Double = 60.0
        var maxFPS: Double = 0.0
        var avgFPS: Double = 0.0
        var frameDrops: Int = 0
        
        var duration: TimeInterval {
            return (endTime ?? CACurrentMediaTime()) - startTime
        }
    }
    
    func startScrollSession() {
        currentScrollSession = ScrollSession(startTime: CACurrentMediaTime())
    }
    
    func endScrollSession() {
        guard var session = currentScrollSession else { return }
        
        session.endTime = CACurrentMediaTime()
        
        // 計算會話統計
        if !fpsValues.isEmpty {
            session.minFPS = fpsValues.min() ?? 60.0
            session.maxFPS = fpsValues.max() ?? 0.0
            session.avgFPS = fpsValues.reduce(0, +) / Double(fpsValues.count)
            session.frameDrops = frameDropCount
        }
        
        scrollSessions.append(session)
        currentScrollSession = nil
        
        // 清空當前會話數據
        fpsValues.removeAll()
        frameDropCount = 0
        
        print("📊 滾動會話結束: 時長 \(String(format: "%.2f", session.duration))s, 平均FPS \(String(format: "%.1f", session.avgFPS))")
    }
    
    func recordUpdateDuration(_ duration: TimeInterval) {
        updateDurations.append(duration)
        
        // 保持最近 100 次記錄
        if updateDurations.count > 100 {
            updateDurations.removeFirst()
        }
    }
    
    func recordFPS(_ fps: Double) {
        fpsValues.append(fps)
        
        // 更新當前會話
        if var session = currentScrollSession {
            session.minFPS = min(session.minFPS, fps)
            session.maxFPS = max(session.maxFPS, fps)
            currentScrollSession = session
        }
    }
    
    func recordFrameDrop() {
        frameDropCount += 1
    }
    
    var averageUpdateDuration: TimeInterval {
        guard !updateDurations.isEmpty else { return 0 }
        return updateDurations.reduce(0, +) / Double(updateDurations.count)
    }
    
    var summary: String {
        let avgDuration = averageUpdateDuration * 1000 // Convert to ms
        let totalSessions = scrollSessions.count
        let avgSessionFPS = scrollSessions.isEmpty ? 0 : scrollSessions.map { $0.avgFPS }.reduce(0, +) / Double(totalSessions)
        
        return String(format: "平均更新: %.2fms | 平均FPS: %.1f",
                      avgDuration, avgSessionFPS)
    }
    
    func reset() {
        updateDurations.removeAll()
        fpsValues.removeAll()
        scrollSessions.removeAll()
        frameDropCount = 0
        currentScrollSession = nil
    }
}
