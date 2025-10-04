//
//  ErrorHandlingManager.swift
//  DualApp
//
//  Created by DualApp Team on 10/3/25.
//

import Foundation
import SwiftUI
import os.log

// MARK: - Error Handling Manager Actor

@MainActor
actor ErrorHandlingManager: Sendable {
    
    // MARK: - Singleton
    
    static let shared = ErrorHandlingManager()
    
    // MARK: - Properties
    
    private var errorHistory: [ErrorRecord] = []
    private var activeErrors: [ErrorRecord] = []
    private var errorHandlers: [ErrorHandler] = []
    private var maxHistorySize: Int = 1000
    private var maxActiveErrors: Int = 10
    
    // MARK: - Event Streams
    
    let events: AsyncStream<ErrorEvent>
    private let eventContinuation: AsyncStream<ErrorEvent>.Continuation
    
    // MARK: - Logging
    
    private let logger = Logger(subsystem: "com.dualapp.errorhandling", category: "ErrorHandling")
    
    // MARK: - Analytics
    
    private var analyticsEnabled: Bool = true
    private var crashReportingEnabled: Bool = true
    
    // MARK: - Initialization
    
    private init() {
        (self.events, self.eventContinuation) = AsyncStream<ErrorEvent>.makeStream()
        
        // Setup default error handlers
        setupDefaultHandlers()
        
        // Setup crash reporting
        setupCrashReporting()
    }
    
    // MARK: - Public Interface
    
    func handleError(_ error: Error, context: ErrorContext? = nil, severity: ErrorSeverity = .error) async {
        let errorRecord = ErrorRecord(
            error: error,
            context: context,
            severity: severity,
            timestamp: Date(),
            id: UUID()
        )
        
        // Log the error
        await logError(errorRecord)
        
        // Add to history
        await addToHistory(errorRecord)
        
        // Add to active errors if critical or error
        if severity == .critical || severity == .error {
            await addToActiveErrors(errorRecord)
        }
        
        // Notify listeners
        eventContinuation.yield(.errorOccurred(errorRecord))
        
        // Handle the error
        await handleWithErrorHandlers(errorRecord)
        
        // Report to analytics if enabled
        if analyticsEnabled {
            await reportToAnalytics(errorRecord)
        }
        
        // Check for crash conditions
        if severity == .critical {
            await checkForCrashCondition(errorRecord)
        }
    }
    
    func handleCriticalError(_ error: Error, context: ErrorContext? = nil) async {
        await handleError(error, context: context, severity: .critical)
        
        // Additional critical error handling
        eventContinuation.yield(.criticalErrorOccurred)
        
        // Attempt recovery
        await attemptCriticalErrorRecovery(error, context: context)
    }
    
    func dismissError(_ errorId: UUID) async {
        activeErrors.removeAll { $0.id == errorId }
        eventContinuation.yield(.errorDismissed(errorId))
    }
    
    func dismissAllErrors() async {
        let errorIds = activeErrors.map { $0.id }
        activeErrors.removeAll()
        
        for errorId in errorIds {
            eventContinuation.yield(.errorDismissed(errorId))
        }
    }
    
    func getActiveErrors() async -> [ErrorRecord] {
        return activeErrors
    }
    
    func getErrorHistory() async -> [ErrorRecord] {
        return errorHistory
    }
    
    func getErrorCount(for severity: ErrorSeverity) async -> Int {
        return errorHistory.filter { $0.severity == severity }.count
    }
    
    func clearErrorHistory() async {
        errorHistory.removeAll()
        eventContinuation.yield(.historyCleared)
    }
    
    func addErrorHandler(_ handler: ErrorHandler) async {
        errorHandlers.append(handler)
        eventContinuation.yield(.handlerAdded(handler.id))
    }
    
    func removeErrorHandler(_ handler: ErrorHandler) async {
        errorHandlers.removeAll { $0.id == handler.id }
        eventContinuation.yield(.handlerRemoved(handler.id))
    }
    
    func setAnalyticsEnabled(_ enabled: Bool) async {
        analyticsEnabled = enabled
        eventContinuation.yield(.analyticsChanged(enabled))
    }
    
    func setCrashReportingEnabled(_ enabled: Bool) async {
        crashReportingEnabled = enabled
        eventContinuation.yield(.crashReportingChanged(enabled))
    }
    
    func generateErrorReport() async -> ErrorReport {
        let now = Date()
        let last24Hours = now.addingTimeInterval(-24 * 60 * 60)
        
        let recentErrors = errorHistory.filter { $0.timestamp >= last24Hours }
        let criticalErrors = recentErrors.filter { $0.severity == .critical }
        let errorErrors = recentErrors.filter { $0.severity == .error }
        let warningErrors = recentErrors.filter { $0.severity == .warning }
        let infoErrors = recentErrors.filter { $0.severity == .info }
        
        let errorCategories = Dictionary(grouping: recentErrors) { $0.category }
        let errorSources = Dictionary(grouping: recentErrors) { $0.context?.component ?? "Unknown" }
        
        return ErrorReport(
            generatedAt: now,
            totalErrors: recentErrors.count,
            criticalErrors: criticalErrors.count,
            errorErrors: errorErrors.count,
            warningErrors: warningErrors.count,
            infoErrors: infoErrors.count,
            errorCategories: errorCategories.mapValues { $0.count },
            errorSources: errorSources.mapValues { $0.count },
            mostCommonError: getMostCommonError(recentErrors),
            errorTrend: calculateErrorTrend(recentErrors),
            systemHealth: calculateSystemHealth(recentErrors)
        )
    }
    
    // MARK: - Private Methods
    
    private func setupDefaultHandlers() {
        // Add default error handlers
        Task {
            await addErrorHandler(CameraErrorHandler())
            await addErrorHandler(AudioErrorHandler())
            await addErrorHandler(VideoErrorHandler())
            await addErrorHandler(StorageErrorHandler())
            await addErrorHandler(NetworkErrorHandler())
            await addErrorHandler(SystemErrorHandler())
        }
    }
    
    private func setupCrashReporting() {
        // Setup crash reporting
        NSSetUncaughtExceptionHandler { exception in
            Task { @MainActor in
                await ErrorHandlingManager.shared.handleCriticalError(
                    NSError(domain: "UncaughtException", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: exception.reason ?? "Unknown exception",
                        "exceptionName": exception.name.rawValue,
                        "exceptionStack": exception.callStackSymbols.joined(separator: "\n")
                    ]),
                    context: ErrorContext(
                        component: "CrashReporter",
                        operation: "UncaughtException",
                        userId: nil,
                        sessionId: nil,
                        additionalInfo: [
                            "exceptionName": exception.name.rawValue,
                            "exceptionReason": exception.reason ?? "Unknown"
                        ]
                    )
                )
            }
        }
    }
    
    private func logError(_ errorRecord: ErrorRecord) async {
        let message = "[\(errorRecord.severity.rawValue.uppercased())] \(errorRecord.error.localizedDescription)"
        
        switch errorRecord.severity {
        case .critical:
            logger.critical("\(message)")
        case .error:
            logger.error("\(message)")
        case .warning:
            logger.warning("\(message)")
        case .info:
            logger.info("\(message)")
        }
        
        // Log additional context if available
        if let context = errorRecord.context {
            logger.debug("Error context: \(context.component) - \(context.operation)")
        }
    }
    
    private func addToHistory(_ errorRecord: ErrorRecord) async {
        errorHistory.append(errorRecord)
        
        // Trim history if needed
        if errorHistory.count > maxHistorySize {
            errorHistory.removeFirst(errorHistory.count - maxHistorySize)
        }
    }
    
    private func addToActiveErrors(_ errorRecord: ErrorRecord) async {
        // Remove similar errors to avoid duplicates
        activeErrors.removeAll { existing in
            existing.error.localizedDescription == errorRecord.error.localizedDescription &&
            existing.context?.component == errorRecord.context?.component
        }
        
        activeErrors.append(errorRecord)
        
        // Trim active errors if needed
        if activeErrors.count > maxActiveErrors {
            activeErrors.removeFirst(activeErrors.count - maxActiveErrors)
        }
    }
    
    private func handleWithErrorHandlers(_ errorRecord: ErrorRecord) async {
        for handler in errorHandlers {
            if await handler.canHandle(errorRecord) {
                await handler.handle(errorRecord)
            }
        }
    }
    
    private func reportToAnalytics(_ errorRecord: ErrorRecord) async {
        // Report to analytics service
        // This would integrate with your analytics provider
        logger.debug("Reporting error to analytics: \(errorRecord.error.localizedDescription)")
    }
    
    private func checkForCrashCondition(_ errorRecord: ErrorRecord) async {
        // Check if this error indicates a crash condition
        let recentCriticalErrors = errorHistory.suffix(10).filter { $0.severity == .critical }
        
        if recentCriticalErrors.count >= 3 {
            logger.critical("Multiple critical errors detected, potential crash condition")
            eventContinuation.yield(.crashConditionDetected)
        }
    }
    
    private func attemptCriticalErrorRecovery(_ error: Error, context: ErrorContext?) async {
        // Attempt to recover from critical error
        logger.info("Attempting critical error recovery")
        
        // This would implement recovery strategies
        // For now, just log the attempt
        eventContinuation.yield(.recoveryAttempted)
    }
    
    private func getMostCommonError(_ errors: [ErrorRecord]) -> String? {
        let errorMessages = Dictionary(grouping: errors) { $0.error.localizedDescription }
        return errorMessages.max { $0.value.count < $1.value.count }?.key
    }
    
    private func calculateErrorTrend(_ errors: [ErrorRecord]) -> ErrorTrend {
        let now = Date()
        let last12Hours = now.addingTimeInterval(-12 * 60 * 60)
        let last24Hours = now.addingTimeInterval(-24 * 60 * 60)
        
        let recent12 = errors.filter { $0.timestamp >= last12Hours }
        let recent24 = errors.filter { $0.timestamp >= last24Hours }
        
        let rate12 = Double(recent12.count) / 12.0
        let rate24 = Double(recent24.count) / 24.0
        
        if rate12 > rate24 * 1.2 {
            return .increasing
        } else if rate12 < rate24 * 0.8 {
            return .decreasing
        } else {
            return .stable
        }
    }
    
    private func calculateSystemHealth(_ errors: [ErrorRecord]) -> SystemHealth {
        let criticalCount = errors.filter { $0.severity == .critical }.count
        let errorCount = errors.filter { $0.severity == .error }.count
        let totalCount = errors.count
        
        if totalCount == 0 {
            return .excellent
        } else if criticalCount > 0 {
            return .poor
        } else if errorCount > totalCount / 2 {
            return .fair
        } else {
            return .good
        }
    }
}

