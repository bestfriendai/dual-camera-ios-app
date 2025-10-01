import AVFoundation
import os.log
//
//  CameraControlsView.swift
//  DualCameraApp
//
//  Advanced camera controls UI with focus, exposure, and zoom controls
//

import UIKit

class CameraControlsView: UIView {
    
    // MARK: - Properties
    
    private let containerView = UIView()
    private let titleLabel = UILabel()
    private let controlsStackView = UIStackView()
    
    // Focus controls
    private let focusControlContainer = UIView()
    private let focusLabel = UILabel()
    private let focusSegmentedControl = UISegmentedControl(items: ["Auto", "Manual"])
    private let focusSlider = UISlider()
    private let resetFocusButton = UIButton(type: .system)
    
    // Exposure controls
    private let exposureControlContainer = UIView()
    private let exposureLabel = UILabel()
    private let exposureSegmentedControl = UISegmentedControl(items: ["Auto", "Manual"])
    private let exposureSlider = UISlider()
    private let resetExposureButton = UIButton(type: .system)
    
    // Zoom controls
    private let zoomControlContainer = UIView()
    private let zoomLabel = UILabel()
    private let zoomSlider = UISlider()
    private let resetZoomButton = UIButton(type: .system)
    
    // Camera selector
    private let cameraSelector = UISegmentedControl(items: ["Front", "Back"])
    private var selectedCamera: AVCaptureDevice.Position = .back
    
    // Advanced controls manager
    private var advancedControlsManager: AdvancedCameraControlsManager?
    
    // Callbacks
    var onControlsChanged: (() -> Void)?
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    // MARK: - Setup
    
    private func setupView() {
        backgroundColor = .clear
        
        setupContainerView()
        setupTitleLabel()
        setupCameraSelector()
        setupControlsStackView()
        setupFocusControls()
        setupExposureControls()
        setupZoomControls()
        setupConstraints()
        
        updateUIForSelectedCamera()
    }
    
    private func setupContainerView() {
        containerView.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        containerView.layer.cornerRadius = 16
        containerView.layer.borderWidth = 1
        containerView.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(containerView)
    }
    
    private func setupTitleLabel() {
        titleLabel.text = "Advanced Camera Controls"
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(titleLabel)
    }
    
    private func setupCameraSelector() {
        cameraSelector.selectedSegmentIndex = 1 // Back camera by default
        cameraSelector.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        cameraSelector.selectedSegmentTintColor = UIColor.systemBlue.withAlphaComponent(0.7)
        cameraSelector.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .normal)
        cameraSelector.setTitleTextAttributes([.foregroundColor: UIColor.black], for: .selected)
        cameraSelector.layer.cornerRadius = 8
        cameraSelector.translatesAutoresizingMaskIntoConstraints = false
        
        cameraSelector.addTarget(self, action: #selector(cameraChanged(_:)), for: .valueChanged)
        
        containerView.addSubview(cameraSelector)
    }
    
    private func setupControlsStackView() {
        controlsStackView.axis = .vertical
        controlsStackView.spacing = 16
        controlsStackView.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(controlsStackView)
    }
    
    private func setupFocusControls() {
        focusLabel.text = "Focus"
        focusLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        focusLabel.textColor = .white
        focusLabel.translatesAutoresizingMaskIntoConstraints = false
        
        focusSegmentedControl.selectedSegmentIndex = 0
        focusSegmentedControl.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        focusSegmentedControl.selectedSegmentTintColor = UIColor.systemBlue.withAlphaComponent(0.7)
        focusSegmentedControl.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .normal)
        focusSegmentedControl.setTitleTextAttributes([.foregroundColor: UIColor.black], for: .selected)
        focusSegmentedControl.translatesAutoresizingMaskIntoConstraints = false
        
