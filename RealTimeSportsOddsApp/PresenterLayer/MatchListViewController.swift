//
//  MatchListViewController.swift
//  RealTimeSportsOddsApp
//
//  Created by Chung Han Hsin on 2025/8/5.
//


import UIKit
import Combine

// MARK: - Enhanced MatchListViewController with FPS Monitoring
class MatchListViewController: UIViewController {
    
    // MARK: - UI Components (Same as original)
    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 120
        tableView.separatorStyle = .singleLine
        tableView.backgroundColor = .systemBackground
        tableView.register(MatchCell.self, forCellReuseIdentifier: MatchCell.identifier)
        return tableView
    }()
    
    private lazy var refreshControl: UIRefreshControl = {
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        return refreshControl
    }()
    
    private lazy var loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.hidesWhenStopped = true
        return indicator
    }()
    
    // 🆕 增強的狀態監控容器 - 支持雙行顯示
    private lazy var statusContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .systemBackground.withAlphaComponent(0.95)
        view.layer.cornerRadius = 8
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 1)
        view.layer.shadowOpacity = 0.1
        view.layer.shadowRadius = 2
        return view
    }()
    
    // 🆕 第一行：基本狀態信息
    private lazy var statusLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .label
        label.text = "狀態: 待機 | 已更新 odds: 0 | Cell重載: 0"
        label.textAlignment = .center
        return label
    }()
    
    // 🆕 第二行：FPS 監控信息
    private lazy var fpsLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 12, weight: .regular)
        label.textColor = .secondaryLabel
        label.text = "FPS 監控: 待機狀態"
        label.textAlignment = .center
        return label
    }()
    
    // MARK: - Properties
    private let viewModel: MatchListViewModel
    private var cancellables = Set<AnyCancellable>()
    
    // 🚀 FPS 監控
    private let fpsMonitor = FPSMonitor()
    
    // 🚀 滾動狀態追蹤
    private var isUserScrolling = false
    private var scrollEndTimer: Timer?
    
    // 🎯 批次更新管理
    private let maxBatchSize = 15
    
    // 📊 效能統計
    private var cellReloadsCount = 0
    
    // 🎯 狀態更新計時器
    private var statusUpdateTimer: Timer?
    
    // 📊 性能數據收集
    private var performanceMetrics = PerformanceMetrics()
    
    // MARK: - Lifecycle
    init(viewModel: MatchListViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupBindings()
        setupFPSMonitor()
        startStatusUpdater()
        
        viewModel.loadData()
        
        print("🎯 Enhanced MatchListViewController 初始化完成 (含 FPS 監控)")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel.retryConnection()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopStatusUpdater()
        fpsMonitor.stopMonitoring()
    }
    
    // MARK: - Setup Methods
    private func setupUI() {
        title = "即時賠率 (FPS Monitor)"
        view.backgroundColor = .systemBackground
        
        // 🆕 添加調試按鈕
        setupNavigationBar()
        
        // 添加子視圖
        view.addSubview(tableView)
        view.addSubview(loadingIndicator)
        view.addSubview(statusContainerView)
        
        // 🆕 設置雙行狀態標籤
        setupStatusLabels()
        
        tableView.refreshControl = refreshControl
        setupConstraints()
    }
    
    private func setupNavigationBar() {
        let refreshButton = UIBarButtonItem(
            barButtonSystemItem: .refresh,
            target: self,
            action: #selector(handleRefresh)
        )
        
        let debugButton = UIBarButtonItem(
            title: "Debug",
            style: .plain,
            target: self,
            action: #selector(showPerformanceReport)
        )
        
        navigationItem.rightBarButtonItems = [refreshButton, debugButton]
    }
    
    // 🆕 設置雙行狀態監控標籤
    private func setupStatusLabels() {
        statusContainerView.addSubview(statusLabel)
        statusContainerView.addSubview(fpsLabel)
        
        NSLayoutConstraint.activate([
            // 第一行：基本狀態
            statusLabel.topAnchor.constraint(equalTo: statusContainerView.topAnchor, constant: 8),
            statusLabel.leadingAnchor.constraint(equalTo: statusContainerView.leadingAnchor, constant: 16),
            statusLabel.trailingAnchor.constraint(equalTo: statusContainerView.trailingAnchor, constant: -16),
            
            // 第二行：FPS 信息
            fpsLabel.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 4),
            fpsLabel.leadingAnchor.constraint(equalTo: statusContainerView.leadingAnchor, constant: 16),
            fpsLabel.trailingAnchor.constraint(equalTo: statusContainerView.trailingAnchor, constant: -16),
            fpsLabel.bottomAnchor.constraint(equalTo: statusContainerView.bottomAnchor, constant: -8)
        ])
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Status Container
            statusContainerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            statusContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            statusContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            // TableView
            tableView.topAnchor.constraint(equalTo: statusContainerView.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            
            // Loading Indicator
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    // 🆕 設置 FPS 監控
    private func setupFPSMonitor() {
        fpsMonitor.delegate = self
    }
    
    private func setupBindings() {
        // 監聽數據變化
        viewModel.$matchesWithOdds
            .receive(on: DispatchQueue.main)
            .sink { [weak self] matches in
                self?.handleMatchesUpdate(matches)
            }
            .store(in: &cancellables)
        
        viewModel.$isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoading in
                self?.handleLoadingStateChange(isLoading)
            }
            .store(in: &cancellables)
        
        viewModel.$errorMessage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] errorMessage in
                self?.handleErrorStateChange(errorMessage)
            }
            .store(in: &cancellables)
        
        // 批次更新回調
        viewModel.onBatchOddsUpdate = { [weak self] updates in
            self?.handleBatchOddsUpdate(updates)
        }
    }
    
    // 🎯 啓動狀態更新計時器
    private func startStatusUpdater() {
        statusUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.updateStatusLabels()
        }
    }
    
    private func stopStatusUpdater() {
        statusUpdateTimer?.invalidate()
        statusUpdateTimer = nil
    }
    
    // MARK: - Data Handling
    private func handleMatchesUpdate(_ matches: [MatchWithOdds]) {
        print("🔄 收到數據更新：\(matches.count) 筆")
        
        if tableView.numberOfRows(inSection: 0) != matches.count {
            print("📊 數據筆數變化，重新加載 TableView")
            tableView.reloadData()
        }
        
        updateStatusLabels()
    }
    
    // 🚀 核心方法：處理批次賠率更新
    private func handleBatchOddsUpdate(_ updates: [Int: Odds]) {
        let startTime = CACurrentMediaTime()
        
        print("⚡ 收到批次更新：\(updates.count) 筆賠率")
        
        guard let visibleIndexPaths = tableView.indexPathsForVisibleRows else {
            print("📱 沒有可見的 cells，跳過更新")
            return
        }
        
        var indexPathsToReload: [IndexPath] = []
        
        for indexPath in visibleIndexPaths {
            guard indexPath.row < viewModel.matchesWithOdds.count else { continue }
            
            let matchWithOdds = viewModel.matchesWithOdds[indexPath.row]
            if updates[matchWithOdds.match.matchID] != nil {
                indexPathsToReload.append(indexPath)
            }
        }
        
        guard !indexPathsToReload.isEmpty else {
            print("📱 可見範圍內沒有需要更新的 cells")
            return
        }
        
        print("🔄 更新 \(indexPathsToReload.count) 個可見 cells")
        
        // 分批處理
        let batches = indexPathsToReload.chunked(into: maxBatchSize)
        
        for (index, batch) in batches.enumerated() {
            let delay = Double(index) * 0.03
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                UIView.performWithoutAnimation {
                    self.tableView.reloadRows(at: batch, with: .none)
                }
                
                self.cellReloadsCount += batch.count
                
                if index == batches.count - 1 {
                    let endTime = CACurrentMediaTime()
                    let updateDuration = endTime - startTime
                    
                    // 📊 記錄性能數據
                    self.performanceMetrics.recordUpdateDuration(updateDuration)
                    
                    self.updateStatusLabels()
                }
            }
        }
    }
    
    private func handleLoadingStateChange(_ isLoading: Bool) {
        if isLoading {
            loadingIndicator.startAnimating()
        } else {
            loadingIndicator.stopAnimating()
            refreshControl.endRefreshing()
        }
    }
    
    private func handleErrorStateChange(_ errorMessage: String?) {
        if let errorMessage = errorMessage {
            print("❌ 顯示錯誤：\(errorMessage)")
        }
    }
    
    // 📊 更新狀態標籤 (雙行版本)
    private func updateStatusLabels() {
        DispatchQueue.main.async {
            self.updateBasicStatusLabel()
            self.updateFPSStatusLabel()
        }
    }
    
    // 🆕 更新基本狀態標籤
    private func updateBasicStatusLabel() {
        let statistics = viewModel.statisticsInfo
        let totalReceived = extractTotalReceived(from: statistics)
        
        let scrollingStatus = isUserScrolling ? "滾動中" : "待機"
        let statusText = "狀態: \(scrollingStatus) | 已更新 odds: \(totalReceived) | Cell重載: \(cellReloadsCount)"
        
        let attributedText = NSMutableAttributedString(string: statusText)
        
        // 設置狀態顏色
        let statusColor: UIColor = isUserScrolling ? .systemOrange : .systemGreen
        if let statusRange = statusText.range(of: scrollingStatus) {
            let nsRange = NSRange(statusRange, in: statusText)
            attributedText.addAttribute(.foregroundColor, value: statusColor, range: nsRange)
        }
        
        statusLabel.attributedText = attributedText
    }
    
    // 🆕 更新 FPS 狀態標籤
    private func updateFPSStatusLabel() {
        if isUserScrolling && fpsMonitor.isMonitoring {
            let fps = fpsMonitor.currentFPS
            let fpsStats = fpsMonitor.statisticsInfo
            let avgUpdateTime = performanceMetrics.averageUpdateDuration
            
            let fpsText = String(format: "FPS 監控: %@", fpsStats)
            
            let attributedText = NSMutableAttributedString(string: fpsText)
            
            // 根據 FPS 設置顏色
            let fpsColor: UIColor
            if fps >= 55 {
                fpsColor = .systemGreen
            } else if fps >= 30 {
                fpsColor = .systemOrange
            } else {
                fpsColor = .systemRed
            }
            
            // 設置 FPS 數值顏色
            let fpsValueText = String(format: "%.1f", fps)
            if let fpsRange = fpsText.range(of: fpsValueText) {
                let nsRange = NSRange(fpsRange, in: fpsText)
                attributedText.addAttribute(.foregroundColor, value: fpsColor, range: nsRange)
                attributedText.addAttribute(.font, value: UIFont.systemFont(ofSize: 12, weight: .bold), range: nsRange)
            }
            
            fpsLabel.attributedText = attributedText
        } else {
            fpsLabel.text = "FPS 監控: 待機狀態"
            fpsLabel.textColor = .secondaryLabel
        }
    }
    
    // 🔧 從統計字串中提取總接收數量
    private func extractTotalReceived(from statistics: String) -> Int {
        let components = statistics.components(separatedBy: " | ")
        for component in components {
            if component.hasPrefix("接收: ") {
                let countStr = component.replacingOccurrences(of: "接收: ", with: "")
                return Int(countStr) ?? 0
            }
        }
        return 0
    }
    
    // MARK: - Scrolling State Management with FPS
    
    // 🎯 滾動狀態管理（集成 FPS 監控）
    private func setScrollingState(_ scrolling: Bool) {
        guard isUserScrolling != scrolling else { return }
        
        isUserScrolling = scrolling
        
        // 通知 ViewModel 滾動狀態變化
        viewModel.setScrolling(scrolling)
        
        if scrolling {
            print("📱 開始滾動 - 啓動 FPS 監控")
            fpsMonitor.startMonitoring()
            performanceMetrics.startScrollSession()
            
            scrollEndTimer?.invalidate()
        } else {
            print("📱 停止滾動 - 延遲停止 FPS 監控")
            performanceMetrics.endScrollSession()
            
            // 延遲停止監控，確保捕獲滾動結束的幀
            scrollEndTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
                self?.fpsMonitor.stopMonitoring()
                print("🛑 FPS 監控已停止")
            }
        }
        
        updateStatusLabels()
    }
    
    // MARK: - Actions
    @objc private func handleRefresh() {
        print("🔄 手動刷新數據")
        
        // 重置統計數據
        cellReloadsCount = 0
        performanceMetrics.reset()
        
        viewModel.loadData()
    }
    
    @objc private func showPerformanceReport() {
        let report = generatePerformanceReport()
        print(report)
        
        // 顯示性能報告 Alert
        let alert = UIAlertController(
            title: "性能分析報告",
            message: report,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "確定", style: .default))
        present(alert, animated: true)
    }
    
    // 📊 生成性能報告
    private func generatePerformanceReport() -> String {
        let fpsStats = fpsMonitor.statisticsInfo
        let viewModelStats = viewModel.statisticsInfo
        let perfStats = performanceMetrics.summary
        
        return """
📊 性能分析報告
━━━━━━━━━━━━━━━━━━━━━━━━
🖼️ 渲染性能: \(fpsStats)
📡 數據處理: \(viewModelStats)
🔄 UI更新: Cell重載 \(cellReloadsCount) 次
⏱️ 更新性能: \(perfStats)
━━━━━━━━━━━━━━━━━━━━━━━━

💡 性能建議:
\(generatePerformanceSuggestions())
"""
    }
    
    // 💡 生成性能建議
    private func generatePerformanceSuggestions() -> String {
        var suggestions: [String] = []
        
        if fpsMonitor.currentFPS < 55 && fpsMonitor.isMonitoring {
            suggestions.append("• 檢測到幀率下降，建議減少批次更新頻率")
        }
        
        if performanceMetrics.averageUpdateDuration > 0.016 { // > 16ms
            suggestions.append("• UI更新耗時較長，建議優化Cell配置邏輯")
        }
        
        if cellReloadsCount > 1000 {
            suggestions.append("• Cell重載次數過多，建議優化更新策略")
        }
        
        if suggestions.isEmpty {
            suggestions.append("• 性能表現良好，繼續保持！")
        }
        
        return suggestions.joined(separator: "\n")
    }
    
    deinit {
        scrollEndTimer?.invalidate()
        stopStatusUpdater()
        fpsMonitor.stopMonitoring()
    }
}

