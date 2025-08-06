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
        
        // 🚀 Setup dependencies
        let cacheService = CacheService()
        let dataSource = WebSocketDataSource()
        let repository = MatchRepository(dataSource: dataSource, cacheService: cacheService)
        
        let getMatchesUseCase = GetMatchesUseCase(repository: repository)
        let getOddsUseCase = GetOddsUseCase(repository: repository)
        let observeOddsUpdatesUseCase = ObserveOddsUpdatesUseCase(repository: repository)
        
        let viewModel = MatchListViewModel(
            getMatchesUseCase: getMatchesUseCase,
            getOddsUseCase: getOddsUseCase,
            observeOddsUpdatesUseCase: observeOddsUpdatesUseCase
        )
        
        // 🆕 使用增强版本的 ViewController (含 FPS 监控)
        let viewController = MatchListViewController(viewModel: viewModel)
        let navigationController = UINavigationController(rootViewController: viewController)
        
        // 🎯 配置 Navigation Controller 外观
        setupNavigationAppearance(navigationController)
        
        window = UIWindow(windowScene: windowScene)
        window?.rootViewController = navigationController
        window?.makeKeyAndVisible()
        
        print("🎯 App 启动完成 - 已启用 FPS 监控功能")
    }
    
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
