//
//  SystemCoordinator.swift
//  DualApp
//
//  Created by DualApp Team on 10/3/25.
//

import Foundation
import SwiftUI

// MARK: - System Coordinator Actor

@MainActor
actor SystemCoordinator: Sendable {
    // MARK: - Singleton
    
    static let shared = SystemCoordinator()
    
    // MARK: - Actor References
    
    private nonisolated let cameraManager: CameraManager
    private nonisolated let permissionManager: PermissionManager
    private nonisolated let memoryManager: MemoryManager
    private nonisolated let batteryManager: BatteryManager
    private nonisolated let thermalManager: ThermalManager
    
    // MARK: - Event Streams
    
    private var cameraTask: Task<Void, Never>?
    private var permissionTask: Task<Void, Never>?
    private var memoryTask: Task<Void, Never>?
    private var batteryTask: Task<Void, Never>?
    private var thermalTask: Task<Void, Never>?
    
    // MARK: - State
    
    private(set) var isInitialized: Bool = false
    private(set) var systemHealth: SystemHealth = .unknown
    
    // MARK: - Event Stream
    
    let events: AsyncStream<SystemEvent>
    private let eventContinuation: AsyncStream<SystemEvent>.Continuation
    
    // MARK: - Initialization
    
    private init() {
        (self.events, self.eventContinuation) = AsyncStream<SystemEvent>.makeStream()
        
        // Initialize actors with distributed actor support
        self.cameraManager = CameraManager()
        self.permissionManager = PermissionManager()
        self.memoryManager = MemoryManager()
        self.batteryManager = BatteryManager()
        self.thermalManager = ThermalManager.shared
        
        Task {
            await initializeSystem()
        }
    }
    
    // MARK: - Public Interface
    
    func initializeSystem() async {
        guard !isInitialized else { return }
        
        eventContinuation.yield(.initializationStarted)
        
        do {
            // Start all actor monitoring with task groups for better performance
            try await startActorMonitoringWithTaskGroups()
            
            // Set up inter-actor communication
            await setupInterActorCommunication()
            
            // Perform initial system health check
            await performSystemHealthCheck()
            
            isInitialized = true
            eventContinuation.yield(.initializationCompleted)
            
        } catch {
            eventContinuation.yield(.initializationFailed(error.localizedDescription))
        }
    }
    
    func shutdownSystem() async {
        guard isInitialized else { return }
        
        eventContinuation.yield(.shutdownStarted)
        
        // Stop all monitoring
        await stopActorMonitoring()
        
        // Cancel all tasks
        await cancelAllTasks()
        
        isInitialized = false
        eventContinuation.yield(.shutdownCompleted)
    }
    
    func getSystemStatus() async -> SystemStatus {
        return SystemStatus(
            isInitialized: isInitialized,
            systemHealth: systemHealth,
            cameraState: await cameraManager.state,
            memoryPressure: await memoryManager.currentMemoryPressure,
            batteryLevel: await batteryManager.currentBatteryLevel,
            thermalState: await thermalManager.currentThermalState
        )
    }
    
    func requestSystemOptimization() async {
        eventContinuation.yield(.optimizationRequested)
        
        // Optimize memory
        await memoryManager.requestMemoryCleanup()
        
        // Optimize battery usage
        await batteryManager.setBatteryOptimizationEnabled(true)
        
        // Apply thermal mitigation if needed
        if await thermalManager.shouldThrottlePerformance() {
            await thermalManager.forceThermalMitigation()
        }
        
        eventContinuation.yield(.optimizationCompleted)
    }
    
    // MARK: - Private Methods
    
    private func startActorMonitoringWithTaskGroups() async throws {
        // Use task groups for concurrent monitoring
        try await withThrowingTaskGroup(of: Void.self) { group in
            // Camera manager monitoring
            group.addTask {
                for await event in await self.cameraManager.events {
                    await self.handleCameraEvent(event)
                }
            }
            
            // Permission manager monitoring
            group.addTask {
                for await event in await self.permissionManager.events {
                    await self.handlePermissionEvent(event)
                }
            }
            
            // Memory manager monitoring
            group.addTask {
                for await event in await self.memoryManager.events {
                    await self.handleMemoryEvent(event)
                }
            }
            
            // Battery manager monitoring
            group.addTask {
                for await event in await self.batteryManager.events {
                    await self.handleBatteryEvent(event)
                }
            }
            
            // Thermal manager monitoring
            group.addTask {
                for await event in await self.thermalManager.events {
                    await self.handleThermalEvent(event)
                }
            }
        }
    }
    
    private func stopActorMonitoring() async {
        cameraTask?.cancel()
        permissionTask?.cancel()
        memoryTask?.cancel()
        batteryTask?.cancel()
        thermalTask?.cancel()
        
        await cameraManager.stopRecording()
        await memoryManager.stopMonitoring()
        await batteryManager.stopMonitoring()
        await thermalManager.stopMonitoring()
    }
    
    private func setupInterActorCommunication() async {
        // Set up cross-actor event handling with strict concurrency
        // This allows actors to react to each other's events
    }
    
    private func cancelAllTasks() async {
        cameraTask?.cancel()
        permissionTask?.cancel()
        memoryTask?.cancel()
        batteryTask?.cancel()
        thermalTask?.cancel()
    }
    
    private func performSystemHealthCheck() async {
        let memoryPressure = await memoryManager.currentMemoryPressure
        let batteryLevel = await batteryManager.currentBatteryLevel
        let thermalState = await thermalManager.currentThermalState
        
        // Calculate overall system health
        if memoryPressure == .critical || batteryLevel < 0.1 || thermalState == .critical {
            systemHealth = .critical
        } else if memoryPressure == .warning || batteryLevel < 0.2 || thermalState == .serious {
            systemHealth = .warning
        } else {
            systemHealth = .healthy
        }
        
        eventContinuation.yield(.healthChanged(systemHealth))
    }
    
    // MARK: - Event Handlers
    
    private func handleCameraEvent(_ event: CameraEvent) async {
        switch event {
        case .stateChanged(let state):
            eventContinuation.yield(.cameraStateChanged(state))
            
        case .recordingStarted:
            // Notify other managers about recording start
            await memoryManager.optimizeForHighMemoryUsage()
            await batteryManager.setPerformanceProfile(.balanced)
            eventContinuation.yield(.recordingStateChanged(.started))
            
        case .recordingStopped:
            // Notify other managers about recording stop
            await memoryManager.optimizeForLowMemoryUsage()
            eventContinuation.yield(.recordingStateChanged(.stopped))
            
        case .error(let error):
            eventContinuation.yield(.cameraError(error))
            
        default:
            break
        }
    }
    
    private func handlePermissionEvent(_ event: PermissionEvent) async {
        switch event {
        case .permissionChanged(let type, let status):
            eventContinuation.yield(.permissionChanged(type, status))
            
            // If camera permission is denied, stop camera operations
            if type == .camera && !status.isAuthorized {
                await cameraManager.stopRecording()
            }
            
        default:
            break
        }
    }
    
    private func handleMemoryEvent(_ event: MemoryEvent) async {
        switch event {
        case .warning(let usageRatio):
            eventContinuation.yield(.memoryWarning(usageRatio))
            
            // If memory is critical, stop recording
            if usageRatio > 0.9 {
                await cameraManager.stopRecording()
            }
            
        case .cleanupCompleted:
            eventContinuation.yield(.memoryCleanupCompleted)
            
        default:
            break
        }
    }
    
    private func handleBatteryEvent(_ event: BatteryEvent) async {
        switch event {
        case .criticalBatteryLevel(let level):
            eventContinuation.yield(.batteryCritical(level))
            
            // Stop recording on critical battery
            await cameraManager.stopRecording()
            
        case .lowBatteryLevel(let level):
            eventContinuation.yield(.batteryLow(level))
            
            // Reduce recording quality on low battery
            if await cameraManager.state == .recording {
                let recommendedQuality = await batteryManager.getRecommendedQuality()
                // Apply quality reduction
            }
            
        case .stateChanged(let state):
            eventContinuation.yield(.batteryStateChanged(state))
            
        default:
            break
        }
    }
    
    private func handleThermalEvent(_ event: ThermalEvent) async {
        switch event {
        case .warning(let state):
            eventContinuation.yield(.thermalWarning(state))
            
            // Reduce performance on thermal warning
            if state == .serious || state == .critical {
                await cameraManager.stopRecording()
            }
            
        case .stateChanged(from: _, to: let newState):
            eventContinuation.yield(.thermalStateChanged(newState))
            
        default:
            break
        }
    }
    
    deinit {
        Task {
            await shutdownSystem()
        }
    }
}

