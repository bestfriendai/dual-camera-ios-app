// Dual Camera App
import Foundation
import os.signpost
import UIKit
import Metal
import Swift

class PerformanceMonitor: @unchecked Sendable {
    nonisolated(unsafe) static let shared = PerformanceMonitor()
    
    private let log: OSLog
    private var appLaunchSignpostID: OSSignpostID?
    private var cameraSetupSignpostID: OSSignpostID?
    private var recordingSignpostID: OSSignpostID?
    private var frameProcessingSignpostID: OSSignpostID?
    private var photoCaptureSignpostID: OSSignpostID?
    private var frontPhotoCaptureSignpostID: OSSignpostID?
    private var backPhotoCaptureSignpostID: OSSignpostID?
    private var photoCaptureStartTime: CFTimeInterval = 0
    private var photoCaptureLatencies: [CFTimeInterval] = []
    private let maxPhotoCaptureLatencySamples = 50
    
    // Performance metrics
    private var frameCount: Int = 0
    private var lastFrameTime: CFTimeInterval = 0
    private var frameRateBuffer: InlineArray<60, CFTimeInterval> = InlineArray(repeating: 0.0)
    private var frameRateBufferCount: Int = 0
    private let maxFrameRateSamples = 60 // Increased for better accuracy
    
    // Memory monitoring
    private var memoryWarningCount: Int = 0
    private var lastMemoryCheck: CFTimeInterval = 0
    private var memoryPressureHandler: DispatchSourceMemoryPressure?
    
    // CPU monitoring
    private var cpuUsageBuffer: InlineArray<30, Double> = InlineArray(repeating: 0.0)
    private var cpuUsageBufferCount: Int = 0
    private let maxCpuSamples = 30
    private var lastCpuCheck: CFTimeInterval = 0
    private var cpuMonitoringTimer: Timer?
    
    // Thermal monitoring
    private var thermalState: ProcessInfo.ThermalState = .nominal
    private var thermalStateHistory: InlineArray<100, (Date, ProcessInfo.ThermalState)> = InlineArray(repeating: (Date.distantPast, .nominal))
    private var thermalStateHistoryCount: Int = 0
    private let maxThermalSamples = 100
    
    // GPU monitoring
    private var gpuUtilization: Double = 0.0
    private var gpuMemoryUsage: Double = 0.0
    private var metalDevice: MTLDevice?
    
    // Frame rate stabilization
    private var targetFrameRate: Double = 30.0
    private var frameDropCount: Int = 0
    private var frameDropHistory: [Date] = []
    private var frameRateVariance: Double = 0.0
    
    // Performance analytics
    private var performanceBottlenecks: [String: Int] = [:]
    private var performanceHistory: [String: [Double]] = [:]
    private let maxHistorySamples = 1000
    
    // Real-time metrics
    private var isMonitoring = false
    private var monitoringTimer: Timer?
    private let metricsUpdateInterval: TimeInterval = 0.5 // Update every 500ms
    
    // Battery monitoring
    private var batteryLevel: Float = 1.0
    private var batteryState: UIDevice.BatteryState = .unknown
    private var lastBatteryCheck: CFTimeInterval = 0
    
    private var isFullyInitialized = false
    
    private init() {
        self.log = OSLog(subsystem: "com.dualcamera.app", category: "Performance")
    }
    
    private func deferredInitialization() {
        guard !isFullyInitialized else { return }
        
        metalDevice = MTLCreateSystemDefaultDevice()
        setupMemoryMonitoring()
        setupThermalMonitoring()
        setupBatteryMonitoring()
        isFullyInitialized = true
        
        logEvent("Initialization", "Deferred initialization complete")
    }
    
    // MARK: - App Launch Performance
    func beginAppLaunch() {
        Task(priority: .utility) {
            self.deferredInitialization()
        }
        
        let signpostID = OSSignpostID(log: log)
        appLaunchSignpostID = signpostID
        os_signpost(.begin, log: log, name: "App Launch", signpostID: signpostID)
        logEvent("App Launch", "Started app launch monitoring")
    }
    
