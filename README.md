## 專案 description
📽️ [點我觀看操作影片 Demo](https://www.youtube.com/shorts/yJq1Qdl3SPM)

<img width="425" height="958" alt="不滾動" src="https://github.com/user-attachments/assets/77f3b798-a17b-48ca-a77c-62c3fb09f3c0" />
<img width="433" height="953" alt="有 FPS" src="https://github.com/user-attachments/assets/21d4427a-fd5f-4c9b-90c1-e01c92465b0c" />

### ✅ 已完成
#### 核心功能
1. 資料來源
- ✅ GET /matches: WebSocketDataSource 模擬 100 筆比賽資料
- ✅ GET /odds: 模擬初始賠率資料，包含 teamA/teamB 賠率

2. WebSocket 模擬
- ✅ 每秒推播 10 筆: WebSocketDataSource.observeOddsUpdates() 精確實現每秒 10 筆更新
- ✅ 指定 matchID 更新: 使用 MockData.getRandomOddsUpdate() 隨機選擇比賽更新

3. 畫面行為

- ✅ UITableView 展示: MatchListViewController + 自定義 MatchCell
- ✅ 時間排序: 按 startTime 升序排序（最近在上面）
- ✅ 即時更新: 只更新對應 cell，不整頁 reload
- ✅ 保持順暢: 實現批次更新 + FPS 監控，避免卡頓

4. Thread-safe 處理

- ✅ 資料一致性: 使用 @MainActor 確保 UI 更新在主線程
- ✅ 避免 race condition: CacheService 使用 concurrent queue + barrier

#### 架構要求 
1. MVVM 架構

- ✅ Model: Match, Odds, MatchWithOdds
- ✅ View: MatchListViewController, MatchCell
- ✅ ViewModel: MatchListViewModel 使用 @Published 屬性

2. Swift Concurrency

- ✅ AsyncStream: WebSocket 模擬
- ✅ async/await: 所有異步操作
- ✅ Task.detached: 背景數據處理

3. Clean Architecture
- ✅ Presenter Layer: MatchListViewController, MatchListViewModel, MatchCell
- ✅ Domain Layer: GetMatchesUseCase, GetOddsUseCase, BatchUpdateUseCase
- ✅ Data Layer: MatchRepository, WebSocketDataSource, CacheService

#### 加分項目
1. WebSocket 斷線重連
- ✅ 自動重連: MatchListViewModel.retryConnection()

2. 快取機制
- ✅ Memory Cache: CacheService
- ✅ TTL 支持: matches (5分鐘), odds (1分鐘)
- ✅ Thread-safe: concurrent queue + barrier flags

#### 測試

- ✅ CacheServiceTests: 快取功能測試
- ✅ MatchRepositoryTests: Repository 層測試
- ✅ GetMatchesUseCaseTests & GetOddsUseCaseTests: Use Case 測試
- ✅ MockMatchDataSourceTests: 數據源測試
- ✅ BatchUpdateUseCaseTests: 批次更新測試

#### 性能監控 
- ✅ FPSMonitor: 實時 FPS 監控
- ✅ PerformanceMetrics: 性能指標收集


實作了一個即時賽事賠率展示系統，支援 100 筆比賽資料的即時更新，具備以下核心功能：
- **即時賠率更新**：模擬每秒 10 筆賠率推播，確保 UI 即時反映最新數據
- **智慧滾動優化**：採用批次刷新資料到 UI 機制，在用戶滾動時累積資料更新，停止滾動時批次處理資料刷新，並確保只更新出現在畫面上的 match
- **FPS 監控**：整合 CADisplayLink 實時監控滾動性能
- **cache 機制**：實現記憶體快取，提升資料存取效率，並確保 thread safe
- **retry 機制**：自動重連機制

### 採用技術
- 採用 Clean Architecture 配合 MVVM 模式
- 使用 Swift Concurrency 處理非同步操作
- 實現 Thread-Safe 的資料存取機制
- 整合性能監控與優化策略

### HLV UML
<img width="1482" height="841" alt="截圖 2025-08-10 上午9 46 26" src="https://github.com/user-attachments/assets/88b1529f-9228-457a-81a6-cd5ad5ab0b2d" />

👉 [UML draw.io](https://drive.google.com/file/d/1VmSsyvhrFcLlnGMacoGkU2xpQdiYWHk-/view?usp=sharing)

### 關鍵元件說明

#### 1. **PerformanceMetrics**
負責收集和分析應用程式性能數據：
- 記錄 UI 更新耗時
- 追蹤 FPS 變化
- 監控滾動會話統計
- 提供性能建議

#### 2. **FPSMonitor + CADisplayLink**
使用 CADisplayLink 精確監控渲染性能：
```swift
private func displayLinkCallback(_ displayLink: CADisplayLink) {
   let currentTime = displayLink.timestamp
   let deltaTime = currentTime - lastTimestamp
   
   // 檢測掉幀
   let expectedFrameTime = 1.0 / targetFPS
   if deltaTime > expectedFrameTime * 1.5 {
       droppedFrames += 1
   }
   
   // 計算 FPS 並通知代理
   fps = Double(frameCount) / accumulatedTime
   delegate?.fpsMonitor(self, didUpdateFPS: fps, isDropped: fps < fpsThreshold)
}
```

#### 3. **BatchUpdateUseCase**
核心批次更新邏輯：
- **滾動中**：累積賠率更新，避免頻繁 UI 重繪
- **停止滾動**：批次處理累積的更新，確保數據一致性

## ⚡ Swift Concurrency 使用場景

### 1. **非同步資料載入**
```swift
func performDataLoading() async {
   do {
       // 並行載入比賽和賠率資料
       let (matchesResult, oddsResult) = try await loadMatchesAndOdds()
       
       // 背景處理資料合併
       let processedData = await processMatchesWithOdds(matches: matchesResult, odds: oddsResult)
       
       // 更新資料模型
       await updateDataModel(with: processedData)
   } catch {
       await handleLoadingError(error)
   }
}
```
### 2. **AsyncStream 處理即時更新**
```swift
func observeOddsUpdates() -> AsyncStream<Odds> {
   return AsyncStream { continuation in
       let task = Task {
           while !Task.isCancelled {
               // 每秒推送 10 筆更新
               ...
           }
       }
       
       continuation.onTermination = { _ in
           task.cancel()
       }
   }
}
```
### 3. **Task.detached 背景處理**
```swift
func processMatchesWithOdds(matches: [Match], odds: [Odds]) async -> [Int: MatchWithOdds] {
   return await Task.detached(priority: .userInitiated) {
      // backgrounnd thread 處理生成 MatchWithOdds dictionary
      ...
   }.value
}
```
## 🔒 Thread-Safe 資料存取機制

### 1. **CacheService 的 Concurrent Queue**
- 採用 Concurrent Queue + barrier 實現多讀單寫的 thread safe cache
```swift
func get<T: Codable>(key: String) -> T? {
        return queue.sync {
            guard let item = cache[key],
                  item.expiryDate > Date() else {
                cache.removeValue(forKey: key)
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
        self.cache[key] = item
    }
}
```
### 2. **@MainActor 確保 UI 更新的執行緒安全**
```swift
@MainActor
class MatchListViewModel: ObservableObject {
   @Published private(set) var matchesWithOdds: [MatchWithOdds] = []
   @Published private(set) var isLoading = false
   
   func handleBatchOddsUpdate(_ updates: [Int: Odds]) {
       // 確保在主執行緒更新 UI 相關狀態
       updateInternalDataWithOdds(updates)
       ...
   }
}
```

## 🔄 UI 與 ViewModel 資料綁定

### 1. **Combine 資料流**
```swift
private func setupBindings() {
   // 監聽資料變化
   viewModel.$matchesWithOdds
       .receive(on: DispatchQueue.main)
       .sink { [weak self] matches in
           self?.handleMatchesUpdate(matches)
       }
       .store(in: &cancellables)
   
   // 批次更新回調
   viewModel.onBatchOddsUpdate = { [weak self] updates in
       self?.handleBatchOddsUpdate(updates)
   }
}
```

### 2. **智慧 UI 更新策略**
1. 只更新可見範圍內需要更新的 cell
2. 分批處理，避免一次性更新過多 cell
```swift
private func handleBatchOddsUpdate(_ updates: [Int: Odds]) {
   guard let visibleIndexPaths = tableView.indexPathsForVisibleRows else { return }
   
   var indexPathsToReload: [IndexPath] = []
   
   // 只更新可見範圍內需要更新的 cell
   for indexPath in visibleIndexPaths {
       let matchWithOdds = viewModel.matchesWithOdds[indexPath.row]
       if updates[matchWithOdds.match.matchID] != nil {
           indexPathsToReload.append(indexPath)
       }
   }
   
   // 分批處理，避免一次性更新過多 cell
   let batches = indexPathsToReload.chunked(into: maxBatchSize)
   for (index, batch) in batches.enumerated() {
       let delay = Double(index) * 0.03
       
       DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
           UIView.performWithoutAnimation {
               self.tableView.reloadRows(at: batch, with: .none)
           }
       }
   }
}
```

## 🚀 性能優化策略

### 1.滾動停止時才刷新 UI

專案使用 `BatchUpdateUseCase` 結合滾動狀態監測實現：

```swift
// 滾動狀態管理
func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
   setScrollingState(true)  // 開始滾動，切換到累積模式
}

func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
   setScrollingState(false)  // 滾動結束，處理累積的更新
}

private func setScrollingState(_ scrolling: Bool) {
   viewModel.setScrolling(scrolling)
   
   if scrolling {
       // 滾動中：啟動 FPS 監控，暫停 UI 更新
       ...
   } else {
       // 停止滾動：處理累積的更新，停止監控
       ...
       
       // 延遲停止監控，確保捕獲滾動結束的幀
       ...
   }
}
```

**BatchUpdateUseCase 中的滾動模式切換：**
```swift
@MainActor
func handleScrollingModeUpdate(_ odds: Odds) {
   // 滾動中：累積更新，不立即處理
   ...
}

@MainActor
func handleIdleModeUpdate(_ odds: Odds) {
   // 待機時：立即處理單個更新
   ...
}

@MainActor
func handleScrollingEnd() {
   // 滾動結束：批次處理累積的更新
   Task { @MainActor in
       try? await Task.sleep(nanoseconds: UInt64(Config.scrollEndDelay * 1_000_000_000))
       self.processPendingUpdatesImmediately()
   }
}
```

### 2. **CADisplayLink FPS 監控實現**

使用 CADisplayLink 精確監控滾動時的 FPS：

```swift
class FPSMonitor {
   private var displayLink: CADisplayLink?
   private var lastTimestamp: CFTimeInterval = 0
   private var frameCount: Int = 0
   private let targetFPS: Double = 60.0
   private let fpsThreshold: Double = 55.0
   
   func startMonitoring() {
       displayLink = CADisplayLink(target: self, selector: #selector(displayLinkCallback))
       displayLink?.preferredFramesPerSecond = 0  // 使用螢幕最大重新整理率
       
       // 關鍵：添加到 common modes，確保滾動時也能正常工作
       displayLink?.add(to: .main, forMode: .common)
   }
   
   @objc private func displayLinkCallback(_ displayLink: CADisplayLink) {
       
       // 檢測掉幀 - 如果幀間隔超過預期時間的 1.5 倍，認為是掉幀
       // 每秒計算一次 FPS
       ...
   }
   
   private func calculateFPS() {
       // 通知 delegate 並記錄性能數據
       ...
   }
}
```

**FPS 監控與性能反饋：**
```swift
extension MatchListViewController: FPSMonitorDelegate {
   func fpsMonitor(_ monitor: FPSMonitor, didUpdateFPS fps: Double, isDropped: Bool) {
       DispatchQueue.main.async {
           // 記錄 FPS 數據到 PerformanceMetrics
           self.performanceMetrics.recordFPS(fps)
           // 更新狀態標籤
           self.updateStatusLabels()
       }
   }
```

### 3. **PerformanceMetrics 性能分析**

```swift
class PerformanceMetrics {
       // calaulate session
       print("📊 滾動結束: 時長 \(session.duration)s, 平均FPS \(session.avgFPS)")
   }
}
```

### 4. **記憶體快取策略**
```swift
// 快取配置
func getMatches() async throws -> [Match] {
   if let cachedMatches: [Match] = cacheService.get(key: "matches") {
       return cachedMatches  // 5 分鐘快取
   }
   
   let matches = try await dataSource.fetchMatches()
   cacheService.set(key: "matches", value: matches, expiry: 300)
   return matches
}

func getOdds() async throws -> [Odds] {
   if let cachedOdds: [Odds] = cacheService.get(key: "odds") {
       return cachedOdds  // 1 分鐘快取
   }
   
   let odds = try await dataSource.fetchOdds()
   cacheService.set(key: "odds", value: odds, expiry: 60)
   return odds
}
}
```

## 🧪 測試覆蓋說明

### 測試架構
專案實現了完整的單元測試覆蓋，包含以下層級：

#### 1. **資料層測試**
- `CacheServiceTests`: 測試快取機制的設置、獲取、過期和清除
- `MatchRepositoryTests`: 測試資料倉庫的快取邏輯和資料來源整合
- `MockMatchDataSourceTests`: 測試模擬資料來源的行為

#### 2. **業務邏輯層測試**
- `GetMatchesUseCaseTests`: 測試比賽資料獲取用例
- `GetOddsUseCaseTests`: 測試賠率資料獲取用例
- `BatchUpdateUseCaseTests`: 測試批次更新邏輯的各種場景

#### 3. **關鍵測試場景**

**BatchUpdateUseCase 完整測試：**
```swift
@MainActor
func test_ComplexScrollingScenario_ShouldHandleCorrectly() async throws {
   // 測試滾動與待機模式切換
   batchUpdateUseCase.startBatchProcessing()
   
   // 待機模式：立即處理
   batchUpdateUseCase.handleOddsUpdate(idleOdds1)
   XCTAssertEqual(receivedBatchUpdates.count, 1)
   
   // 滾動模式：累積更新
   batchUpdateUseCase.setScrolling(true)
   batchUpdateUseCase.handleOddsUpdate(scrollOdds1)
   batchUpdateUseCase.handleOddsUpdate(scrollOdds2)
   
   // 停止滾動：批次處理
   batchUpdateUseCase.setScrolling(false)
   try await Task.sleep(nanoseconds: 300_000_000)
   
   XCTAssertEqual(receivedBatchUpdates.count, 2)
   XCTAssertEqual(receivedBatchUpdates[1].count, 2)
}
```

## Conclusion

### 技術成果
- ✅ **完整的 Clean Architecture 實現**
- ✅ **高效的批次更新機制**
- ✅ **精確的 FPS 監控系統**
- ✅ **Thread-Safe 的資料處理**
- ✅ **智慧的 UI 更新策略**
- ✅ **完善的單元測試覆蓋**

### 性能表現
- 支援每秒 10 筆高頻更新而不影響滾動流暢度
- FPS 維持在 60+ 的高水準
- 記憶體使用穩定且高效

### 可擴展性
- 每個 layer 間 follow dependency injection 和 dependency invertion 便於擴展和進行 unit tests
- 模組化設計易於擴展新功能
- Protocol-based 架構支援不同資料來源
- 完整的測試覆蓋確保代碼品質

### Memory Leaks 檢測
<img width="1195" height="360" alt="image" src="https://github.com/user-attachments/assets/2fc91c33-2703-45a2-ae64-4524cef809ff" />

#### 潛在問題分析
1. 由 Instrument Leaks 的截圖，可發現無 memory leak，但 All Heap & Allocation 存在一些問題，未來可以進一步進行優化
2. Persistent(長期存在的 objects): 38,741 個; Transient(已釋放的 objects): 502,458 個; Transient/Persistent = 13:1 (正常應為 2-3:1)。代表每 13 個 objects 中只有 1 個長期存在，系統需花費資源在頻繁內存分配/釋放
3. 推測 WebSocket 每秒會創建 10 個 objects，並於用完時拋棄; 且於 BatchUseCase 中，滾動時會創建並累積需更新的 objects，並於停止滾動時更新完後釋放這些 objects; 在一開始便直接載入 100 個 Matche objects

#### 改進方案
1. Object Pooling, 創建 MatchOddsPool，過重用對象而非重複創建銷毀，來減少內存分配開銷和垃圾回收壓力。 並搭配 auto realease pool 的機制，在 pool 達設定的 memory useage limit 時，使用 LRU strategy 進行 memory 的釋放
2. 可與後端討論採用分頁（pagination）機制，藉此減輕 client side 在載入大量資料時的負擔


### Future work
#### 目前的 FPSMonitor, PerformanceMetrics 同時負責監控、計算和回調通知，並由 ViewController 直接持有
- 違反了 Clean Architecture 的分層原則，未來需將 business logic 及 data source 抽離並封裝到 usecase layer 和 data layer。並將 UIKit 與 QuartzCore 等平台相關的依賴從 Domain Layer 中移除，以確保 UseCase 及 Data Layer 保持 Platform-independent。
- 並透過 ViewModel 負責管理與調度 UseCase，達成更清晰的分層與責任劃分

- 同時也需 Presenter Layer 創建 Adapter，將 FPSMonitorProvider 與 PerformanceMetricsProvider 實作於此層，這兩個 Provider 與平台相關（如 UIKit、QuartzCore 等），因此應由 Presenter Layer 依賴具體實作，並透過介面注入至 UseCase，讓 UseCase 僅依賴抽象，維持 Platform-independent 的特性(具體實作可以參考 `origin/feature/extract-usecase-from-FPSMonitor`，但因為還有 bug，所以還未 merge 回 master😅)
- 若視 FPSMonitor 及 PerformanceMetrics 為外部 service，也可以讓其與 ViewController 之間建立抽象層，並封裝它們的實作細節成 Swift Package
- 因已經定義 remote service 與 cache 的 abstracted layer，未來可依據需求決定其實作細節，並將這些實作封裝成獨立的 Swift Package，以達到模組化與依賴隔離的目的


### 感謝您辛苦 reviewe，有任何意見，都歡迎留言！

