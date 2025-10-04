//
//  DiagnosticsManager.swift
//  DualApp
//
//  Created by DualApp Team on 10/3/25.
//

import Foundation
import SwiftUI
import os.log
import UIKit

// MARK: - Diagnostics Manager Actor

@MainActor
actor DiagnosticsManager: Sendable {
    
    // MARK: - Singleton
    
    static let shared = DiagnosticsManager()
    
    // MARK: - Properties
    
    private var performanceMetrics: PerformanceMetrics
    private var systemMetrics: SystemMetrics
    private var appMetrics: AppMetrics
    private var diagnosticReports: [DiagnosticReport] = []
    private var isMonitoring: Bool = false
    private var monitoringTask: Task<Void, Never>?
    
    // MARK: - Event Streams
    
    let events: AsyncStream<DiagnosticsEvent>
    private let eventContinuation: AsyncStream<DiagnosticsEvent>.Continuation
    
    // MARK: - Logging
    
    private let logger = Logger(subsystem: "com.dualapp.diagnostics", category: "Diagnostics")
    
    // MARK: - Monitoring Configuration
    
    private let monitoringInterval: TimeInterval = 1.0 // 1 second
    private let maxReportsCount: Int = 100
    
    // MARK: - Initialization
    
    private init() {
        (self.events, self.eventContinuation) = AsyncStream<DiagnosticsEvent>.makeStream()
        
        // Initialize metrics
        self.performanceMetrics = PerformanceMetrics()
        self.systemMetrics = SystemMetrics()
        self.appMetrics = AppMetrics()
        
        // Start monitoring
        Task {
            await startMonitoring()
        }
    }
    
    // MARK: - Public Interface
    
    func startMonitoring() async {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        eventContinuation.yield(.monitoringStarted)
        
        monitoringTask = Task {
            while isMonitoring && !Task.isCancelled {
                await collectMetrics()
                try? await Task.sleep(nanoseconds: UInt64(monitoringInterval * 1_000_000_000))
            }
        }
    }
    
    func stopMonitoring() async {
        guard isMonitoring else { return }
        
        isMonitoring = false
        monitoringTask?.cancel()
        monitoringTask = nil
        
        eventContinuation.yield(.monitoringStopped)
    }
    
    func collectMetrics() async {
        // Collect system metrics
        await updateSystemMetrics()
        
        // Collect performance metrics
        await updatePerformanceMetrics()
        
        // Collect app metrics
        await updateAppMetrics()
        
        // Check for issues
        await checkForIssues()
        
        // Notify listeners
        eventContinuation.yield(.metricsUpdated(
            performance: performanceMetrics,
            system: systemMetrics,
            app: appMetrics
        ))
    }
    
    func generateDiagnosticReport() async -> DiagnosticReport {
        let report = DiagnosticReport(
            id: UUID(),
            timestamp: Date(),
            performanceMetrics: performanceMetrics,
            systemMetrics: systemMetrics,
            appMetrics: appMetrics,
            issues: await detectIssues(),
            recommendations: await generateRecommendations(),
            systemHealth: await calculateSystemHealth()
        )
        
        // Store report
        diagnosticReports.append(report)
        
        // Trim reports if needed
        if diagnosticReports.count > maxReportsCount {
            diagnosticReports.removeFirst(diagnosticReports.count - maxReportsCount)
        }
        
        eventContinuation.yield(.reportGenerated(report))
        
        return report
    }
    
    func getDiagnosticReports() async -> [DiagnosticReport] {
        return diagnosticReports
    }
    
    func clearDiagnosticReports() async {
        diagnosticReports.removeAll()
        eventContinuation.yield(.reportsCleared)
    }
    
    func runSystemHealthCheck() async -> SystemHealthCheck {
        let check = SystemHealthCheck(
            timestamp: Date(),
            memoryHealth: await checkMemoryHealth(),
            storageHealth: await checkStorageHealth(),
            thermalHealth: await checkThermalHealth(),
            batteryHealth: await checkBatteryHealth(),
            networkHealth: await checkNetworkHealth(),
            performanceHealth: await checkPerformanceHealth()
        )
        
        eventContinuation.yield(.healthCheckCompleted(check))
        
        return check
    }
    
    func exportDiagnosticData() async -> Data {
        let exportData = DiagnosticExportData(
            reports: diagnosticReports,
            currentMetrics: DiagnosticExportData.CurrentMetrics(
                performance: performanceMetrics,
                system: systemMetrics,
                app: appMetrics
            ),
            deviceInfo: await getDeviceInfo(),
            exportDate: Date()
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        do {
            return try encoder.encode(exportData)
        } catch {
            logger.error("Failed to export diagnostic data: \(error.localizedDescription)")
            return Data()
        }
    }
    
    func getPerformanceMetrics() async -> PerformanceMetrics {
        return performanceMetrics
    }
    
    func getSystemMetrics() async -> SystemMetrics {
        return systemMetrics
    }
    
    func getAppMetrics() async -> AppMetrics {
        return appMetrics
    }
    
    // MARK: - Private Methods
    
    private func updateSystemMetrics() async {
        let processInfo = ProcessInfo.processInfo
        
        // Update CPU usage
        systemMetrics.cpuUsage = await getCurrentCPUUsage()
        
        // Update memory usage
        systemMetrics.memoryUsage = await getCurrentMemoryUsage()
        
        // Update thermal state
        systemMetrics.thermalState = ProcessInfo.processInfo.thermalState
        
        // Update battery level
        UIDevice.current.isBatteryMonitoringEnabled = true
        systemMetrics.batteryLevel = UIDevice.current.batteryLevel
        
        // Update disk usage
        systemMetrics.diskUsage = await getCurrentDiskUsage()
        
        // Update network status
        systemMetrics.networkStatus = await getCurrentNetworkStatus()
    }
    
    private func updatePerformanceMetrics() async {
        let currentTime = Date()
        
        // Update frame rate
        performanceMetrics.frameRate = await calculateFrameRate()
        
        // Update render time
        performanceMetrics.averageRenderTime = await calculateAverageRenderTime()
        
        // Update memory pressure
        performanceMetrics.memoryPressure = await getMemoryPressure()
        
        // Update thermal throttling
        performanceMetrics.thermalThrottling = await getThermalThrottlingStatus()
        
        // Update timestamp
        performanceMetrics.lastUpdated = currentTime
    }
    
    private func updateAppMetrics() async {
        let currentTime = Date()
        
        // Update uptime
        if let launchTime = appMetrics.launchTime {
            appMetrics.uptime = currentTime.timeIntervalSince(launchTime)
        } else {
            appMetrics.launchTime = currentTime
            appMetrics.uptime = 0
        }
        
        // Update memory usage
        appMetrics.memoryUsage = await getAppMemoryUsage()
        
        // Update active sessions
        appMetrics.activeSessions = await getActiveSessions()
        
        // Update errors count
        appMetrics.errorsCount = await getErrorsCount()
        
        // Update timestamp
        appMetrics.lastUpdated = currentTime
    }
    
    private func checkForIssues() async {
        var issues: [DiagnosticIssue] = []
        
        // Check memory usage
        if systemMetrics.memoryUsage > 0.8 {
            issues.append(DiagnosticIssue(
                type: .highMemoryUsage,
                severity: .warning,
                description: "Memory usage is above 80%",
                recommendation: "Close other apps or restart the app"
            ))
        }
        
        // Check CPU usage
        if systemMetrics.cpuUsage > 0.9 {
            issues.append(DiagnosticIssue(
                type: .highCPUUsage,
                severity: .warning,
                description: "CPU usage is above 90%",
                recommendation: "Reduce app workload or wait for processes to complete"
            ))
        }
        
        // Check thermal state
        if systemMetrics.thermalState == .critical {
            issues.append(DiagnosticIssue(
                type: .thermalThrottling,
                severity: .error,
                description: "Device is overheating",
                recommendation: "Allow device to cool down and reduce app usage"
            ))
        }
        
        // Check battery level
        if systemMetrics.batteryLevel < 0.1 {
            issues.append(DiagnosticIssue(
                type: .lowBattery,
                severity: .warning,
                description: "Battery level is below 10%",
                recommendation: "Connect to power source"
            ))
        }
        
        // Check disk space
        if systemMetrics.diskUsage.freeSpace < 1024 * 1024 * 1024 { // Less than 1GB
            issues.append(DiagnosticIssue(
                type: .lowDiskSpace,
                severity: .error,
                description: "Available disk space is below 1GB",
                recommendation: "Free up storage space"
            ))
        }
        
        // Notify about issues
        if !issues.isEmpty {
            eventContinuation.yield(.issuesDetected(issues))
        }
    }
    
    private func detectIssues() async -> [DiagnosticIssue] {
        var issues: [DiagnosticIssue] = []
        
        // Performance issues
        if performanceMetrics.averageRenderTime > 0.033 { // More than 30ms
            issues.append(DiagnosticIssue(
                type: .slowRendering,
                severity: .warning,
                description: "Average render time is above 30ms",
                recommendation: "Reduce visual effects or lower quality settings"
            ))
        }
        
        if performanceMetrics.frameRate < 30 {
            issues.append(DiagnosticIssue(
                type: .lowFrameRate,
                severity: .warning,
                description: "Frame rate is below 30fps",
                recommendation: "Lower video quality or reduce background processes"
            ))
        }
        
        // System issues
        if systemMetrics.memoryUsage > 0.85 {
            issues.append(DiagnosticIssue(
                type: .highMemoryUsage,
                severity: .error,
                description: "Memory usage is critically high",
                recommendation: "Restart app or device"
            ))
        }
        
        if systemMetrics.thermalState == .serious || systemMetrics.thermalState == .critical {
            issues.append(DiagnosticIssue(
                type: .thermalThrottling,
                severity: .error,
                description: "Device thermal state is serious or critical",
                recommendation: "Stop intensive operations and allow device to cool"
            ))
        }
        
        return issues
    }
    
    private func generateRecommendations() async -> [DiagnosticRecommendation] {
        var recommendations: [DiagnosticRecommendation] = []
        
        // Performance recommendations
        if performanceMetrics.averageRenderTime > 0.025 {
            recommendations.append(DiagnosticRecommendation(
                type: .performance,
                title: "Optimize Performance",
                description: "Consider reducing visual effects or lowering quality settings",
                priority: .medium
            ))
        }
        
        // Memory recommendations
        if systemMetrics.memoryUsage > 0.7 {
            recommendations.append(DiagnosticRecommendation(
                type: .memory,
                title: "Free Up Memory",
                description: "Close background apps or restart the application",
                priority: .high
            ))
        }
        
        // Battery recommendations
        if systemMetrics.batteryLevel < 0.2 {
            recommendations.append(DiagnosticRecommendation(
                type: .battery,
                title: "Conserve Battery",
                description: "Connect to power source or enable battery optimization",
                priority: .high
            ))
        }
        
        // Storage recommendations
        if systemMetrics.diskUsage.freeSpace < 5 * 1024 * 1024 * 1024 { // Less than 5GB
            recommendations.append(DiagnosticRecommendation(
                type: .storage,
                title: "Free Up Storage",
                description: "Clear cache and remove unnecessary files",
                priority: .medium
            ))
        }
        
        return recommendations.sorted { $0.priority.rawValue > $1.priority.rawValue }
    }
    
    private func calculateSystemHealth() async -> SystemHealthStatus {
        let issues = await detectIssues()
        
        let criticalIssues = issues.filter { $0.severity == .error }
        let warningIssues = issues.filter { $0.severity == .warning }
        
        if criticalIssues.count > 0 {
            return .poor
        } else if warningIssues.count > 3 {
            return .fair
        } else if warningIssues.count > 0 {
            return .good
        } else {
            return .excellent
        }
    }
    
    // MARK: - Health Check Methods
    
    private func checkMemoryHealth() async -> HealthStatus {
        let memoryUsage = systemMetrics.memoryUsage
        
        if memoryUsage > 0.9 {
            return .critical
        } else if memoryUsage > 0.7 {
            return .warning
        } else {
            return .healthy
        }
    }
    
    private func checkStorageHealth() async -> HealthStatus {
        let freeSpace = systemMetrics.diskUsage.freeSpace
        let totalSpace = systemMetrics.diskUsage.totalSpace
        let usageRatio = 1.0 - (freeSpace / totalSpace)
        
        if usageRatio > 0.95 {
            return .critical
        } else if usageRatio > 0.8 {
            return .warning
        } else {
            return .healthy
        }
    }
    
    private func checkThermalHealth() async -> HealthStatus {
        switch systemMetrics.thermalState {
        case .critical:
            return .critical
        case .serious:
            return .warning
        case .fair:
            return .healthy
        case .nominal:
            return .healthy
        @unknown default:
            return .healthy
        }
    }
    
    private func checkBatteryHealth() async -> HealthStatus {
        let batteryLevel = systemMetrics.batteryLevel
        
        if batteryLevel < 0.05 {
            return .critical
        } else if batteryLevel < 0.2 {
            return .warning
        } else {
            return .healthy
        }
    }
    
    private func checkNetworkHealth() async -> HealthStatus {
        switch systemMetrics.networkStatus {
        case .connected:
            return .healthy
        case .connecting:
            return .warning
        case .disconnected:
            return .warning
        }
    }
    
    private func checkPerformanceHealth() async -> HealthStatus {
        let frameRate = performanceMetrics.frameRate
        let renderTime = performanceMetrics.averageRenderTime
        
        if frameRate < 15 || renderTime > 0.066 {
            return .critical
        } else if frameRate < 30 || renderTime > 0.033 {
            return .warning
        } else {
            return .healthy
        }
    }
    
    // MARK: - System Information Methods
    
    private func getCurrentCPUUsage() async -> Double {
        var info = processor_info_array_t.allocate(capacity: 1)
        var numCpuInfo: mach_msg_type_number_t = 0
        var numCpus: natural_t = 0
        
        let result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &numCpus, &info, &numCpuInfo)
        
        guard result == KERN_SUCCESS else { return 0.0 }
        
        let cpuLoadInfo = info.bindMemory(to: processor_cpu_load_info.self, capacity: Int(numCpus))
        
        var totalTicks: UInt32 = 0
        var idleTicks: UInt32 = 0
        
        for i in 0..<Int(numCpus) {
            totalTicks += cpuLoadInfo[i].cpu_ticks.0 + cpuLoadInfo[i].cpu_ticks.1 + cpuLoadInfo[i].cpu_ticks.2 + cpuLoadInfo[i].cpu_ticks.3
            idleTicks += cpuLoadInfo[i].cpu_ticks.2
        }
        
        vm_deallocate(mach_task_self_, vm_address_t(info.raw), vm_size_t(numCpuInfo))
        
        return totalTicks > 0 ? Double(totalTicks - idleTicks) / Double(totalTicks) : 0.0
    }
    
    private func getCurrentMemoryUsage() async -> Double {
        let taskInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        guard kerr == KERN_SUCCESS else { return 0.0 }
        
        let usedMemory = Double(taskInfo.resident_size)
        let totalMemory = Double(ProcessInfo.processInfo.physicalMemory)
        
        return usedMemory / totalMemory
    }
    
    private func getCurrentDiskUsage() async -> DiskUsage {
        let fileManager = FileManager.default
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        do {
            let attributes = try fileManager.attributesOfFileSystem(forPath: documentsPath.path)
            
            let totalSpace = attributes[.systemSize] as? UInt64 ?? 0
            let freeSpace = attributes[.systemFreeSize] as? UInt64 ?? 0
            let usedSpace = totalSpace - freeSpace
            
            return DiskUsage(
                totalSpace: totalSpace,
                usedSpace: usedSpace,
                freeSpace: freeSpace
            )
        } catch {
            return DiskUsage(totalSpace: 0, usedSpace: 0, freeSpace: 0)
        }
    }
    
    private func getCurrentNetworkStatus() async -> NetworkStatus {
        let reachability = SCNetworkReachabilityCreateWithName(nil, "apple.com")
        var flags = SCNetworkReachabilityFlags()
        
        guard SCNetworkReachabilityGetFlags(reachability!, &flags) else {
            return .disconnected
        }
        
        let isReachable = flags.contains(.reachable)
        let needsConnection = flags.contains(.connectionRequired)
        
        if isReachable && !needsConnection {
            return .connected
        } else if isReachable && needsConnection {
            return .connecting
        } else {
            return .disconnected
        }
    }
    
    private func calculateFrameRate() async -> Double {
        // This would be implemented with actual frame rate calculation
        // For now, return a placeholder value
        return 60.0
    }
    
    private func calculateAverageRenderTime() async -> Double {
        // This would be implemented with actual render time calculation
        // For now, return a placeholder value
        return 0.016 // 16ms for 60fps
    }
    
    private func getMemoryPressure() async -> MemoryPressure {
        let source = DispatchSource.makeMemoryPressureSource(eventMask: .warning, queue: .main)
        
        // This is a simplified implementation
        // In a real app, you would monitor memory pressure events
        return .normal
    }
    
    private func getThermalThrottlingStatus() async -> Bool {
        return ProcessInfo.processInfo.thermalState == .serious || ProcessInfo.processInfo.thermalState == .critical
    }
    
    private func getAppMemoryUsage() async -> UInt64 {
        let taskInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        guard kerr == KERN_SUCCESS else { return 0 }
        
        return taskInfo.resident_size
    }
    
    private func getActiveSessions() async -> Int {
        // This would return the number of active recording sessions
        // For now, return a placeholder value
        return 0
    }
    
    private func getErrorsCount() async -> Int {
        // This would return the number of recent errors
        // For now, return a placeholder value
        return 0
    }
    
    private func getDeviceInfo() async -> DeviceInfo {
        return DeviceInfo(
            model: UIDevice.current.model,
            systemVersion: UIDevice.current.systemVersion,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
            buildNumber: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown",
            deviceName: UIDevice.current.name,
            identifierForVendor: UIDevice.current.identifierForVendor?.uuidString
        )
    }
}