// MARK: - Error Event

enum ErrorEvent: Sendable {
    case errorOccurred(ErrorRecord)
    case criticalErrorOccurred
    case errorDismissed(UUID)
    case historyCleared
    case handlerAdded(String)
    case handlerRemoved(String)
    case analyticsChanged(Bool)
    case crashReportingChanged(Bool)
    case crashConditionDetected
    case recoveryAttempted
}

// MARK: - Error Record

struct ErrorRecord: Sendable, Identifiable, Codable {
    let id: UUID
    let error: StorableError
    let context: ErrorContext?
    let severity: ErrorSeverity
    let timestamp: Date
    
    var category: ErrorCategory {
        return error.category
    }
    
    var localizedDescription: String {
        return error.localizedDescription
    }
    
    var recoverySuggestion: String? {
        return error.recoverySuggestion
    }
}

// MARK: - Error Context

struct ErrorContext: Sendable, Codable {
    let component: String
    let operation: String
    let userId: String?
    let sessionId: String?
    let additionalInfo: [String: String]?
    
    init(component: String, operation: String, userId: String? = nil, sessionId: String? = nil, additionalInfo: [String: String]? = nil) {
        self.component = component
        self.operation = operation
        self.userId = userId
        self.sessionId = sessionId
        self.additionalInfo = additionalInfo
    }
}

