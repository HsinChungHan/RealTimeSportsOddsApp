//
//  CacheServiceProtocol.swift
//  RealTimeSportsOddsApp
//
//  Created by Chung Han Hsin on 2025/8/3.
//

import Foundation
protocol CacheServiceProtocol {
    func get<T: Codable>(key: String) -> T?
    func set<T: Codable>(key: String, value: T, expiry: TimeInterval)
    func remove(key: String)
    func clear()
}