// MARK: - Diagnostics Event

enum DiagnosticsEvent: Sendable {
    case monitoringStarted
    case monitoringStopped
    case metricsUpdated(performance: PerformanceMetrics, system: SystemMetrics, app: AppMetrics)
    case issuesDetected([DiagnosticIssue])
    case reportGenerated(DiagnosticReport)
    case reportsCleared
    case healthCheckCompleted(SystemHealthCheck)
}

// MARK: - Metrics Models

struct PerformanceMetrics: Sendable, Codable {
    var frameRate: Double = 0.0
    var averageRenderTime: Double = 0.0
    var memoryPressure: MemoryPressure = .normal
    var thermalThrottling: Bool = false
    var lastUpdated: Date = Date()
}

struct SystemMetrics: Sendable, Codable {
    var cpuUsage: Double = 0.0
    var memoryUsage: Double = 0.0
    var thermalState: ProcessInfo.ThermalState = .nominal
    var batteryLevel: Float = 1.0
    var diskUsage: DiskUsage = DiskUsage(totalSpace: 0, usedSpace: 0, freeSpace: 0)
    var networkStatus: NetworkStatus = .disconnected
    var lastUpdated: Date = Date()
}

struct AppMetrics: Sendable, Codable {
    var launchTime: Date?
    var uptime: TimeInterval = 0.0
    var memoryUsage: UInt64 = 0
    var activeSessions: Int = 0
    var errorsCount: Int = 0
    var lastUpdated: Date = Date()
}

