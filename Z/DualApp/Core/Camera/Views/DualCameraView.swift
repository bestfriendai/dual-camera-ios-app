//
//  DualCameraView.swift
//  DualApp
//
//  Created by DualApp Team on 10/3/25.
//

import SwiftUI
import AVFoundation

// MARK: - Dual Camera View

struct DualCameraView: View {
    
    // MARK: - Properties
    
    @StateObject private var dualCameraSession = DualCameraSession()
    @State private var configuration: CameraConfiguration = .default
    @State private var isRecording: Bool = false
    @State private var selectedCamera: CameraPosition = .back
    @State private var renderMode: RenderMode = .sideBySide
    @State private var filter: RenderFilter = .none
    @State private var showComposite: Bool = true
    @State private var frontZoomLevel: Float = 1.0
    @State private var backZoomLevel: Float = 1.0
    @State private var showingPermissionAlert: Bool = false
    @State private var permissionError: Error?
    
    // MARK: - Performance Monitoring
    
    @State private var performanceMetrics: DualCameraPerformanceMetrics?
    @State private var showingPerformanceAlert: Bool = false
    @State private var performanceAlertMessage: String = ""
    
    // MARK: - Error Handling
    
    @State private var showingErrorAlert: Bool = false
    @State private var errorMessage: String = ""
    
    // MARK: - Initialization
    
    init() {
        // Request camera permissions
        requestCameraPermissions()
    }
    
    // MARK: - Body
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Camera preview
                cameraPreview
                
                // Camera controls
                cameraControls
                    .cameraPreviewOverlay(
                        dualCameraSession: dualCameraSession,
                        renderMode: $renderMode,
                        filter: $filter,
                        isRecording: $isRecording,
                        showComposite: $showComposite,
                        selectedCamera: $selectedCamera,
                        frontZoomLevel: $frontZoomLevel,
                        backZoomLevel: $backZoomLevel
                    )
                
                // Performance warning overlay
                if showingPerformanceAlert {
                    performanceWarningOverlay
                }
                
                // Error overlay
                if showingErrorAlert {
                    errorOverlay
                }
                
