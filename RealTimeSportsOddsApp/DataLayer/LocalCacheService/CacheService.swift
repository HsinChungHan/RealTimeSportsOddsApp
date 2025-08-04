//
//  CacheService.swift
//  RealTimeSportsOddsApp
//
//  Created by Chung Han Hsin on 2025/8/3.
//

import Foundation
/*
 使用 NSCache 儲存資料於 RAM 中。
 每筆資料有 expiryDate，自動過期移除
 */
// Can move to an independant Swift Package
class CacheService: CacheServiceProtocol {
    private let cache = NSCache<NSString, CacheItem>()
    private let queue = DispatchQueue(label: "cache.queue", attributes: .concurrent)
    
    private class CacheItem {
        let data: Data
        let expiryDate: Date
        
        init(data: Data, expiryDate: Date) {
            self.data = data
            self.expiryDate = expiryDate
        }
    }
    
    func get<T: Codable>(key: String) -> T? {
        return queue.sync {
            guard let item = cache.object(forKey: NSString(string: key)),
                  item.expiryDate > Date() else {
                cache.removeObject(forKey: NSString(string: key))
                return nil
            }
            
            return try? JSONDecoder().decode(T.self, from: item.data)
        }
    }
    
    func set<T: Codable>(key: String, value: T, expiry: TimeInterval) {
        queue.async(flags: .barrier) {
            guard let data = try? JSONEncoder().encode(value) else { return }
            let expiryDate = Date().addingTimeInterval(expiry)
            let item = CacheItem(data: data, expiryDate: expiryDate)
            self.cache.setObject(item, forKey: NSString(string: key))
        }
    }
    
    func remove(key: String) {
        queue.async(flags: .barrier) {
            self.cache.removeObject(forKey: NSString(string: key))
        }
    }
    
    func clear() {
        queue.async(flags: .barrier) {
            self.cache.removeAllObjects()
        }
    }
}