    func endAppLaunch() {
        guard let signpostID = appLaunchSignpostID else { return }
        os_signpost(.end, log: log, name: "App Launch", signpostID: signpostID)
        appLaunchSignpostID = nil
        logEvent("App Launch", "Completed app launch")
    }
    
    // MARK: - Camera Setup Performance
    func beginCameraSetup() {
        if !isFullyInitialized {
            deferredInitialization()
        }
        
        let signpostID = OSSignpostID(log: log)
        cameraSetupSignpostID = signpostID
        os_signpost(.begin, log: log, name: "Camera Setup", signpostID: signpostID)
        logEvent("Camera Setup", "Started camera setup")
    }
    
    func endCameraSetup() {
        guard let signpostID = cameraSetupSignpostID else { return }
        os_signpost(.end, log: log, name: "Camera Setup", signpostID: signpostID)
        cameraSetupSignpostID = nil
        logEvent("Camera Setup", "Completed camera setup")
    }
    
    // MARK: - Recording Performance
    func beginRecording() {
        let signpostID = OSSignpostID(log: log)
        recordingSignpostID = signpostID
        os_signpost(.begin, log: log, name: "Recording", signpostID: signpostID)
        frameCount = 0
        frameRateBufferCount = 0
        logEvent("Recording", "Started recording performance monitoring")
    }
    
    func endRecording() {
        guard let signpostID = recordingSignpostID else { return }
        os_signpost(.end, log: log, name: "Recording", signpostID: signpostID)
        recordingSignpostID = nil
        
        let avgFrameRate = calculateAverageFrameRate()
        logEvent("Recording", "Completed recording. Average frame rate: \(String(format: "%.1f", avgFrameRate)) fps")
    }
    
    // MARK: - Frame Processing Performance
    func beginFrameProcessing() {
        let signpostID = OSSignpostID(log: log)
        frameProcessingSignpostID = signpostID
        os_signpost(.begin, log: log, name: "Frame Processing", signpostID: signpostID)
    }
    
    func endFrameProcessing() {
        guard let signpostID = frameProcessingSignpostID else { return }
        os_signpost(.end, log: log, name: "Frame Processing", signpostID: signpostID)
        frameProcessingSignpostID = nil
    }
    
    // MARK: - Photo Capture Performance
    func beginPhotoCapture() {
        let signpostID = OSSignpostID(log: log)
        photoCaptureSignpostID = signpostID
        os_signpost(.begin, log: log, name: "Photo Capture", signpostID: signpostID)
        photoCaptureStartTime = CACurrentMediaTime()
        logEvent("Photo Capture", "Started photo capture")
    }
    
    func endPhotoCapture() {
        guard let signpostID = photoCaptureSignpostID else { return }
        let latency = CACurrentMediaTime() - photoCaptureStartTime
        os_signpost(.end, log: log, name: "Photo Capture", signpostID: signpostID, "Latency: %.2f ms", latency * 1000)
        photoCaptureSignpostID = nil
        
        photoCaptureLatencies.append(latency)
        if photoCaptureLatencies.count > maxPhotoCaptureLatencySamples {
            photoCaptureLatencies.removeFirst()
        }
        
        logEvent("Photo Capture", "Completed in \(String(format: "%.2f", latency * 1000)) ms")
        addToHistory("photoCaptureLatency", value: latency * 1000)
    }
    
    func beginFrontPhotoCapture() {
        let signpostID = OSSignpostID(log: log)
        frontPhotoCaptureSignpostID = signpostID
        os_signpost(.begin, log: log, name: "Front Photo Capture", signpostID: signpostID)
        photoCaptureStartTime = CACurrentMediaTime()
        logEvent("Photo Capture", "Started front camera photo capture")
    }
    
