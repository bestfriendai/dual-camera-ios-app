//
//  AdvancedCameraControlsManager.swift
//  DualCameraApp
//
//  Advanced camera controls with independent exposure/focus and smooth zoom
//

import UIKit
import AVFoundation

class AdvancedCameraControlsManager {
    
    // MARK: - Properties
    
    private var frontCameraDevice: AVCaptureDevice?
    private var backCameraDevice: AVCaptureDevice?
    
    // Focus control
    private var frontFocusMode: AVCaptureDevice.FocusMode = .continuousAutoFocus
    private var backFocusMode: AVCaptureDevice.FocusMode = .continuousAutoFocus
    private var frontFocusPoint: CGPoint = CGPoint(x: 0.5, y: 0.5)
    private var backFocusPoint: CGPoint = CGPoint(x: 0.5, y: 0.5)
    
    // Exposure control
    private var frontExposureMode: AVCaptureDevice.ExposureMode = .continuousAutoExposure
    private var backExposureMode: AVCaptureDevice.ExposureMode = .continuousAutoExposure
    private var frontExposurePoint: CGPoint = CGPoint(x: 0.5, y: 0.5)
    private var backExposurePoint: CGPoint = CGPoint(x: 0.5, y: 0.5)
    private var frontTargetBias: Float = 0.0
    private var backTargetBias: Float = 0.0
    
    // Zoom control
    private var frontZoomFactor: Float = 1.0
    private var backZoomFactor: Float = 1.0
    private var frontMaxZoomFactor: Float = 1.0
    private var backMaxZoomFactor: Float = 1.0
    private var zoomVelocity: Float = 0.0
    private var lastZoomTime: CFTimeInterval = 0
    
    // White balance control
    private var frontWhiteBalanceMode: AVCaptureDevice.WhiteBalanceMode = .continuousAutoWhiteBalance
    private var backWhiteBalanceMode: AVCaptureDevice.WhiteBalanceMode = .continuousAutoWhiteBalance
    
    // Smooth zoom animation
    private var zoomDisplayLink: CADisplayLink?
    private var targetFrontZoom: Float = 1.0
    private var targetBackZoom: Float = 1.0
    
    // Callbacks
    var onFocusChanged: ((AVCaptureDevice.Position, CGPoint) -> Void)?
    var onExposureChanged: ((AVCaptureDevice.Position, CGPoint) -> Void)?
    var onZoomChanged: ((AVCaptureDevice.Position, Float) -> Void)?
    
    // MARK: - Initialization
    
    init(frontCamera: AVCaptureDevice?, backCamera: AVCaptureDevice?) {
        self.frontCameraDevice = frontCamera
        self.backCameraDevice = backCamera
        
        initializeMaxZoomFactors()
        loadSavedSettings()
    }
    
    // MARK: - Setup
    
    private func initializeMaxZoomFactors() {
        if let frontCamera = frontCameraDevice {
            frontMaxZoomFactor = Float(min(frontCamera.activeFormat.videoMaxZoomFactor, 10.0))
        }
        
        if let backCamera = backCameraDevice {
            backMaxZoomFactor = Float(min(backCamera.activeFormat.videoMaxZoomFactor, 10.0))
        }
    }
    
    private func loadSavedSettings() {
        let settings = SettingsManager.shared
        
        // Load focus settings
        frontFocusMode = settings.autoFocusEnabled ? .continuousAutoFocus : .locked
        backFocusMode = settings.autoFocusEnabled ? .continuousAutoFocus : .locked
        
        // Load zoom settings
        frontZoomFactor = 1.0
        backZoomFactor = 1.0
        targetFrontZoom = 1.0
        targetBackZoom = 1.0
    }
    
    // MARK: - Focus Control
    
    func setFocusMode(_ mode: AVCaptureDevice.FocusMode, for position: AVCaptureDevice.Position) {
        let device = getDevice(for: position)
        guard let cameraDevice = device else { return }
        
        do {
            try cameraDevice.lockForConfiguration()
            
            if cameraDevice.isFocusModeSupported(mode) {
                cameraDevice.focusMode = mode
                
                if position == .front {
                    frontFocusMode = mode
                } else {
                    backFocusMode = mode
                }
            }
            
            cameraDevice.unlockForConfiguration()
        } catch {
            print("Error setting focus mode: \(error)")
        }
    }
    
    func setFocusPoint(_ point: CGPoint, for position: AVCaptureDevice.Position) {
        let device = getDevice(for: position)
        guard let cameraDevice = device else { return }
        
        do {
            try cameraDevice.lockForConfiguration()
            
            if cameraDevice.isFocusPointOfInterestSupported {
                cameraDevice.focusPointOfInterest = point
                
                if position == .front {
                    frontFocusPoint = point
                } else {
                    backFocusPoint = point
                }
                
                onFocusChanged?(position, point)
            }
            
            cameraDevice.unlockForConfiguration()
        } catch {
            print("Error setting focus point: \(error)")
        }
    }
    
