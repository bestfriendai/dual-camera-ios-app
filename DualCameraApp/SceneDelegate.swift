// Dual Camera App
import UIKit

@available(iOS 13.0, *)
class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        print("✅ SceneDelegate: scene willConnectTo started")
        
        guard let windowScene = (scene as? UIWindowScene) else {
            print("❌ SceneDelegate: Failed to cast scene to UIWindowScene")
            return
        }
        
        print("✅ SceneDelegate: WindowScene obtained")

        // Create window and set root view controller (UIKit)
        window = UIWindow(windowScene: windowScene)
        print("✅ SceneDelegate: Window created")
        
        let viewController = ViewController()
        print("✅ SceneDelegate: ViewController created")
        
        window?.rootViewController = viewController
        print("✅ SceneDelegate: Root view controller set")
        
        window?.makeKeyAndVisible()
        print("✅ SceneDelegate: Window made key and visible")

        // End app launch performance measurement
        DispatchQueue.main.async {
            print("✅ SceneDelegate: Ending app launch performance measurement")
            PerformanceMonitor.shared.endAppLaunch()
        }
        
        print("✅ SceneDelegate: scene willConnectTo completed")
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