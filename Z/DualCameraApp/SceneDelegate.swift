// Dual Camera App
import UIKit
import os.signpost

@available(iOS 13.0, *)
class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    private let log = OSLog(subsystem: "com.dualcamera.app", category: "SceneDelegate")

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        let signpostID = OSSignpostID(log: log)
        os_signpost(.begin, log: log, name: "Scene Connection", signpostID: signpostID)
        StartupOptimizer.shared.beginPhase(.uiInitialization)
        
        window = UIWindow(windowScene: windowScene)
        
        let placeholderVC = UIViewController()
        placeholderVC.view.backgroundColor = .black
        let activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.color = .white
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        placeholderVC.view.addSubview(activityIndicator)
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: placeholderVC.view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: placeholderVC.view.centerYAnchor)
        ])
        activityIndicator.startAnimating()
        
        window?.rootViewController = placeholderVC
        window?.makeKeyAndVisible()
        
        Task(priority: .userInitiated) {
            let viewController = ViewController()
            await MainActor.run {
                UIView.transition(with: self.window!, duration: 0.2, options: .transitionCrossDissolve, animations: {
                    self.window?.rootViewController = viewController
                }, completion: nil)
                StartupOptimizer.shared.endPhase(.uiInitialization)
                PerformanceMonitor.shared.endAppLaunch()
                os_signpost(.end, log: self.log, name: "Scene Connection", signpostID: signpostID)
                print("⏱️ SceneDelegate: Scene connection complete")
            }
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
    }
}