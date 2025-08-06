//
//  BatchUpdateUseCaseProtocol.swift
//  RealTimeSportsOddsApp
//
//  Created by Chung Han Hsin on 2025/8/6.
//

import Foundation

protocol BatchUpdateUseCaseProtocol {
    // 開始批次更新處理
    func startBatchProcessing()
    
    // 停止批次更新處理
    func stopBatchProcessing()
    
    // 處理單個賠率更新
    func handleOddsUpdate(_ odds: Odds)
    
    // 設置滾動狀態
    func setScrolling(_ isScrolling: Bool)
    
    // 設置批次更新 callback
    func setBatchUpdateCallback(_ callback: @escaping ([Int: Odds]) -> Void)
    
    // 獲取統計信息
    var statisticsInfo: String { get }
}