                // Permission overlay
                if showingPermissionAlert {
                    permissionOverlay
                }
            }
        }
        .onAppear {
            setupDualCameraSession()
        }
        .onDisappear {
            cleanupDualCameraSession()
        }
        .alert("Error", isPresented: $showingErrorAlert) {
            Button("OK") {
                showingErrorAlert = false
            }
        } message: {
            Text(errorMessage)
        }
        .alert("Performance Warning", isPresented: $showingPerformanceAlert) {
            Button("OK") {
                showingPerformanceAlert = false
            }
        } message: {
            Text(performanceAlertMessage)
        }
        .alert("Camera Permission", isPresented: $showingPermissionAlert) {
            Button("Settings") {
                openAppSettings()
            }
            Button("Cancel", role: .cancel) {
                showingPermissionAlert = false
            }
        } message: {
            Text("Camera permission is required to use this feature. Please enable it in Settings.")
        }
    }
    
    // MARK: - Camera Preview
    
    private var cameraPreview: some View {
        DualCameraPreviewView(
            dualCameraSession: dualCameraSession,
            renderMode: $renderMode,
            filter: $filter,
            isRecording: $isRecording,
            showComposite: $showComposite,
            selectedCamera: $selectedCamera,
            frontZoomLevel: $frontZoomLevel,
            backZoomLevel: $backZoomLevel
        )
    }
    
    // MARK: - Camera Controls
    
    private var cameraControls: some View {
        CameraControlsView(
            dualCameraSession: dualCameraSession,
            configuration: $configuration,
            isRecording: $isRecording,
            selectedCamera: $selectedCamera,
            renderMode: $renderMode,
            showComposite: $showComposite
        )
    }
    
    // MARK: - Performance Warning Overlay
    
    private var performanceWarningOverlay: some View {
        VStack {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.yellow)
                    .font(.title)
                
                Text("Performance Warning")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: {
                    showingPerformanceAlert = false
                }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.white)
                        .font(.title2)
                }
            }
            .padding()
            .background(Color.black.opacity(0.8))
            .cornerRadius(12)
            .padding(.horizontal, 20)
            .padding(.top, 50)
            
            Spacer()
        }
    }
    
    // MARK: - Error Overlay
    
    private var errorOverlay: some View {
        VStack {
            HStack {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.red)
                    .font(.title)
                
                Text("Error")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: {
                    showingErrorAlert = false
                }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.white)
                        .font(.title2)
                }
            }
            .padding()
            .background(Color.black.opacity(0.8))
            .cornerRadius(12)
            .padding(.horizontal, 20)
            .padding(.top, 50)
            
            Spacer()
        }
    }
    
    // MARK: - Permission Overlay
    
    private var permissionOverlay: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 20) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.white)
                
                Text("Camera Permission Required")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text("Please grant camera permission to use the dual camera feature.")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                
                Button(action: {
                    requestCameraPermissions()
                }) {
                    Text("Grant Permission")
                        .font(.headline)
                        .foregroundColor(.black)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 12)
                        .background(Color.white)
                        .cornerRadius(25)
                }
            }
            .padding(30)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 40)
            .padding(.bottom, 50)
        }
        .background(Color.black.opacity(0.5))
    }
    
    // MARK: - Setup Methods
    
    private func setupDualCameraSession() {
        Task {
            do {
                // Initialize dual camera session
                try await dualCameraSession.initializeSession()
                
                // Configure session
                try await dualCameraSession.configureSession(with: configuration)
                
                // Start session
                try await dualCameraSession.startSession()
                
                // Monitor for events
                await monitorDualCameraEvents()
                
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingErrorAlert = true
                }
            }
        }
    }
    
    private func cleanupDualCameraSession() {
        Task {
            await dualCameraSession.stopSession()
        }
    }
    
    private func monitorDualCameraEvents() async {
        for await event in await dualCameraSession.events {
            await handleDualCameraEvent(event)
        }
    }
    
    private func handleDualCameraEvent(_ event: DualCameraEvent) async {
        await MainActor.run {
            switch event {
            case .stateChanged(let state):
                print("Camera state changed: \(state.description)")
                
            case .configurationUpdated(let config):
                configuration = config
                
            case .recordingStarted(let session):
                isRecording = true
                
            case .recordingStopped(let session):
                isRecording = false
                
            case .camerasSwitched:
                print("Cameras switched")
                
            case .zoomChanged(let zoom):
                if selectedCamera == .front {
                    frontZoomLevel = zoom
                } else {
                    backZoomLevel = zoom
                }
                
            case .focusChanged(let point, let position):
                print("Focus changed: \(point) for \(position.description)")
                
            case .exposureChanged(let bias, let position):
                print("Exposure changed: \(bias) for \(position.description)")
                
            case .error(let error):
                errorMessage = error.localizedDescription
                showingErrorAlert = true
                
            case .performanceWarning(let message):
                performanceAlertMessage = message
                showingPerformanceAlert = true
                
            case .thermalLimitReached:
                performanceAlertMessage = "Device is overheating. Recording quality may be reduced."
                showingPerformanceAlert = true
                
            case .batteryLevelLow:
                performanceAlertMessage = "Battery level is low. Consider connecting to a power source."
                showingPerformanceAlert = true
            }
        }
    }
    
    // MARK: - Permission Methods
    
    private func requestCameraPermissions() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                if granted {
                    self.showingPermissionAlert = false
                } else {
                    self.showingPermissionAlert = true
                }
            }
        }
    }
    
    private func openAppSettings() {
        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsURL)
        }
    }
}

// MARK: - Preview

struct DualCameraView_Previews: PreviewProvider {
    static var previews: some View {
        DualCameraView()
    }
}