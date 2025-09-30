import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Begin performance monitoring
        PerformanceMonitor.shared.beginAppLaunch()

        // Override point for customization after application launch.
        // Only create window for iOS 12 fallback (iOS 13+ uses SceneDelegate)
        if #available(iOS 13.0, *) {
            // Scene delegate handles window creation
        } else {
            window = UIWindow(frame: UIScreen.main.bounds)
            window?.rootViewController = ViewController()
            window?.makeKeyAndVisible()
        }

        // Defer non-critical initialization
        DispatchQueue.main.async {
            self.setupNonCriticalServices()
        }

        return true
    }

    private func setupNonCriticalServices() {
        // Setup analytics, crash reporting, etc. here
        // Currently empty but ready for future additions
    }

    // MARK: UISceneSession Lifecycle (iOS 13+)
    @available(iOS 13.0, *)
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    @available(iOS 13.0, *)
    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
    }
}