    func endFrontPhotoCapture() {
        guard let signpostID = frontPhotoCaptureSignpostID else { return }
        let latency = CACurrentMediaTime() - photoCaptureStartTime
        os_signpost(.end, log: log, name: "Front Photo Capture", signpostID: signpostID, "Latency: %.2f ms", latency * 1000)
        frontPhotoCaptureSignpostID = nil
        
        photoCaptureLatencies.append(latency)
        if photoCaptureLatencies.count > maxPhotoCaptureLatencySamples {
            photoCaptureLatencies.removeFirst()
        }
        
        logEvent("Photo Capture", "Front camera completed in \(String(format: "%.2f", latency * 1000)) ms")
        addToHistory("photoCaptureLatency", value: latency * 1000)
    }
    
    func beginBackPhotoCapture() {
        let signpostID = OSSignpostID(log: log)
        backPhotoCaptureSignpostID = signpostID
        os_signpost(.begin, log: log, name: "Back Photo Capture", signpostID: signpostID)
        photoCaptureStartTime = CACurrentMediaTime()
        logEvent("Photo Capture", "Started back camera photo capture")
    }
    
    func endBackPhotoCapture() {
        guard let signpostID = backPhotoCaptureSignpostID else { return }
        let latency = CACurrentMediaTime() - photoCaptureStartTime
        os_signpost(.end, log: log, name: "Back Photo Capture", signpostID: signpostID, "Latency: %.2f ms", latency * 1000)
        backPhotoCaptureSignpostID = nil
        
        photoCaptureLatencies.append(latency)
        if photoCaptureLatencies.count > maxPhotoCaptureLatencySamples {
            photoCaptureLatencies.removeFirst()
        }
        
        logEvent("Photo Capture", "Back camera completed in \(String(format: "%.2f", latency * 1000)) ms")
        addToHistory("photoCaptureLatency", value: latency * 1000)
    }
    
    func getAveragePhotoCaptureLatency() -> Double {
        guard !photoCaptureLatencies.isEmpty else { return 0 }
        let total = photoCaptureLatencies.reduce(0, +)
        return (total / Double(photoCaptureLatencies.count)) * 1000
    }
    
    func getPhotoCaptureStatistics() -> [String: Any] {
        guard !photoCaptureLatencies.isEmpty else {
            return [
                "average": 0.0,
                "min": 0.0,
                "max": 0.0,
                "median": 0.0,
                "sampleCount": 0
            ]
        }
        
        let latenciesInMs = photoCaptureLatencies.map { $0 * 1000 }
        let total = latenciesInMs.reduce(0, +)
        let average = total / Double(latenciesInMs.count)
        let min = latenciesInMs.min() ?? 0
        let max = latenciesInMs.max() ?? 0
        
        let sorted = latenciesInMs.sorted()
        let median: Double
        if sorted.count % 2 == 0 {
            median = (sorted[sorted.count / 2 - 1] + sorted[sorted.count / 2]) / 2
        } else {
            median = sorted[sorted.count / 2]
        }
        
        return [
            "average": average,
            "min": min,
            "max": max,
            "median": median,
            "sampleCount": photoCaptureLatencies.count
        ]
    }
    
    // MARK: - Frame Rate Monitoring
    func recordFrame() {
        let currentTime = CACurrentMediaTime()
        
        if lastFrameTime > 0 {
            let frameTime = currentTime - lastFrameTime
            
            if frameRateBufferCount < 60 {
                frameRateBuffer[frameRateBufferCount] = frameTime
                frameRateBufferCount += 1
            } else {
                for i in 0..<59 {
                    frameRateBuffer[i] = frameRateBuffer[i + 1]
                }
                frameRateBuffer[59] = frameTime
            }
            
            frameCount += 1
            
            // Check for frame drops
            let currentFrameRate = 1.0 / frameTime
            if currentFrameRate < targetFrameRate * 0.8 { // 80% of target
                frameDropCount += 1
                frameDropHistory.append(Date())
                recordBottleneck("Frame Drop")
                
                // Keep only recent frame drops
                if frameDropHistory.count > 100 {
                    frameDropHistory.removeFirst()
                }
            }
            
            // Calculate frame rate variance
            if frameRateBufferCount >= 10 {
                let frameRates = (0..<frameRateBufferCount).map { 1.0 / frameRateBuffer[$0] }
                let avgRate = frameRates.reduce(0, +) / Double(frameRates.count)
                let variance = frameRates.map { pow($0 - avgRate, 2) }.reduce(0, +) / Double(frameRates.count)
                frameRateVariance = sqrt(variance)
            }
            
            // Log frame rate every 30 frames
            if frameCount % 30 == 0 {
                let avgFrameRate = calculateAverageFrameRate()
                logEvent("Frame Rate", "\(String(format: "%.1f", avgFrameRate)) fps (variance: \(String(format: "%.2f", frameRateVariance)))")
                
                // Store in performance history
                addToHistory("frameRate", value: avgFrameRate)
                addToHistory("frameRateVariance", value: frameRateVariance)
            }
        }
        
        lastFrameTime = currentTime
    }
    
