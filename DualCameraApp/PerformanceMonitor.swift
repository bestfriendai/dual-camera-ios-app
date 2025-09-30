import Foundation
import os.signpost

class PerformanceMonitor {
    static let shared = PerformanceMonitor()
    
    private let log: OSLog
    private var appLaunchSignpostID: OSSignpostID?
    private var cameraSetupSignpostID: OSSignpostID?
    
    private init() {
        self.log = OSLog(subsystem: "com.dualcamera.app", category: "Performance")
    }
    
    func beginAppLaunch() {
        let signpostID = OSSignpostID(log: log)
        appLaunchSignpostID = signpostID
        os_signpost(.begin, log: log, name: "App Launch", signpostID: signpostID)
    }
    
    func endAppLaunch() {
        guard let signpostID = appLaunchSignpostID else { return }
        os_signpost(.end, log: log, name: "App Launch", signpostID: signpostID)
        appLaunchSignpostID = nil
    }
    
    func beginCameraSetup() {
        let signpostID = OSSignpostID(log: log)
        cameraSetupSignpostID = signpostID
        os_signpost(.begin, log: log, name: "Camera Setup", signpostID: signpostID)
    }
    
    func endCameraSetup() {
        guard let signpostID = cameraSetupSignpostID else { return }
        os_signpost(.end, log: log, name: "Camera Setup", signpostID: signpostID)
        cameraSetupSignpostID = nil
    }
    
    func logEvent(_ name: StaticString, _ message: String = "") {
        os_signpost(.event, log: log, name: name, "%{public}s", message)
    }
}

