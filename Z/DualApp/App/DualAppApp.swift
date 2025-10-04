//
//  DualAppApp.swift
//  DualApp
//
//  Created by DualApp Team on 10/3/25.
//

import SwiftUI
import Combine

@main
struct DualAppApp: App {
    // MARK: - App Properties
    
    @StateObject private var appState = AppState()
    
    // MARK: - App Body
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
                .onAppear {
                    // Initialize app
                    setupApp()
                }
        }
    }
    
    // MARK: - Private Methods
    
    private func setupApp() {
        // Set up global error handling
        setupGlobalErrorHandling()
        
        // Set up notifications
        setupNotifications()
    }
    
    private func setupGlobalErrorHandling() {
        // Set up global error handling for uncaught exceptions
        NSSetUncaughtExceptionHandler { exception in
            Task { @MainActor in
                appState.handleError(
                    NSError(domain: "UncaughtException", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: exception.reason ?? "Unknown exception",
                        "exceptionName": exception.name.rawValue,
                        "exceptionStack": exception.callStackSymbols.joined(separator: "\n")
                    ]),
                    context: ErrorContext(
                        component: "GlobalErrorHandler",
                        operation: "UncaughtException",
                        additionalInfo: [
                            "exceptionName": exception.name.rawValue,
                            "exceptionReason": exception.reason ?? "Unknown"
                        ]
                    ),
                    severity: .critical
                )
            }
        }
    }
    
    private func setupNotifications() {
        // Request notification permissions
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                Task { @MainActor in
                    appState.handleError(
                        error,
                        context: ErrorContext(
                            component: "NotificationManager",
                            operation: "RequestAuthorization"
                        ),
                        severity: .warning
                    )
                }
            }
        }
    }
}

// MARK: - App Tabs

enum AppTab: String, CaseIterable {
    case recording = "Recording"
    case gallery = "Gallery"
    case settings = "Settings"
    
    var systemImage: String {
        switch self {
        case .recording:
            return "camera.fill"
        case .gallery:
            return "photo.stack"
        case .settings:
            return "gearshape.fill"
        }
    }
}