// MARK: - Storable Error Protocol

protocol StorableError: Error, Sendable, Codable {
    var category: ErrorCategory { get }
    var recoverySuggestion: String? { get }
}

// MARK: - Error Extensions

extension Error: StorableError {
    var category: ErrorCategory {
        if let categorizedError = self as? StorableError {
            return categorizedError.category
        }
        
        let description = self.localizedDescription.lowercased()
        
        if description.contains("camera") {
            return .camera
        } else if description.contains("audio") {
            return .audio
        } else if description.contains("video") {
            return .video
        } else if description.contains("storage") || description.contains("disk") {
            return .storage
        } else if description.contains("network") || description.contains("connection") {
            return .network
        } else if description.contains("permission") {
            return .permission
        } else {
            return .system
        }
    }
    
    var recoverySuggestion: String? {
        if let recoverableError = self as? StorableError {
            return recoverableError.recoverySuggestion
        }
        
        let description = self.localizedDescription.lowercased()
        
        if description.contains("permission") {
            return "Check app permissions in Settings"
        } else if description.contains("network") {
            return "Check your internet connection"
        } else if description.contains("storage") {
            return "Free up storage space"
        } else {
            return "Try restarting the app"
        }
    }
}

// MARK: - Error Categories

enum ErrorCategory: String, CaseIterable, Sendable, Codable {
    case camera = "camera"
    case audio = "audio"
    case video = "video"
    case storage = "storage"
    case network = "network"
    case permission = "permission"
    case system = "system"
    case ui = "ui"
    case unknown = "unknown"
}

