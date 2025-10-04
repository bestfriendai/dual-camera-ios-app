// Dual Camera App
import UIKit
import os.signpost

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    private let log = OSLog(subsystem: "com.dualcamera.app", category: "AppDelegate")

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let signpostID = OSSignpostID(log: log)
        os_signpost(.begin, log: log, name: "AppDelegate Launch", signpostID: signpostID)
        
        StartupOptimizer.shared.beginStartupOptimization()
        StartupOptimizer.shared.beginPhase(.appLaunch)
        
        Task(priority: .utility) {
            PerformanceMonitor.shared.beginAppLaunch()
            self.setupNonCriticalServices()
        }

        if #available(iOS 13.0, *) {
        } else {
            window = UIWindow(frame: UIScreen.main.bounds)
            window?.rootViewController = ViewController()
            window?.makeKeyAndVisible()
        }

        StartupOptimizer.shared.endPhase(.appLaunch)
        os_signpost(.end, log: log, name: "AppDelegate Launch", signpostID: signpostID)
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