    private func calculateAverageFrameRate() -> Double {
        guard frameRateBufferCount > 0 else { return 0 }
        var sum: CFTimeInterval = 0
        for i in 0..<frameRateBufferCount {
            sum += frameRateBuffer[i]
        }
        let averageFrameTime = sum / CFTimeInterval(frameRateBufferCount)
        return 1.0 / averageFrameTime
    }
    
    func getFrameRateStability() -> Double {
        let avgFrameRate = calculateAverageFrameRate()
        guard avgFrameRate > 0 else { return 0 }
        
        // Calculate stability as percentage of frames within 10% of target
        let targetTolerance = targetFrameRate * 0.1
        let stableFrames = (0..<frameRateBufferCount).filter { abs(1.0 / frameRateBuffer[$0] - targetFrameRate) <= targetTolerance }.count
        return Double(stableFrames) / Double(frameRateBufferCount) * 100
    }
    
    // MARK: - Memory Monitoring
    private func setupMemoryMonitoring() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
        
        // Setup memory pressure monitoring
        memoryPressureHandler = DispatchSource.makeMemoryPressureSource(
            eventMask: [.warning, .critical],
            queue: DispatchQueue.global(qos: .utility)
        )
        
        memoryPressureHandler?.setEventHandler { [weak self] in
            guard let self = self else { return }
            
            let event = self.memoryPressureHandler?.mask
            if event?.contains(.warning) == true {
                self.logEvent("Memory Pressure", "System memory pressure warning")
                self.recordBottleneck("Memory Pressure")
            }
            
            if event?.contains(.critical) == true {
                self.logEvent("Memory Pressure", "System memory pressure critical")
                self.recordBottleneck("Critical Memory Pressure")
            }
        }
        