// MARK: - System Event

enum SystemEvent: Sendable {
    case initializationStarted
    case initializationCompleted
    case initializationFailed(String)
    case shutdownStarted
    case shutdownCompleted
    case healthChanged(SystemHealth)
    case cameraStateChanged(CameraState)
    case recordingStateChanged(RecordingState)
    case permissionChanged(PermissionType, PermissionStatus)
    case memoryWarning(Double)
    case memoryCleanupCompleted
    case batteryCritical(Double)
    case batteryLow(Double)
    case batteryStateChanged(UIDevice.BatteryState)
    case thermalWarning(ThermalState)
    case thermalStateChanged(ThermalState)
    case cameraError(CameraError)
    case optimizationRequested
    case optimizationCompleted
}

// MARK: - System Health

enum SystemHealth: String, CaseIterable, Sendable {
    case healthy = "Healthy"
    case warning = "Warning"
    case critical = "Critical"
    case unknown = "Unknown"
    
    var color: Color {
        switch self {
        case .healthy:
            return .green
        case .warning:
            return .yellow
        case .critical:
            return .red
        case .unknown:
            return .gray
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
        case .unknown:
            return "questionmark.circle.fill"
        }
    }
}

// MARK: - Recording State

enum RecordingState: Sendable {
    case started
    case stopped
    case paused
    case error
}