struct DiskUsage: Sendable, Codable {
    let totalSpace: UInt64
    let usedSpace: UInt64
    let freeSpace: UInt64
    
    var usagePercentage: Double {
        return totalSpace > 0 ? Double(usedSpace) / Double(totalSpace) : 0.0
    }
    
    var freeSpaceFormatted: String {
        return ByteCountFormatter.string(fromByteCount: Int64(freeSpace), countStyle: .file)
    }
    
    var usedSpaceFormatted: String {
        return ByteCountFormatter.string(fromByteCount: Int64(usedSpace), countStyle: .file)
    }
    
    var totalSpaceFormatted: String {
        return ByteCountFormatter.string(fromByteCount: Int64(totalSpace), countStyle: .file)
    }
}

enum MemoryPressure: String, Sendable, Codable {
    case normal = "normal"
    case warning = "warning"
    case critical = "critical"
}

enum NetworkStatus: String, Sendable, Codable {
    case connected = "connected"
    case connecting = "connecting"
    case disconnected = "disconnected"
}

// MARK: - Diagnostic Models

struct DiagnosticReport: Sendable, Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let performanceMetrics: PerformanceMetrics
    let systemMetrics: SystemMetrics
    let appMetrics: AppMetrics
    let issues: [DiagnosticIssue]
    let recommendations: [DiagnosticRecommendation]
    let systemHealth: SystemHealthStatus
}