// MARK: - UITableViewDataSource
extension MatchListViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.matchesWithOdds.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: MatchCell.identifier, for: indexPath) as? MatchCell else {
            return UITableViewCell()
        }
        
        let matchWithOdds = viewModel.matchesWithOdds[indexPath.row]
        cell.configure(with: matchWithOdds)
        
        return cell
    }
}

// MARK: - UITableViewDelegate
extension MatchListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let matchWithOdds = viewModel.matchesWithOdds[indexPath.row]
        print("🎯 選擇了比賽：\(matchWithOdds.match.teamA) vs \(matchWithOdds.match.teamB)")
    }
    
    // 🚀 關鍵：滾動狀態監聽（集成 FPS 監控）
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        setScrollingState(true)
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            setScrollingState(false)
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        setScrollingState(false)
    }
}

// MARK: - FPSMonitorDelegate
extension MatchListViewController: FPSMonitorDelegate {
    func fpsMonitor(_ monitor: FPSMonitor, didUpdateFPS fps: Double, isDropped: Bool) {
        DispatchQueue.main.async {
            // 記錄 FPS 數據
            self.performanceMetrics.recordFPS(fps)
            
            // 更新狀態標籤
            self.updateStatusLabels()
            
            // 如果檢測到嚴重卡頓，採取優化措施
            if isDropped && fps < 30.0 {
                print("🚨 嚴重卡頓警告: FPS = \(String(format: "%.1f", fps))")
                self.handleSevereFrameDrop()
            }
        }
    }
    
    // 🚨 處理嚴重掉幀
    private func handleSevereFrameDrop() {
        print("🔧 啓動性能保護模式")
        
        // 可以通知 ViewModel 啓用性能模式
        // viewModel.enablePerformanceMode(true)
        
        // 或者臨時增加更新間隔
        performanceMetrics.recordFrameDrop()
    }
}

// MARK: - Array Extension for Batching
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
