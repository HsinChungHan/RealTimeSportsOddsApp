//
//  SceneDelegate.swift
//  RealTimeSportsOddsApp
//
//  Created by Chung Han Hsin on 2025/8/3.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    
    var window: UIWindow?
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        // MARK: - 🚀 Setup Clean Architecture Dependencies
        
        // 1️⃣ Infrastructure Layer (Data Sources & Cache)
        let cacheService = CacheService()
        let dataSource = WebSocketDataSource()
        
        // 2️⃣ Repository Layer
        let repository = MatchRepository(dataSource: dataSource, cacheService: cacheService)
        
        // 3️⃣ Use Case Layer - Data Operations
        let getMatchesUseCase = GetMatchesUseCase(repository: repository)
        let getOddsUseCase = GetOddsUseCase(repository: repository)
        let observeOddsUpdatesUseCase = ObserveOddsUpdatesUseCase(repository: repository)
        
        // 4️⃣ Use Case Layer - Batch Processing
        let batchUpdateUseCase = BatchUpdateUseCase(
            observeOddsUpdatesUseCase: observeOddsUpdatesUseCase
        )
        
        // 🆕 5️⃣ Use Case Layer - Performance Monitoring
        let fpsProvider = UIKitFPSProvider()
        let fpsMonitorUseCase = FPSMonitorUseCase(fpsProvider: fpsProvider)
        
        // 6️⃣ Presentation Layer - ViewModel
        let viewModel = MatchListViewModel(
            getMatchesUseCase: getMatchesUseCase,
            getOddsUseCase: getOddsUseCase,
            batchUpdateUseCase: batchUpdateUseCase,
            fpsMonitorUseCase: fpsMonitorUseCase  // 🆕 注入 FPS Monitor UseCase
        )
        
        // 7️⃣ Presentation Layer - View Controller
        let viewController = MatchListViewController(viewModel: viewModel)
        let navigationController = UINavigationController(rootViewController: viewController)
        
        // 🎯 Configure Navigation Controller Appearance
        setupNavigationAppearance(navigationController)
        
        // 🪟 Setup Window
        window = UIWindow(windowScene: windowScene)
        window?.rootViewController = navigationController
        window?.makeKeyAndVisible()
        
        print("🎯 应用启动完成")
        print("   ├─ 数据源: WebSocket 模拟 (每秒10笔更新)")
        print("   ├─ 缓存: NSCache (比赛5分钟, 赔率1分钟)")
        print("   ├─ 批次处理: BatchUpdateUseCase (滚动优化)")
        print("   ├─ UI监控: FPSMonitorUseCase + 性能统计")  // 🆕 更新日誌
        print("   └─ 架构: Clean Architecture + MVVM")
    }
    
    // MARK: - UI Configuration
    private func setupNavigationAppearance(_ navigationController: UINavigationController) {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .systemBackground
        appearance.titleTextAttributes = [.foregroundColor: UIColor.label]
        
        navigationController.navigationBar.standardAppearance = appearance
        navigationController.navigationBar.scrollEdgeAppearance = appearance
        navigationController.navigationBar.prefersLargeTitles = false
    }
}