        memoryPressureHandler?.resume()
    }
    
    @objc private func handleMemoryWarning() {
        memoryWarningCount += 1
        logEvent("Memory Warning", "Received memory warning #\(memoryWarningCount)")
        recordBottleneck("Memory Warning")
        
        // Log current memory usage
        let currentMemory = getCurrentMemoryUsage()
        logEvent("Memory Usage", "Current: \(String(format: "%.1f", currentMemory)) MB")
        
        // Store in performance history
        addToHistory("memoryWarnings", value: Double(memoryWarningCount))
        addToHistory("memoryUsage", value: currentMemory)
    }
    
    // MARK: - Thermal Monitoring
    private func setupThermalMonitoring() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(thermalStateChanged),
            name: ProcessInfo.thermalStateDidChangeNotification,
            object: nil
        )
        
        // Initial thermal state
        thermalState = ProcessInfo.processInfo.thermalState
        thermalStateHistory[0] = (Date(), thermalState)
        thermalStateHistoryCount = 1
    }
    
    @objc private func thermalStateChanged() {
        let newThermalState = ProcessInfo.processInfo.thermalState
        
        if newThermalState != thermalState {
            thermalState = newThermalState
            
            if thermalStateHistoryCount < 100 {
                thermalStateHistory[thermalStateHistoryCount] = (Date(), thermalState)
                thermalStateHistoryCount += 1
            } else {
                for i in 0..<99 {
                    thermalStateHistory[i] = thermalStateHistory[i + 1]
                }
                thermalStateHistory[99] = (Date(), thermalState)
            }
            
            logEvent("Thermal State", "Changed to: \(thermalStateDescription(thermalState))")
            
            if thermalState == .serious || thermalState == .critical {
                recordBottleneck("Thermal Throttling")
            }
        }
    }
    
    private func thermalStateDescription(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal: return "Nominal"
        case .fair: return "Fair"
        case .serious: return "Serious"
        case .critical: return "Critical"
        @unknown default: return "Unknown"
        }
    }
    
    // MARK: - Battery Monitoring
    private func setupBatteryMonitoring() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        
        // Initial battery state
        batteryLevel = UIDevice.current.batteryLevel
        batteryState = UIDevice.current.batteryState
        
        // Register for battery level changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(batteryStateChanged),
            name: UIDevice.batteryLevelDidChangeNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(batteryStateChanged),
            name: UIDevice.batteryStateDidChangeNotification,
            object: nil
        )
    }
    
    @objc private func batteryStateChanged() {
        batteryLevel = UIDevice.current.batteryLevel
        batteryState = UIDevice.current.batteryState
        
        logEvent("Battery", "Level: \(String(format: "%.0f", batteryLevel * 100))%, State: \(batteryStateDescription(batteryState))")
        
        // Store in performance history
        addToHistory("batteryLevel", value: Double(batteryLevel))
    }
    
    private func batteryStateDescription(_ state: UIDevice.BatteryState) -> String {
        switch state {
        case .unknown: return "Unknown"
        case .unplugged: return "Unplugged"
        case .charging: return "Charging"
        case .full: return "Full"
        @unknown default: return "Unknown"
        }
    }
    
    private func getCurrentMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / 1024.0 / 1024.0 // Convert to MB
        }
        return 0
    }
    
    // MARK: - Performance Metrics
    func logMemoryUsage() {
        let currentTime = CACurrentMediaTime()
        
        // Only check memory every 5 seconds to avoid overhead
        if currentTime - lastMemoryCheck > 5.0 {
            let currentMemory = getCurrentMemoryUsage()
            logEvent("Memory Usage", "\(String(format: "%.1f", currentMemory)) MB")
            lastMemoryCheck = currentTime
        }
    }
    
    func logCPUUsage() {
        var infoArray: processor_info_array_t?
        var numCpuInfo: mach_msg_type_number_t = 0
        var numCpus: natural_t = 0
        
        let result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &numCpus, &infoArray, &numCpuInfo)
        
        if result == KERN_SUCCESS, let info = infoArray {
            let cpuLoadInfo = UnsafeBufferPointer<processor_cpu_load_info>(start: UnsafeRawPointer(info).assumingMemoryBound(to: processor_cpu_load_info.self), count: Int(numCpus))
            
            var totalUser: UInt32 = 0
            var totalSystem: UInt32 = 0
            var totalIdle: UInt32 = 0
            
            for i in 0..<Int(numCpus) {
                totalUser += cpuLoadInfo[i].cpu_ticks.0
                totalSystem += cpuLoadInfo[i].cpu_ticks.1
                totalIdle += cpuLoadInfo[i].cpu_ticks.2
            }
            
            let totalTicks = totalUser + totalSystem + totalIdle
            let cpuUsage = totalTicks > 0 ? Double(totalUser + totalSystem) / Double(totalTicks) * 100 : 0
            
            logEvent("CPU Usage", "\(String(format: "%.1f", cpuUsage))%")
            
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), vm_size_t(numCpuInfo) * vm_size_t(MemoryLayout<integer_t>.size))
        }
    }
    
    // MARK: - Real-time Monitoring
    func startRealTimeMonitoring() {
        guard !isMonitoring else { return }
        
        if !isFullyInitialized {
            deferredInitialization()
        }
        
        isMonitoring = true
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: metricsUpdateInterval, repeats: true) { [weak self] _ in
            self?.updateRealTimeMetrics()
        }
        
        logEvent("Monitoring", "Started real-time performance monitoring")
    }
    
    func stopRealTimeMonitoring() {
        guard isMonitoring else { return }
        
        isMonitoring = false
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        
        logEvent("Monitoring", "Stopped real-time performance monitoring")
    }
    
    private func updateRealTimeMetrics() {
        let memoryUsage = getCurrentMemoryUsage()
        addToHistory("memoryUsage", value: memoryUsage)
        
        if let device = metalDevice {
            updateGPUMetrics(device: device)
        }
        
        checkPerformanceThresholds()
    }
    
    private func getCurrentCPUUsage() -> Double {
        var infoArray: processor_info_array_t?
        var numCpuInfo: mach_msg_type_number_t = 0
        var numCpus: natural_t = 0
        
        let result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &numCpus, &infoArray, &numCpuInfo)
        
        if result == KERN_SUCCESS, let info = infoArray {
            let cpuLoadInfo = UnsafeBufferPointer<processor_cpu_load_info>(start: UnsafeRawPointer(info).assumingMemoryBound(to: processor_cpu_load_info.self), count: Int(numCpus))
            
            var totalUser: UInt32 = 0
            var totalSystem: UInt32 = 0
            var totalIdle: UInt32 = 0
            
            for i in 0..<Int(numCpus) {
                totalUser += cpuLoadInfo[i].cpu_ticks.0
                totalSystem += cpuLoadInfo[i].cpu_ticks.1
                totalIdle += cpuLoadInfo[i].cpu_ticks.2
            }
            
            let totalTicks = totalUser + totalSystem + totalIdle
            let cpuUsage = totalTicks > 0 ? Double(totalUser + totalSystem) / Double(totalTicks) * 100 : 0
            
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), vm_size_t(numCpuInfo) * vm_size_t(MemoryLayout<integer_t>.size))
            return cpuUsage
        }
        
        return 0
    }
    
    private func updateGPUMetrics(device: MTLDevice) {
        // GPU metrics are device-dependent and may not be available on all devices
        // This is a placeholder for GPU monitoring implementation
        addToHistory("gpuUtilization", value: gpuUtilization)
        addToHistory("gpuMemoryUsage", value: gpuMemoryUsage)
    }
    
    private func checkPerformanceThresholds() {
        let currentMemory = getCurrentMemoryUsage()
        if currentMemory > 300 {
            recordBottleneck("High Memory Usage")
        }
        
        if thermalState == .serious || thermalState == .critical {
            recordBottleneck("Thermal Throttling")
        }
        
        let frameRateStability = getFrameRateStability()
        if frameRateStability < 90 {
            recordBottleneck("Frame Rate Instability")
        }
    }
    
    // MARK: - Performance Analytics
    private func recordBottleneck(_ type: String) {
        performanceBottlenecks[type, default: 0] += 1
        logEvent("Bottleneck", "\(type) detected")
    }
    
    private func addToHistory(_ key: String, value: Double) {
        if performanceHistory[key] == nil {
            performanceHistory[key] = []
        }
        
        performanceHistory[key]?.append(value)
        
        // Keep only recent samples
        if let history = performanceHistory[key], history.count > maxHistorySamples {
            performanceHistory[key]?.removeFirst()
        }
    }
    
    func getPerformanceAnalytics() -> [String: Any] {
        var analytics: [String: Any] = [:]
        
        // Frame rate metrics
        analytics["averageFrameRate"] = calculateAverageFrameRate()
        analytics["frameRateStability"] = getFrameRateStability()
        analytics["frameDropCount"] = frameDropCount
        analytics["frameRateVariance"] = frameRateVariance
        
        // Photo capture metrics
        analytics["photoCaptureStatistics"] = getPhotoCaptureStatistics()
        analytics["averagePhotoCaptureLatency"] = getAveragePhotoCaptureLatency()
        
        // Memory metrics
        analytics["currentMemoryUsage"] = getCurrentMemoryUsage()
        analytics["memoryWarnings"] = memoryWarningCount
        
        // CPU metrics
        var cpuSum: Double = 0
        for i in 0..<cpuUsageBufferCount {
            cpuSum += cpuUsageBuffer[i]
        }
        analytics["averageCpuUsage"] = cpuUsageBufferCount == 0 ? 0 : cpuSum / Double(cpuUsageBufferCount)
        
        // Thermal metrics
        analytics["thermalState"] = thermalStateDescription(thermalState)
        analytics["thermalHistory"] = (0..<thermalStateHistoryCount).map { (thermalStateHistory[$0].0.timeIntervalSince1970, thermalStateHistory[$0].1.rawValue) }
        
        // Battery metrics
        analytics["batteryLevel"] = batteryLevel
        analytics["batteryState"] = batteryStateDescription(batteryState)
        
        // Bottleneck analysis
        analytics["performanceBottlenecks"] = performanceBottlenecks
        analytics["topBottlenecks"] = getTopBottlenecks()
        
        // Performance history (last 100 samples)
        var historySummary: [String: [Double]] = [:]
        for (key, values) in performanceHistory {
            let recentValues = Array(values.suffix(100))
            historySummary[key] = recentValues
        }
        analytics["performanceHistory"] = historySummary
        
        return analytics
    }
    
    private func getTopBottlenecks() -> [(String, Int)] {
        return performanceBottlenecks.sorted { $0.value > $1.value }.prefix(5).map { ($0.key, $0.value) }
    }
    
    func getPerformanceRecommendations() -> [String] {
        var recommendations: [String] = []
        
        // Analyze bottlenecks and provide recommendations
        let topBottlenecks = getTopBottlenecks()
        
        for (bottleneck, _) in topBottlenecks {
            switch bottleneck {
            case "High CPU Usage":
                recommendations.append("Consider reducing video quality or frame rate to lower CPU usage")
            case "High Memory Usage":
                recommendations.append("Enable adaptive quality settings to reduce memory pressure")
            case "Thermal Throttling":
                recommendations.append("Device is overheating. Consider taking a break from recording")
            case "Frame Rate Instability":
                recommendations.append("Enable frame rate stabilization in settings")
            case "Memory Warning":
                recommendations.append("Close other apps to free up memory")
            default:
                recommendations.append("Performance issue detected: \(bottleneck)")
            }
        }
        
        // Battery recommendations
        if batteryLevel < 0.2 && batteryState == .unplugged {
            recommendations.append("Battery is low. Consider connecting to a power source")
        }
        
        return recommendations
    }
    
    // MARK: - General Event Logging
    func logEvent(_ name: StaticString, _ message: String = "") {
        os_signpost(.event, log: log, name: name, "%{public}s", message)
    }
    
    // MARK: - Enhanced Performance Summary
    func getPerformanceSummary() -> [String: Any] {
        return [
            "averageFrameRate": calculateAverageFrameRate(),
            "frameRateStability": getFrameRateStability(),
            "memoryWarnings": memoryWarningCount,
            "currentMemoryUsage": getCurrentMemoryUsage(),
            "totalFrames": frameCount,
            "frameDropCount": frameDropCount,
            "thermalState": thermalStateDescription(thermalState),
            "batteryLevel": batteryLevel,
            "topBottlenecks": getTopBottlenecks(),
            "isMonitoring": isMonitoring,
            "averagePhotoCaptureLatency": getAveragePhotoCaptureLatency(),
            "photoCaptureCount": photoCaptureLatencies.count
        ]
    }
    
    func resetPerformanceMetrics() {
        frameCount = 0
        frameRateBufferCount = 0
        memoryWarningCount = 0
        frameDropCount = 0
        frameDropHistory.removeAll()
        performanceBottlenecks.removeAll()
        performanceHistory.removeAll()
        cpuUsageBufferCount = 0
        thermalStateHistoryCount = 0
        photoCaptureLatencies.removeAll()
        photoCaptureStartTime = 0
        
        logEvent("Metrics", "Reset all performance metrics")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        stopRealTimeMonitoring()
        memoryPressureHandler?.cancel()
    }
}