    func focusAtPoint(_ point: CGPoint, for position: AVCaptureDevice.Position) {
        let device = getDevice(for: position)
        guard let cameraDevice = device else { return }
        
        do {
            try cameraDevice.lockForConfiguration()
            
            // Set focus point
            if cameraDevice.isFocusPointOfInterestSupported {
                cameraDevice.focusPointOfInterest = point
            }
            
            // Set focus mode to auto-focus for a moment
            if cameraDevice.isFocusModeSupported(.autoFocus) {
                cameraDevice.focusMode = .autoFocus
            }
            
            // Set exposure point as well for better results
            if cameraDevice.isExposurePointOfInterestSupported {
                cameraDevice.exposurePointOfInterest = point
            }
            
            cameraDevice.unlockForConfiguration()
            
            // Reset to continuous focus after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.setFocusMode(.continuousAutoFocus, for: position)
            }
            
            // Save focus point
            if position == .front {
                frontFocusPoint = point
            } else {
                backFocusPoint = point
            }
            
            onFocusChanged?(position, point)
        } catch {
            print("Error focusing at point: \(error)")
        }
    }
    
    // MARK: - Exposure Control
    
    func setExposureMode(_ mode: AVCaptureDevice.ExposureMode, for position: AVCaptureDevice.Position) {
        let device = getDevice(for: position)
        guard let cameraDevice = device else { return }
        
        do {
            try cameraDevice.lockForConfiguration()
            
            if cameraDevice.isExposureModeSupported(mode) {
                cameraDevice.exposureMode = mode
                
                if position == .front {
                    frontExposureMode = mode
                } else {
                    backExposureMode = mode
                }
            }
            
            cameraDevice.unlockForConfiguration()
        } catch {
            print("Error setting exposure mode: \(error)")
        }
    }
    
    func setExposurePoint(_ point: CGPoint, for position: AVCaptureDevice.Position) {
        let device = getDevice(for: position)
        guard let cameraDevice = device else { return }
        
        do {
            try cameraDevice.lockForConfiguration()
            
            if cameraDevice.isExposurePointOfInterestSupported {
                cameraDevice.exposurePointOfInterest = point
                
                if position == .front {
                    frontExposurePoint = point
                } else {
                    backExposurePoint = point
                }
                
                onExposureChanged?(position, point)
            }
            
            cameraDevice.unlockForConfiguration()
        } catch {
            print("Error setting exposure point: \(error)")
        }
    }
    
    func setExposureTargetBias(_ bias: Float, for position: AVCaptureDevice.Position) {
        let device = getDevice(for: position)
        guard let cameraDevice = device else { return }
        
        do {
            try cameraDevice.lockForConfiguration()
            
            let minBias = cameraDevice.minExposureTargetBias
            let maxBias = cameraDevice.maxExposureTargetBias
            let clampedBias = max(minBias, min(maxBias, bias))
            
            cameraDevice.setExposureTargetBias(clampedBias)
                
            if position == .front {
                frontTargetBias = clampedBias
            } else {
                backTargetBias = clampedBias
            }
            
            cameraDevice.unlockForConfiguration()
        } catch {
            print("Error setting exposure target bias: \(error)")
        }
    }
    
    func adjustExposure(by delta: Float, for position: AVCaptureDevice.Position) {
        let device = getDevice(for: position)
        guard let cameraDevice = device else { return }
        
        let currentBias = position == .front ? frontTargetBias : backTargetBias
        let newBias = currentBias + delta
        setExposureTargetBias(newBias, for: position)
    }
    
    // MARK: - Zoom Control
    
    func setZoomFactor(_ factor: Float, for position: AVCaptureDevice.Position) {
        let device = getDevice(for: position)
        guard let cameraDevice = device else { return }
        
        let maxZoom = position == .front ? frontMaxZoomFactor : backMaxZoomFactor
        let clampedFactor = max(1.0, min(maxZoom, factor))
        
        do {
            try cameraDevice.lockForConfiguration()
            cameraDevice.videoZoomFactor = CGFloat(clampedFactor)
            cameraDevice.unlockForConfiguration()
            
            if position == .front {
                frontZoomFactor = clampedFactor
            } else {
                backZoomFactor = clampedFactor
            }
            
            onZoomChanged?(position, clampedFactor)
        } catch {
            print("Error setting zoom factor: \(error)")
        }
    }
    
    func setZoomFactorSmoothly(_ factor: Float, for position: AVCaptureDevice.Position) {
        let maxZoom = position == .front ? frontMaxZoomFactor : backMaxZoomFactor
        let clampedFactor = max(1.0, min(maxZoom, factor))
        
        if position == .front {
            targetFrontZoom = clampedFactor
        } else {
            targetBackZoom = clampedFactor
        }
        
        startSmoothZoomAnimation()
    }
    
    func zoom(by delta: Float, for position: AVCaptureDevice.Position) {
        let currentZoom = position == .front ? frontZoomFactor : backZoomFactor
        let newZoom = currentZoom + delta
        setZoomFactorSmoothly(newZoom, for: position)
    }
    
    func resetZoom(for position: AVCaptureDevice.Position) {
        setZoomFactorSmoothly(1.0, for: position)
    }
    
    private func startSmoothZoomAnimation() {
        if zoomDisplayLink == nil {
            zoomDisplayLink = CADisplayLink(target: self, selector: #selector(updateZoomAnimation))
            zoomDisplayLink?.add(to: .main, forMode: .common)
        }
    }
    
    @objc private func updateZoomAnimation() {
        let currentTime = CACurrentMediaTime()
        let deltaTime = currentTime - lastZoomTime
        lastZoomTime = currentTime
        
        // Update front zoom
        let frontDelta = targetFrontZoom - frontZoomFactor
        if abs(frontDelta) > 0.01 {
            let frontStep = Float(deltaTime) * 2.0 // Zoom speed
            frontZoomFactor += frontDelta * frontStep
            setZoomFactor(frontZoomFactor, for: .front)
        }
        
        // Update back zoom
        let backDelta = targetBackZoom - backZoomFactor
        if abs(backDelta) > 0.01 {
            let backStep = Float(deltaTime) * 2.0 // Zoom speed
            backZoomFactor += backDelta * backStep
            setZoomFactor(backZoomFactor, for: .back)
        }
        
        // Stop animation if both zooms are at target
        if abs(frontDelta) <= 0.01 && abs(backDelta) <= 0.01 {
            stopSmoothZoomAnimation()
        }
    }
    
    private func stopSmoothZoomAnimation() {
        zoomDisplayLink?.invalidate()
        zoomDisplayLink = nil
    }
    
    // MARK: - White Balance Control
    
    func setWhiteBalanceMode(_ mode: AVCaptureDevice.WhiteBalanceMode, for position: AVCaptureDevice.Position) {
        let device = getDevice(for: position)
        guard let cameraDevice = device else { return }
        
        do {
            try cameraDevice.lockForConfiguration()
            
            if cameraDevice.isWhiteBalanceModeSupported(mode) {
                cameraDevice.whiteBalanceMode = mode
                
                if position == .front {
                    frontWhiteBalanceMode = mode
                } else {
                    backWhiteBalanceMode = mode
                }
            }
            
            cameraDevice.unlockForConfiguration()
        } catch {
            print("Error setting white balance mode: \(error)")
        }
    }
    
    func setWhiteBalanceTemperature(_ temperature: Float, for position: AVCaptureDevice.Position) {
        let device = getDevice(for: position)
        guard let cameraDevice = device else { return }
        
        do {
            try cameraDevice.lockForConfiguration()
            
            if cameraDevice.isWhiteBalanceModeSupported(.locked) {
                let temperatureAndTint = AVCaptureDevice.WhiteBalanceTemperatureAndTintValues(temperature: temperature, tint: 0)
                let whiteBalanceGains = cameraDevice.deviceWhiteBalanceGains(for: temperatureAndTint)
                
                cameraDevice.setWhiteBalanceModeLocked(with: whiteBalanceGains, completionHandler: nil)
            }
            
            cameraDevice.unlockForConfiguration()
        } catch {
            print("Error setting white balance temperature: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func getDevice(for position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        switch position {
        case .front:
            return frontCameraDevice
        case .back:
            return backCameraDevice
        default:
            return nil
        }
    }
    
    // MARK: - Public Properties
    
    var currentFrontZoomFactor: Float {
        return frontZoomFactor
    }
    
    var currentBackZoomFactor: Float {
        return backZoomFactor
    }
    
    var maxFrontZoomFactor: Float {
        return frontMaxZoomFactor
    }
    
    var maxBackZoomFactor: Float {
        return backMaxZoomFactor
    }
    
    var currentFrontFocusPoint: CGPoint {
        return frontFocusPoint
    }
    
    var currentBackFocusPoint: CGPoint {
        return backFocusPoint
    }
    
    var currentFrontExposureBias: Float {
        return frontTargetBias
    }
    
    var currentBackExposureBias: Float {
        return backTargetBias
    }
    
    // MARK: - Reset Methods
    
    func resetAllControls() {
        resetZoom(for: .front)
        resetZoom(for: .back)
        setFocusMode(.continuousAutoFocus, for: .front)
        setFocusMode(.continuousAutoFocus, for: .back)
        setExposureMode(.continuousAutoExposure, for: .front)
        setExposureMode(.continuousAutoExposure, for: .back)
        setWhiteBalanceMode(.continuousAutoWhiteBalance, for: .front)
        setWhiteBalanceMode(.continuousAutoWhiteBalance, for: .back)
    }
    
    deinit {
        stopSmoothZoomAnimation()
    }
}