struct DiagnosticIssue: Sendable, Identifiable, Codable {
    let id = UUID()
    let type: DiagnosticIssueType
    let severity: DiagnosticSeverity
    let description: String
    let recommendation: String
}

enum DiagnosticIssueType: String, Sendable, Codable {
    case highMemoryUsage = "highMemoryUsage"
    case highCPUUsage = "highCPUUsage"
    case thermalThrottling = "thermalThrottling"
    case lowBattery = "lowBattery"
    case lowDiskSpace = "lowDiskSpace"
    case slowRendering = "slowRendering"
    case lowFrameRate = "lowFrameRate"
}

enum DiagnosticSeverity: String, Sendable, Codable {
    case info = "info"
    case warning = "warning"
    case error = "error"
    case critical = "critical"
}

struct DiagnosticRecommendation: Sendable, Identifiable, Codable {
    let id = UUID()
    let type: RecommendationType
    let title: String
    let description: String
    let priority: RecommendationPriority
}

enum RecommendationType: String, Sendable, Codable {
    case performance = "performance"
    case memory = "memory"
    case battery = "battery"
    case storage = "storage"
    case network = "network"
}

enum RecommendationPriority: Int, Sendable, Codable {
    case low = 1
    case medium = 2
    case high = 3
    case critical = 4
}

