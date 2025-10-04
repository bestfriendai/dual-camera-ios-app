//
//  PermissionManager.swift
//  DualApp
//
//  Created by DualApp Team on 10/3/25.
//

import Foundation
import AVFoundation
import Photos
import SwiftUI

// MARK: - Permission Manager Actor

actor PermissionManager: Sendable {
    // MARK: - State Properties
    
    private(set) var cameraStatus: PermissionStatus = .notDetermined
    private(set) var microphoneStatus: PermissionStatus = .notDetermined
    private(set) var photoLibraryStatus: PermissionStatus = .notDetermined
    
    // MARK: - Event Stream
    
    let events: AsyncStream<PermissionEvent>
    private let eventContinuation: AsyncStream<PermissionEvent>.Continuation
    
    // MARK: - Initialization
    
    init() {
        (self.events, self.eventContinuation) = AsyncStream<PermissionEvent>.makeStream()
        Task {
            await refreshPermissionStatuses()
        }
    }
    
    // MARK: - Public Interface
    
    func requestCameraPermission() async -> PermissionStatus {
        let status = await AVCaptureDevice.requestAccess(for: .video)
        cameraStatus = status ? .authorized : .denied
        eventContinuation.yield(.permissionChanged(.camera, cameraStatus))
        return cameraStatus
    }
    
    func requestMicrophonePermission() async -> PermissionStatus {
        let status = await AVCaptureDevice.requestAccess(for: .audio)
        microphoneStatus = status ? .authorized : .denied
        eventContinuation.yield(.permissionChanged(.microphone, microphoneStatus))
        return microphoneStatus
    }
    
    func requestPhotoLibraryPermission() async -> PermissionStatus {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        photoLibraryStatus = PermissionStatus(from: status)
        eventContinuation.yield(.permissionChanged(.photoLibrary, photoLibraryStatus))
        return photoLibraryStatus
    }
    
    func requestAllPermissions() async -> [PermissionType: PermissionStatus] {
        let cameraStatus = await requestCameraPermission()
        let microphoneStatus = await requestMicrophonePermission()
        let photoLibraryStatus = await requestPhotoLibraryPermission()
        
        return [
            .camera: cameraStatus,
            .microphone: microphoneStatus,
            .photoLibrary: photoLibraryStatus
        ]
    }
    
    func openAppSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        
        UIApplication.shared.open(settingsURL)
    }
    
    // MARK: - Private Methods
    
    private func refreshPermissionStatuses() async {
        // Camera permission
        let cameraAuthStatus = AVCaptureDevice.authorizationStatus(for: .video)
        cameraStatus = PermissionStatus(from: cameraAuthStatus as AVAuthorizationStatus)
        
        // Microphone permission
        let microphoneAuthStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        microphoneStatus = PermissionStatus(from: microphoneAuthStatus as AVAuthorizationStatus)
        
        // Photo library permission
        let photoLibraryAuthStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        photoLibraryStatus = PermissionStatus(from: photoLibraryAuthStatus)
    }
}

// MARK: - Permission Status Extension

extension PermissionStatus {
    init(from phStatus: PHAuthorizationStatus) {
        switch phStatus {
        case .notDetermined:
            self = .notDetermined
        case .authorized:
            self = .authorized
        case .denied:
            self = .denied
        case .restricted:
            self = .restricted
        case .limited:
            self = .limited
        @unknown default:
            self = .notDetermined
        }
    }
    
    init(from avStatus: AVAuthorizationStatus) {
        switch avStatus {
        case .notDetermined:
            self = .notDetermined
        case .authorized:
            self = .authorized
        case .denied:
            self = .denied
        case .restricted:
            self = .restricted
        @unknown default:
            self = .notDetermined
        }
    }
    
    var isAuthorized: Bool {
        switch self {
        case .authorized, .limited:
            return true
        default:
            return false
        }
    }
    
    var canRequestPermission: Bool {
        switch self {
        case .notDetermined:
            return true
        default:
            return false
        }
    }
}

// MARK: - Permission Event

enum PermissionEvent: Sendable {
    case permissionChanged(PermissionType, PermissionStatus)
    case allPermissionsRequested([PermissionType: PermissionStatus])
}

// MARK: - Permission Error

enum PermissionError: LocalizedError, Sendable {
    case permissionDenied(PermissionType)
    case permissionRestricted(PermissionType)
    case systemError(String)
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied(let type):
            return "\(type.rawValue) permission was denied"
        case .permissionRestricted(let type):
            return "\(type.rawValue) permission is restricted"
        case .systemError(let message):
            return "System error: \(message)"
        }
    }
}