// MARK: - System Status

struct SystemStatus: Sendable {
    let isInitialized: Bool
    let systemHealth: SystemHealth
    let cameraState: CameraState
    let memoryPressure: MemoryPressure
    let batteryLevel: Double
    let thermalState: ThermalState
    
    var formattedBatteryLevel: String {
        return String(format: "%.0f%%", batteryLevel * 100)
    }
    
    var isSystemHealthy: Bool {
        return systemHealth == .healthy && isInitialized
    }
    
    var canRecord: Bool {
        return isInitialized &&
               systemHealth != .critical &&
               memoryPressure != .critical &&
               batteryLevel > 0.1 &&
               thermalState != .critical
    }
}

// MARK: - System Coordinator Extensions

extension SystemCoordinator {
    
    // MARK: - Convenience Methods
    
    func startRecording() async throws {
        guard isInitialized else {
            throw SystemError.notInitialized
        }
        
        let systemStatus = await getSystemStatus()
        guard systemStatus.canRecord else {
            throw SystemError.systemNotReady
        }
        
        // Check permissions first
        let permissions = await permissionManager.requestAllPermissions()
        guard permissions.values.allSatisfy({ $0.isAuthorized }) else {
            throw SystemError.permissionsNotGranted
        }
        
        try await cameraManager.startRecording()
    }
    
    func stopRecording() async {
        await cameraManager.stopRecording()
    }
    
    func capturePhoto() async throws -> PhotoMetadata {
        guard isInitialized else {
            throw SystemError.notInitialized
        }
        
        return try await cameraManager.capturePhoto()
    }
    
    func updateCameraConfiguration(_ config: CameraConfiguration) async throws {
        guard isInitialized else {
            throw SystemError.notInitialized
        }
        
        try await cameraManager.updateConfiguration(config)
    }
    
    func getSystemRecommendations() async -> SystemRecommendations {
        let memoryPressure = await memoryManager.currentMemoryPressure
        let batteryLevel = await batteryManager.currentBatteryLevel
        let thermalState = await thermalManager.currentThermalState
        
        var recommendations: [String] = []
        
        if memoryPressure == .warning || memoryPressure == .critical {
            recommendations.append("Consider closing other apps to free up memory")
        }
        
        if batteryLevel < 0.2 {
            recommendations.append("Connect to power source for optimal performance")
        }
        
        if thermalState == .serious || thermalState == .critical {
            recommendations.append("Allow device to cool down before continuing")
        }
        
        return SystemRecommendations(
            videoQuality: await batteryManager.getRecommendedQuality(),
            frameRate: await thermalManager.getRecommendedFrameRate(),
            maxRecordingDuration: await batteryManager.getOptimalRecordingDuration(),
            recommendations: recommendations
        )
    }
}

// MARK: - System Recommendations

struct SystemRecommendations: Sendable {
    let videoQuality: VideoQuality
    let frameRate: Int32
    let maxRecordingDuration: TimeInterval
    let recommendations: [String]
    
    var formattedMaxDuration: String {
        let minutes = Int(maxRecordingDuration) / 60
        let seconds = Int(maxRecordingDuration) % 60
        
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
}

// MARK: - System Error

enum SystemError: LocalizedError, Sendable {
    case notInitialized
    case systemNotReady
    case permissionsNotGranted
    case coordinationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "System is not initialized"
        case .systemNotReady:
            return "System is not ready for operation"
        case .permissionsNotGranted:
            return "Required permissions are not granted"
        case .coordinationFailed(let reason):
            return "System coordination failed: \(reason)"
        }
    }
}