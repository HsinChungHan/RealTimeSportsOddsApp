//
//  BatchUpdateUseCaseProtocol.swift
//  RealTimeSportsOddsApp
//
//  Created by Chung Han Hsin on 2025/8/6.
//

import Foundation

protocol BatchUpdateUseCaseProtocol {
    /// 开始批次更新处理
    func startBatchProcessing()
    
    /// 停止批次更新处理
    func stopBatchProcessing()
    
    /// 处理单个赔率更新
    func handleOddsUpdate(_ odds: Odds)
    
    /// 设置滚动状态
    func setScrolling(_ isScrolling: Bool)
    
    /// 设置批次更新回调
    func setBatchUpdateCallback(_ callback: @escaping ([Int: Odds]) -> Void)
    
    /// 获取统计信息
    var statisticsInfo: String { get }
}