enum SystemHealthStatus: String, Sendable, Codable {
    case excellent = "excellent"
    case good = "good"
    case fair = "fair"
    case poor = "poor"
    
    var color: Color {
        switch self {
        case .excellent:
            return .green
        case .good:
            return .blue
        case .fair:
            return .orange
        case .poor:
            return .red
        }
    }
    
    var icon: String {
        switch self {
        case .excellent:
            return "heart.fill"
        case .good:
            return "heart"
        case .fair:
            return "heart.slash"
        case .poor:
            return "heart.slash.fill"
        }
    }
}

// MARK: - Health Check Models

struct SystemHealthCheck: Sendable, Codable {
    let timestamp: Date
    let memoryHealth: HealthStatus
    let storageHealth: HealthStatus
    let thermalHealth: HealthStatus
    let batteryHealth: HealthStatus
    let networkHealth: HealthStatus
    let performanceHealth: HealthStatus
    
    var overallHealth: HealthStatus {
        let healths = [memoryHealth, storageHealth, thermalHealth, batteryHealth, networkHealth, performanceHealth]
        
        if healths.contains(.critical) {
            return .critical
        } else if healths.contains(.warning) {
            return .warning
        } else {
            return .healthy
        }
    }
}

enum HealthStatus: String, Sendable, Codable {
    case healthy = "healthy"
    case warning = "warning"
    case critical = "critical"
    
    var color: Color {
        switch self {
        case .healthy:
            return .green
        case .warning:
            return .orange
        case .critical:
            return .red
        }
    }
    
    var icon: String {
        switch self {
        case .healthy:
            return "checkmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .critical:
            return "xmark.circle.fill"
        }
    }
}

// MARK: - Export Models

struct DiagnosticExportData: Sendable, Codable {
    let reports: [DiagnosticReport]
    let currentMetrics: CurrentMetrics
    let deviceInfo: DeviceInfo
    let exportDate: Date
    
    struct CurrentMetrics: Sendable, Codable {
        let performance: PerformanceMetrics
        let system: SystemMetrics
        let app: AppMetrics
    }
}

struct DeviceInfo: Sendable, Codable {
    let model: String
    let systemVersion: String
    let appVersion: String
    let buildNumber: String
    let deviceName: String
    let identifierForVendor: String?
}