        focusSegmentedControl.addTarget(self, action: #selector(focusModeChanged(_:)), for: .valueChanged)
        
        focusSlider.minimumValue = 0.0
        focusSlider.maximumValue = 1.0
        focusSlider.value = 0.5
        focusSlider.tintColor = .systemBlue
        focusSlider.translatesAutoresizingMaskIntoConstraints = false
        focusSlider.addTarget(self, action: #selector(focusValueChanged(_:)), for: .valueChanged)
        
        resetFocusButton.setTitle("Reset", for: .normal)
        resetFocusButton.setTitleColor(.systemBlue, for: .normal)
        resetFocusButton.translatesAutoresizingMaskIntoConstraints = false
        resetFocusButton.addTarget(self, action: #selector(resetFocusTapped(_:)), for: .touchUpInside)
        
        focusControlContainer.addSubview(focusLabel)
        focusControlContainer.addSubview(focusSegmentedControl)
        focusControlContainer.addSubview(focusSlider)
        focusControlContainer.addSubview(resetFocusButton)
        
        controlsStackView.addArrangedSubview(focusControlContainer)
    }
    
    private func setupExposureControls() {
        exposureLabel.text = "Exposure"
        exposureLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        exposureLabel.textColor = .white
        exposureLabel.translatesAutoresizingMaskIntoConstraints = false
        
        exposureSegmentedControl.selectedSegmentIndex = 0
        exposureSegmentedControl.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        exposureSegmentedControl.selectedSegmentTintColor = UIColor.systemBlue.withAlphaComponent(0.7)
        exposureSegmentedControl.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .normal)
        exposureSegmentedControl.setTitleTextAttributes([.foregroundColor: UIColor.black], for: .selected)
        exposureSegmentedControl.translatesAutoresizingMaskIntoConstraints = false
        
        exposureSegmentedControl.addTarget(self, action: #selector(exposureModeChanged(_:)), for: .valueChanged)
        
        exposureSlider.minimumValue = -2.0
        exposureSlider.maximumValue = 2.0
        exposureSlider.value = 0.0
        exposureSlider.tintColor = .systemBlue
        exposureSlider.translatesAutoresizingMaskIntoConstraints = false
        exposureSlider.addTarget(self, action: #selector(exposureValueChanged(_:)), for: .valueChanged)
        
        resetExposureButton.setTitle("Reset", for: .normal)
        resetExposureButton.setTitleColor(.systemBlue, for: .normal)
        resetExposureButton.translatesAutoresizingMaskIntoConstraints = false
        resetExposureButton.addTarget(self, action: #selector(resetExposureTapped(_:)), for: .touchUpInside)
        
        exposureControlContainer.addSubview(exposureLabel)
        exposureControlContainer.addSubview(exposureSegmentedControl)
        exposureControlContainer.addSubview(exposureSlider)
        exposureControlContainer.addSubview(resetExposureButton)
        
        controlsStackView.addArrangedSubview(exposureControlContainer)
    }
    
    private func setupZoomControls() {
        zoomLabel.text = "Zoom"
        zoomLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        zoomLabel.textColor = .white
        zoomLabel.translatesAutoresizingMaskIntoConstraints = false
        
        zoomSlider.minimumValue = 1.0
        zoomSlider.maximumValue = 5.0
        zoomSlider.value = 1.0
        zoomSlider.tintColor = .systemBlue
        zoomSlider.translatesAutoresizingMaskIntoConstraints = false
        zoomSlider.addTarget(self, action: #selector(zoomValueChanged(_:)), for: .valueChanged)
        
        resetZoomButton.setTitle("Reset", for: .normal)
        resetZoomButton.setTitleColor(.systemBlue, for: .normal)
        resetZoomButton.translatesAutoresizingMaskIntoConstraints = false
        resetZoomButton.addTarget(self, action: #selector(resetZoomTapped(_:)), for: .touchUpInside)
        
        zoomControlContainer.addSubview(zoomLabel)
        zoomControlContainer.addSubview(zoomSlider)
        zoomControlContainer.addSubview(resetZoomButton)
        
        controlsStackView.addArrangedSubview(zoomControlContainer)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            cameraSelector.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            cameraSelector.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            cameraSelector.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            cameraSelector.heightAnchor.constraint(equalToConstant: 32),
            
            controlsStackView.topAnchor.constraint(equalTo: cameraSelector.bottomAnchor, constant: 16),
            controlsStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            controlsStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            controlsStackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16),
            
            // Focus controls
            focusLabel.topAnchor.constraint(equalTo: focusControlContainer.topAnchor),
            focusLabel.leadingAnchor.constraint(equalTo: focusControlContainer.leadingAnchor),
            focusLabel.trailingAnchor.constraint(equalTo: focusControlContainer.trailingAnchor),
            
            focusSegmentedControl.topAnchor.constraint(equalTo: focusLabel.bottomAnchor, constant: 8),
            focusSegmentedControl.leadingAnchor.constraint(equalTo: focusControlContainer.leadingAnchor),
            focusSegmentedControl.trailingAnchor.constraint(equalTo: focusControlContainer.trailingAnchor),
            focusSegmentedControl.heightAnchor.constraint(equalToConstant: 28),
            
            focusSlider.topAnchor.constraint(equalTo: focusSegmentedControl.bottomAnchor, constant: 8),
            focusSlider.leadingAnchor.constraint(equalTo: focusControlContainer.leadingAnchor),
            focusSlider.trailingAnchor.constraint(equalTo: focusControlContainer.trailingAnchor),
            
            resetFocusButton.topAnchor.constraint(equalTo: focusSlider.bottomAnchor, constant: 8),
            resetFocusButton.trailingAnchor.constraint(equalTo: focusControlContainer.trailingAnchor),
            resetFocusButton.bottomAnchor.constraint(equalTo: focusControlContainer.bottomAnchor),
            
            // Exposure controls
            exposureLabel.topAnchor.constraint(equalTo: exposureControlContainer.topAnchor),
            exposureLabel.leadingAnchor.constraint(equalTo: exposureControlContainer.leadingAnchor),
            exposureLabel.trailingAnchor.constraint(equalTo: exposureControlContainer.trailingAnchor),
            
            exposureSegmentedControl.topAnchor.constraint(equalTo: exposureLabel.bottomAnchor, constant: 8),
            exposureSegmentedControl.leadingAnchor.constraint(equalTo: exposureControlContainer.leadingAnchor),
            exposureSegmentedControl.trailingAnchor.constraint(equalTo: exposureControlContainer.trailingAnchor),
            exposureSegmentedControl.heightAnchor.constraint(equalToConstant: 28),
            
            exposureSlider.topAnchor.constraint(equalTo: exposureSegmentedControl.bottomAnchor, constant: 8),
            exposureSlider.leadingAnchor.constraint(equalTo: exposureControlContainer.leadingAnchor),
            exposureSlider.trailingAnchor.constraint(equalTo: exposureControlContainer.trailingAnchor),
            
            resetExposureButton.topAnchor.constraint(equalTo: exposureSlider.bottomAnchor, constant: 8),
            resetExposureButton.trailingAnchor.constraint(equalTo: exposureControlContainer.trailingAnchor),
            resetExposureButton.bottomAnchor.constraint(equalTo: exposureControlContainer.bottomAnchor),
            
            // Zoom controls
            zoomLabel.topAnchor.constraint(equalTo: zoomControlContainer.topAnchor),
            zoomLabel.leadingAnchor.constraint(equalTo: zoomControlContainer.leadingAnchor),
            zoomLabel.trailingAnchor.constraint(equalTo: zoomControlContainer.trailingAnchor),
            
            zoomSlider.topAnchor.constraint(equalTo: zoomLabel.bottomAnchor, constant: 8),
            zoomSlider.leadingAnchor.constraint(equalTo: zoomControlContainer.leadingAnchor),
            zoomSlider.trailingAnchor.constraint(equalTo: zoomControlContainer.trailingAnchor),
            
            resetZoomButton.topAnchor.constraint(equalTo: zoomSlider.bottomAnchor, constant: 8),
            resetZoomButton.trailingAnchor.constraint(equalTo: zoomControlContainer.trailingAnchor),
            resetZoomButton.bottomAnchor.constraint(equalTo: zoomControlContainer.bottomAnchor)
        ])
    }
    
    // MARK: - Actions
    
    @objc private func cameraChanged(_ sender: UISegmentedControl) {
        selectedCamera = sender.selectedSegmentIndex == 0 ? .front : .back
        updateUIForSelectedCamera()
        
        // Haptic feedback
        HapticFeedbackManager.shared.selectionChanged()
    }
    
    @objc private func focusModeChanged(_ sender: UISegmentedControl) {
        let mode: AVCaptureDevice.FocusMode = sender.selectedSegmentIndex == 0 ? .continuousAutoFocus : .locked
        advancedControlsManager?.setFocusMode(mode, for: selectedCamera)
        
        // Enable/disable focus slider based on mode
        focusSlider.isEnabled = (sender.selectedSegmentIndex == 1)
        
        // Haptic feedback
        HapticFeedbackManager.shared.selectionChanged()
        
        onControlsChanged?()
    }
    
    @objc private func focusValueChanged(_ sender: UISlider) {
        let point = CGPoint(x: CGFloat(sender.value), y: 0.5)
        advancedControlsManager?.setFocusPoint(point, for: selectedCamera)
        
        onControlsChanged?()
    }
    
    @objc private func resetFocusTapped(_ sender: UIButton) {
        focusSlider.value = 0.5
        focusSegmentedControl.selectedSegmentIndex = 0
        focusSlider.isEnabled = false
        
        advancedControlsManager?.setFocusPoint(CGPoint(x: 0.5, y: 0.5), for: selectedCamera)
        advancedControlsManager?.setFocusMode(.continuousAutoFocus, for: selectedCamera)
        
        // Haptic feedback
        HapticFeedbackManager.shared.lightImpact()
        
        onControlsChanged?()
    }
    
    @objc private func exposureModeChanged(_ sender: UISegmentedControl) {
        let mode: AVCaptureDevice.ExposureMode = sender.selectedSegmentIndex == 0 ? .continuousAutoExposure : .locked
        advancedControlsManager?.setExposureMode(mode, for: selectedCamera)
        
        // Enable/disable exposure slider based on mode
        exposureSlider.isEnabled = (sender.selectedSegmentIndex == 1)
        
        // Haptic feedback
        HapticFeedbackManager.shared.selectionChanged()
        
        onControlsChanged?()
    }
    
    @objc private func exposureValueChanged(_ sender: UISlider) {
        advancedControlsManager?.setExposureTargetBias(sender.value, for: selectedCamera)
        
        onControlsChanged?()
    }
    
    @objc private func resetExposureTapped(_ sender: UIButton) {
        exposureSlider.value = 0.0
        exposureSegmentedControl.selectedSegmentIndex = 0
        exposureSlider.isEnabled = false
        
        advancedControlsManager?.setExposureTargetBias(0.0, for: selectedCamera)
        advancedControlsManager?.setExposureMode(.continuousAutoExposure, for: selectedCamera)
        
        // Haptic feedback
        HapticFeedbackManager.shared.lightImpact()
        
        onControlsChanged?()
    }
    
    @objc private func zoomValueChanged(_ sender: UISlider) {
        advancedControlsManager?.setZoomFactorSmoothly(sender.value, for: selectedCamera)
        
        onControlsChanged?()
    }
    
    @objc private func resetZoomTapped(_ sender: UIButton) {
        zoomSlider.value = 1.0
        advancedControlsManager?.resetZoom(for: selectedCamera)
        
        // Haptic feedback
        HapticFeedbackManager.shared.lightImpact()
        
        onControlsChanged?()
    }
    
    // MARK: - UI Updates
    
    private func updateUIForSelectedCamera() {
        guard let manager = advancedControlsManager else { return }
        
        // Update zoom slider max value
        let maxZoom = selectedCamera == .front ? manager.maxFrontZoomFactor : manager.maxBackZoomFactor
        zoomSlider.maximumValue = maxZoom
        
        // Update current values
        let currentZoom = selectedCamera == .front ? manager.currentFrontZoomFactor : manager.currentBackZoomFactor
        zoomSlider.value = currentZoom
        
        // Update focus slider
        let currentFocusPoint = selectedCamera == .front ? manager.currentFrontFocusPoint : manager.currentBackFocusPoint
        focusSlider.value = Float(currentFocusPoint.x)
        
        // Update exposure slider
        let currentExposureBias = selectedCamera == .front ? manager.currentFrontExposureBias : manager.currentBackExposureBias
        exposureSlider.value = currentExposureBias
    }
    
    // MARK: - Public Methods
    
    func setAdvancedControlsManager(_ manager: AdvancedCameraControlsManager) {
        advancedControlsManager = manager
        updateUIForSelectedCamera()
    }
    
    func setSelectedCamera(_ position: AVCaptureDevice.Position) {
        selectedCamera = position
        cameraSelector.selectedSegmentIndex = position == .front ? 0 : 1
        updateUIForSelectedCamera()
    }
    
    func setEnabled(_ enabled: Bool) {
        focusSegmentedControl.isEnabled = enabled
        exposureSegmentedControl.isEnabled = enabled
        zoomSlider.isEnabled = enabled
        resetFocusButton.isEnabled = enabled
        resetExposureButton.isEnabled = enabled
        resetZoomButton.isEnabled = enabled
        cameraSelector.isEnabled = enabled
        
        // Only enable sliders if manual mode is selected
        focusSlider.isEnabled = enabled && (focusSegmentedControl.selectedSegmentIndex == 1)
        exposureSlider.isEnabled = enabled && (exposureSegmentedControl.selectedSegmentIndex == 1)
        
        alpha = enabled ? 1.0 : 0.6
    }
    
    func focusAtPoint(_ point: CGPoint, for position: AVCaptureDevice.Position) {
        if position == selectedCamera {
            focusSlider.value = Float(point.x)
            advancedControlsManager?.focusAtPoint(point, for: position)
            updateUIForSelectedCamera()
        }
    }
    
    // MARK: - Animation
    
    func animateSelection() {
        UIView.animate(withDuration: 0.2, animations: {
            self.transform = CGAffineTransform(scaleX: 0.98, y: 0.98)
        }) { _ in
            UIView.animate(withDuration: 0.2) {
                self.transform = .identity
            }
        }
    }
}