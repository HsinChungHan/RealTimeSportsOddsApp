//
//  FPSMonitorUseCaseProtocol.swift
//  RealTimeSportsOddsApp
//
//  Created by Chung Han Hsin on 2025/8/6.
//

import Foundation

protocol FPSMonitorUseCaseProtocol {
    var onFPSUpdate: ((Double, Bool) -> Void)? { get set }  // 🔧 改用閉包回調
    var currentFPS: Double { get }
    var statisticsInfo: String { get }
    var isMonitoring: Bool { get }
    
    func startMonitoring()
    func stopMonitoring()
}
