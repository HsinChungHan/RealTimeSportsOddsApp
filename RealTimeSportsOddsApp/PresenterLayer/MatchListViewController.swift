//
//  MatchListViewController.swift
//  RealTimeSportsOddsApp
//
//  Created by Chung Han Hsin on 2025/8/5.
//

import UIKit
import Combine

class MatchListViewController: UIViewController {
    
    // MARK: - UI Components
    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 120
        tableView.separatorStyle = .singleLine
        tableView.backgroundColor = .systemBackground
        
        // 註冊 Cell
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
    
    private lazy var errorView: UIView = {
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.backgroundColor = .systemBackground
        containerView.isHidden = true
        
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.alignment = .center
        
        let errorLabel = UILabel()
        errorLabel.text = "載入失敗"
        errorLabel.font = .systemFont(ofSize: 18, weight: .medium)
        errorLabel.textColor = .systemRed
        errorLabel.textAlignment = .center
        
        let retryButton = UIButton(type: .system)
        retryButton.setTitle("重試", for: .normal)
        retryButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        retryButton.backgroundColor = .systemBlue
        retryButton.setTitleColor(.white, for: .normal)
        retryButton.layer.cornerRadius = 8
        retryButton.contentEdgeInsets = UIEdgeInsets(top: 12, left: 24, bottom: 12, right: 24)
        retryButton.addTarget(self, action: #selector(handleRetry), for: .touchUpInside)
        
        stackView.addArrangedSubview(errorLabel)
        stackView.addArrangedSubview(retryButton)
        containerView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor)
        ])
        
        return containerView
    }()
    
    // MARK: - Properties
    private let viewModel: MatchListViewModel
    private var cancellables = Set<AnyCancellable>()
    
    // 🚀 效能優化：記錄可見 cells 以避免不必要的更新
    private var visibleIndexPaths: Set<IndexPath> = []
    
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
        
        // 開始載入資料
        viewModel.loadData()
        
        print("🎯 ViewController 初始化完成")
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // 🐛 Debug: 檢查 frame 是否正確設置
        print("🔧 ViewDidLayoutSubviews - TableView Frame: \(tableView.frame)")
        print("🔧 ViewDidLayoutSubviews - TableView ContentSize: \(tableView.contentSize)")
        print("🔧 ViewDidLayoutSubviews - TableView isScrollEnabled: \(tableView.isScrollEnabled)")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // 重新連接 WebSocket（處理斷線重連）
        viewModel.retryConnection()
    }
    
    // MARK: - Setup Methods
    private func setupUI() {
        title = "即時賠率"
        view.backgroundColor = .systemBackground
        
        // 添加 Navigation Bar 按鈕
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .refresh,
            target: self,
            action: #selector(handleRefresh)
        )
        
        // 添加子視圖
        view.addSubview(tableView)
        view.addSubview(loadingIndicator)
        view.addSubview(errorView)
        
        // 添加下拉刷新
        tableView.refreshControl = refreshControl
        
        // 🚀 確保 tableView 可以滾動的設置
        tableView.isScrollEnabled = true
        tableView.showsVerticalScrollIndicator = true
        tableView.bounces = true
        
        // 設置約束
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            
            errorView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            errorView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            errorView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            errorView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        
        // 🐛 Debug: 輸出約束資訊
        print("🔧 TableView Frame: \(tableView.frame)")
        print("🔧 View Frame: \(view.frame)")
    }
    
    private func setupBindings() {
        // 🎯 監聽賠率資料變化
        viewModel.$matchesWithOdds
            .receive(on: DispatchQueue.main)
            .sink { [weak self] matches in
                self?.handleMatchesUpdate(matches)
            }
            .store(in: &cancellables)
        
        // 🎯 監聽載入狀態
        viewModel.$isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoading in
                self?.handleLoadingStateChange(isLoading)
            }
            .store(in: &cancellables)
        
        // 🎯 監聽錯誤訊息
        viewModel.$errorMessage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] errorMessage in
                self?.handleErrorStateChange(errorMessage)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Data Handling
    private func handleMatchesUpdate(_ matches: [MatchWithOdds]) {
        print("🔄 收到 \(matches.count) 筆賠率資料更新")
        
        // 🐛 Debug: 檢查資料和 tableView 狀態
        print("🔧 TableView numberOfRows: \(tableView.numberOfRows(inSection: 0))")
        print("🔧 New matches count: \(matches.count)")
        print("🔧 TableView Frame: \(tableView.frame)")
        print("🔧 TableView ContentSize: \(tableView.contentSize)")
        
        // 🚀 智能更新：只更新可見的 cells
        if !matches.isEmpty {
            // 如果是首次載入或資料筆數變化，重新載入整個 table
            if tableView.numberOfRows(inSection: 0) != matches.count {
                print("📊 資料筆數變化，重新載入 TableView")
                tableView.reloadData()
                
                // 🐛 強制立即更新 layout
                DispatchQueue.main.async {
                    self.tableView.layoutIfNeeded()
                    print("🔧 After reload - ContentSize: \(self.tableView.contentSize)")
                }
            } else {
                updateVisibleCells()
            }
        }
    }
    
    private func updateVisibleCells() {
        // 🚀 效能優化：只更新可見的 cells
        let visibleIndexPaths = tableView.indexPathsForVisibleRows ?? []
        
        for indexPath in visibleIndexPaths {
            if let cell = tableView.cellForRow(at: indexPath) as? MatchCell,
               indexPath.row < viewModel.matchesWithOdds.count {
                let matchWithOdds = viewModel.matchesWithOdds[indexPath.row]
                
                // 使用動畫更新賠率
                UIView.transition(with: cell, duration: 0.2, options: .transitionCrossDissolve) {
                    cell.configure(with: matchWithOdds)
                }
            }
        }
        
        print("⚡ 更新了 \(visibleIndexPaths.count) 個可見 cells")
    }
    
    private func handleLoadingStateChange(_ isLoading: Bool) {
        if isLoading {
            loadingIndicator.startAnimating()
            errorView.isHidden = true
        } else {
            loadingIndicator.stopAnimating()
            refreshControl.endRefreshing()
        }
    }
    
    private func handleErrorStateChange(_ errorMessage: String?) {
        if let errorMessage = errorMessage {
            print("❌ 顯示錯誤：\(errorMessage)")
            errorView.isHidden = false
            tableView.isHidden = true
        } else {
            errorView.isHidden = true
            tableView.isHidden = false
        }
    }
    
    // MARK: - Actions
    @objc private func handleRefresh() {
        print("🔄 手動刷新資料")
        viewModel.loadData()
    }
    
    @objc private func handleRetry() {
        print("🔄 重試載入")
        viewModel.loadData()
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
        
        // TODO: 可以在這裡實作比賽詳情頁面
    }
    
    // 🚀 效能優化：追蹤可見 cells
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        visibleIndexPaths.insert(indexPath)
    }
    
    func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        visibleIndexPaths.remove(indexPath)
    }
}
