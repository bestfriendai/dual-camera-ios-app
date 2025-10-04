//
//  AppState.swift
//  DualApp
//
//  Created by DualApp Team on 10/3/25.
//

import SwiftUI
import Combine

// MARK: - App State

@MainActor
class AppState: ObservableObject {
    // MARK: - Published Properties
    
    @Published var isInitialized = false
    @Published var currentTab: AppTab = .recording
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var showingError = false
    @Published var showingSuccess = false
    @Published var activeError: ErrorRecord?
    @Published var showingErrorModal = false
    @Published var showingDiagnosticReport = false
    @Published var diagnosticReport: DiagnosticReport?
    @Published var showingErrorReport = false
    @Published var errorReport: ErrorReport?
    
    // MARK: - Managers
    
    private let settingsManager = SettingsManager.shared
    private let errorHandlingManager = ErrorHandlingManager.shared
    private let diagnosticsManager = DiagnosticsManager.shared
    
    // MARK: - Cancellables
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {
        setupApp()
        setupBindings()
    }
    
    // MARK: - Private Methods
    
    private func setupApp() {
        isLoading = true
        
        Task {
            await initializeComponents()
            await MainActor.run {
                self.isInitialized = true
                self.isLoading = false
            }
        }
    }
    
    private func initializeComponents() async {
        // Initialize settings manager
        await settingsManager.initializeSystem()
        
        // Initialize error handling manager
        await errorHandlingManager.initializeSystem()
        
        // Initialize diagnostics manager
        await diagnosticsManager.startMonitoring()
    }
    
    private func setupBindings() {
        // Listen to error handling events
        Task {
            for await event in errorHandlingManager.events {
                await handleErrorEvent(event)
            }
        }
        
        // Listen to settings events
        Task {
            for await event in settingsManager.events {
                await handleSettingsEvent(event)
            }
        }
        
        // Listen to diagnostics events
        Task {
            for await event in diagnosticsManager.events {
                await handleDiagnosticsEvent(event)
            }
        }
    }
    
    // MARK: - Error Handling
    
    private func handleErrorEvent(_ event: ErrorEvent) async {
        await MainActor.run {
            switch event {
            case .errorOccurred(let errorRecord):
                handleNewError(errorRecord)
            case .criticalErrorOccurred:
                handleCriticalError()
            case .errorDismissed:
                activeError = nil
                showingErrorModal = false
            case .reportGenerated(let report):
                errorReport = report
                showingErrorReport = true
            default:
                break
            }
        }
    }
    