// MARK: - Error Severity

enum ErrorSeverity: String, CaseIterable, Sendable, Codable {
    case info = "info"
    case warning = "warning"
    case error = "error"
    case critical = "critical"
    
    var color: Color {
        switch self {
        case .info:
            return .blue
        case .warning:
            return .orange
        case .error:
            return .red
        case .critical:
            return .purple
        }
    }
    
    var icon: String {
        switch self {
        case .info:
            return "info.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .error:
            return "xmark.circle.fill"
        case .critical:
            return "exclamationmark.octagon.fill"
        }
    }
}

// MARK: - Error Handler Protocol

protocol ErrorHandler: Sendable, Identifiable {
    func canHandle(_ errorRecord: ErrorRecord) async -> Bool
    func handle(_ errorRecord: ErrorRecord) async
}

// MARK: - Default Error Handlers

struct CameraErrorHandler: ErrorHandler {
    let id = "camera_error_handler"
    
    func canHandle(_ errorRecord: ErrorRecord) async -> Bool {
        return errorRecord.category == .camera
    }
    
    func handle(_ errorRecord: ErrorRecord) async {
        // Handle camera-specific errors
        // This could include restarting camera session, switching cameras, etc.
    }
}

struct AudioErrorHandler: ErrorHandler {
    let id = "audio_error_handler"
    
    func canHandle(_ errorRecord: ErrorRecord) async -> Bool {
        return errorRecord.category == .audio
    }
    
    func handle(_ errorRecord: ErrorRecord) async {
        // Handle audio-specific errors
        // This could include restarting audio session, changing audio format, etc.
    }
}

struct VideoErrorHandler: ErrorHandler {
    let id = "video_error_handler"
    
    func canHandle(_ errorRecord: ErrorRecord) async -> Bool {
        return errorRecord.category == .video
    }
    
    func handle(_ errorRecord: ErrorRecord) async {
        // Handle video-specific errors
        // This could include changing video quality, restarting recording, etc.
    }
}

struct StorageErrorHandler: ErrorHandler {
    let id = "storage_error_handler"
    
    func canHandle(_ errorRecord: ErrorRecord) async -> Bool {
        return errorRecord.category == .storage
    }
    
    func handle(_ errorRecord: ErrorRecord) async {
        // Handle storage-specific errors
        // This could include clearing cache, changing storage location, etc.
    }
}

struct NetworkErrorHandler: ErrorHandler {
    let id = "network_error_handler"
    
    func canHandle(_ errorRecord: ErrorRecord) async -> Bool {
        return errorRecord.category == .network
    }
    
    func handle(_ errorRecord: ErrorRecord) async {
        // Handle network-specific errors
        // This could include retrying requests, switching to offline mode, etc.
    }
}

struct SystemErrorHandler: ErrorHandler {
    let id = "system_error_handler"
    
    func canHandle(_ errorRecord: ErrorRecord) async -> Bool {
        return errorRecord.category == .system
    }
    
    func handle(_ errorRecord: ErrorRecord) async {
        // Handle system-specific errors
        // This could include restarting components, checking system resources, etc.
    }
}

// MARK: - Error Report

struct ErrorReport: Sendable, Codable {
    let generatedAt: Date
    let totalErrors: Int
    let criticalErrors: Int
    let errorErrors: Int
    let warningErrors: Int
    let infoErrors: Int
    let errorCategories: [ErrorCategory: Int]
    let errorSources: [String: Int]
    let mostCommonError: String?
    let errorTrend: ErrorTrend
    let systemHealth: SystemHealth
}

// MARK: - Error Trend

enum ErrorTrend: String, Sendable, Codable {
    case increasing = "increasing"
    case decreasing = "decreasing"
    case stable = "stable"
    
    var icon: String {
        switch self {
        case .increasing:
            return "arrow.up.right"
        case .decreasing:
            return "arrow.down.right"
        case .stable:
            return "arrow.right"
        }
    }
    
    var color: Color {
        switch self {
        case .increasing:
            return .red
        case .decreasing:
            return .green
        case .stable:
            return .blue
        }
    }
}

// MARK: - System Health

enum SystemHealth: String, Sendable, Codable {
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
    
    var description: String {
        switch self {
        case .excellent:
            return "System is running perfectly"
        case .good:
            return "System is running well"
        case .fair:
            return "System has some issues"
        case .poor:
            return "System has serious issues"
        }
    }
}