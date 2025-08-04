//
//  CacheServiceTests.swift
//  RealTimeSportsOddsAppTests
//
//  Created by Chung Han Hsin on 2025/8/4.
//

import XCTest
@testable import RealTimeSportsOddsApp

final class CacheServiceTests: XCTestCase {
    var cacheService: CacheService!

    override func setUp() {
        super.setUp()
        cacheService = CacheService()
    }

    override func tearDown() {
        cacheService = nil
        super.tearDown()
    }

    struct DummyData: Codable, Equatable {
        let id: Int
        let name: String
    }

    func testSetAndGet() {
        let key = "testKey"
        let value = DummyData(id: 1, name: "Test")
        
        cacheService.set(key: key, value: value, expiry: 5) // 5 秒
        
        /*
         set() 是非同步的（queue.async(flags: .barrier)）
         所以要用 DispatchQueue.asyncAfter 或 XCTestExpectation 稍作等待，否則 .get() 會拿不到資料
         */
        let expectation = expectation(description: "Wait for async set")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
            if let result: DummyData = self.cacheService.get(key: key) {
                XCTAssertEqual(result, value)
            } else {
                XCTFail("Should have retrieved cached value")
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    func testExpiry() {
        let key = "expireKey"
        let value = DummyData(id: 2, name: "Expiring")

        cacheService.set(key: key, value: value, expiry: 0.2)

        let expectation = expectation(description: "Wait for expiry")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.3) {
            let result: DummyData? = self.cacheService.get(key: key)
            XCTAssertNil(result, "Cached value should have expired")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    func testRemove() {
        let key = "removeKey"
        let value = DummyData(id: 3, name: "ToRemove")

        cacheService.set(key: key, value: value, expiry: 10)

        let expectation = expectation(description: "Wait for async remove")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
            self.cacheService.remove(key: key)

            DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
                let result: DummyData? = self.cacheService.get(key: key)
                XCTAssertNil(result, "Value should have been removed")
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 1.0)
    }

    func testClear() {
        cacheService.set(key: "key1", value: DummyData(id: 1, name: "A"), expiry: 10)
        cacheService.set(key: "key2", value: DummyData(id: 2, name: "B"), expiry: 10)

        let expectation = expectation(description: "Wait for async clear")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) {
            self.cacheService.clear()

            DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
                let value1: DummyData? = self.cacheService.get(key: "key1")
                let value2: DummyData? = self.cacheService.get(key: "key2")

                XCTAssertNil(value1)
                XCTAssertNil(value2)

                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 1.0)
    }
}