    private func handleNewError(_ errorRecord: ErrorRecord) {
        // Store the active error
        activeError = errorRecord
        
        // Show error based on severity
        switch errorRecord.severity {
        case .critical:
            showingErrorModal = true
        case .error:
            showingErrorModal = true
        case .warning:
            // Show banner for warnings
            showingError = true
            errorMessage = errorRecord.localizedDescription
            
            // Auto-hide after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.showingError = false
                self.errorMessage = nil
            }
        case .info:
            // Show banner for info
            showingError = true
            errorMessage = errorRecord.localizedDescription
            
            // Auto-hide after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.showingError = false
                self.errorMessage = nil
            }
        }
    }
    
    private func handleCriticalError() {
        // Handle critical errors
        // This could include saving state, stopping operations, etc.
    }
    
    // MARK: - Settings Handling
    
    private func handleSettingsEvent(_ event: SettingsEvent) async {
        await MainActor.run {
            switch event {
            case .settingsChanged:
                // Settings changed
                break
            case .cloudSyncChanged:
                // Cloud sync status changed
                break
            case .cloudSyncCompleted:
                // Cloud sync completed
                showSuccess("Settings synced successfully")
            case .cloudSyncError(let error):
                // Cloud sync error
                showError("Failed to sync settings: \(error.localizedDescription)")
            default:
                break
            }
        }
    }
    
    // MARK: - Diagnostics Handling
    
    private func handleDiagnosticsEvent(_ event: DiagnosticsEvent) async {
        await MainActor.run {
            switch event {
            case .reportGenerated(let report):
                diagnosticReport = report
                showingDiagnosticReport = true
            case .issuesDetected(let issues):
                // Handle detected issues
                if issues.contains(where: { $0.severity == .error || $0.severity == .critical }) {
                    showError("System issues detected. Check diagnostics for details.")
                }
            default:
                break
            }
        }
    }
    
    // MARK: - Public Methods
    
    func handleError(_ error: Error, context: ErrorContext? = nil, severity: ErrorSeverity = .error) {
        Task {
            await errorHandlingManager.handleError(error, context: context, severity: severity)
        }
    }
    
    func dismissError() {
        Task {
            if let errorId = activeError?.id {
                await errorHandlingManager.dismissError(errorId)
            }
        }
    }
    
    func dismissAllErrors() {
        Task {
            await errorHandlingManager.dismissAllErrors()
        }
    }
    
    func runDiagnostics() {
        Task {
            isLoading = true
            
            let report = await diagnosticsManager.generateDiagnosticReport()
            
            await MainActor.run {
                self.diagnosticReport = report
                self.showingDiagnosticReport = true
                self.isLoading = false
            }
        }
    }
    
    func generateErrorReport() {
        Task {
            isLoading = true
            
            let report = await errorHandlingManager.generateErrorReport()
            
            await MainActor.run {
                self.errorReport = report
                self.showingErrorReport = true
                self.isLoading = false
            }
        }
    }
    
    func showError(_ message: String) {
        errorMessage = message
        showingError = true
        
        // Auto-hide after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.showingError = false
            self.errorMessage = nil
        }
    }
    
    func showSuccess(_ message: String) {
        successMessage = message
        showingSuccess = true
        
        // Auto-hide after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.showingSuccess = false
            self.successMessage = nil
        }
    }
    
    func switchTab(_ tab: AppTab) {
        currentTab = tab
    }
}

// MARK: - App State Extensions

extension AppState {
    // MARK: - Settings Convenience Methods
    
    func getSettings() async -> UserSettings {
        return await settingsManager.getSettings()
    }
    
    func updateSettings(_ settings: UserSettings) {
        Task {
            do {
                try await settingsManager.updateSettings(settings)
            } catch {
                await MainActor.run {
                    self.showError("Failed to update settings: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func resetSettings() {
        Task {
            do {
                try await settingsManager.resetToDefaults()
                await MainActor.run {
                    self.showSuccess("Settings reset to defaults")
                }
            } catch {
                await MainActor.run {
                    self.showError("Failed to reset settings: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Error Handling Convenience Methods
    
    func getActiveErrors() async -> [ErrorRecord] {
        return await errorHandlingManager.getActiveErrors()
    }
    
    func getErrorHistory() async -> [ErrorRecord] {
        return await errorHandlingManager.getErrorHistory()
    }
    
    // MARK: - Diagnostics Convenience Methods
    
    func getPerformanceMetrics() async -> PerformanceMetrics {
        return await diagnosticsManager.getPerformanceMetrics()
    }
    
    func getSystemMetrics() async -> SystemMetrics {
        return await diagnosticsManager.getSystemMetrics()
    }
    
    func getAppMetrics() async -> AppMetrics {
        return await diagnosticsManager.getAppMetrics()
    }
    
    func runSystemHealthCheck() async -> SystemHealthCheck {
        return await diagnosticsManager.runSystemHealthCheck()
    }
}

// MARK: - Error Handling Manager Extensions

extension ErrorHandlingManager {
    func initializeSystem() async {
        // Initialize error handling system
        // This would set up default error handlers, crash reporting, etc.
    }
}

// MARK: - Settings Manager Extensions

extension SettingsManager {
    func initializeSystem() async {
        // Initialize settings system
        // This would load settings, set up cloud sync, etc.
    }
}