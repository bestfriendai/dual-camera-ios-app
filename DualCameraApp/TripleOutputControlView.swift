//
//  TripleOutputControlView.swift
//  DualCameraApp
//
//  UI component for controlling triple output recording modes
//

import UIKit

class TripleOutputControlView: UIView {
    
    // MARK: - Properties
    
    private let containerView = UIView()
    private let titleLabel = UILabel()
    private let modeSegmentedControl = UISegmentedControl(items: ["All Files", "Combined", "Front & Back"])
    private let descriptionLabel = UILabel()
    private let infoButton = UIButton(type: .infoLight)
    
    var onModeChanged: ((DualCameraManager.TripleOutputMode) -> Void)?
    
    private var currentMode: DualCameraManager.TripleOutputMode = .allFiles {
        didSet {
            updateUI()
        }
    }
    
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
        setupSegmentedControl()
        setupDescriptionLabel()
        setupInfoButton()
        setupConstraints()
        
        updateUI()
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
        titleLabel.text = "Recording Mode"
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(titleLabel)
    }
    
    private func setupSegmentedControl() {
        modeSegmentedControl.selectedSegmentIndex = 0
        modeSegmentedControl.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        modeSegmentedControl.selectedSegmentTintColor = UIColor.systemBlue.withAlphaComponent(0.7)
        modeSegmentedControl.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .normal)
        modeSegmentedControl.setTitleTextAttributes([.foregroundColor: UIColor.black], for: .selected)
        modeSegmentedControl.layer.cornerRadius = 8
        modeSegmentedControl.translatesAutoresizingMaskIntoConstraints = false
        
        modeSegmentedControl.addTarget(self, action: #selector(modeChanged(_:)), for: .valueChanged)
        
        containerView.addSubview(modeSegmentedControl)
    }
    
    private func setupDescriptionLabel() {
        descriptionLabel.text = "Save front, back, and combined videos as separate files"
        descriptionLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        descriptionLabel.textColor = UIColor.white.withAlphaComponent(0.8)
        descriptionLabel.numberOfLines = 0
        descriptionLabel.textAlignment = .center
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(descriptionLabel)
    }
    
    private func setupInfoButton() {
        infoButton.tintColor = UIColor.white.withAlphaComponent(0.6)
        infoButton.translatesAutoresizingMaskIntoConstraints = false
        
        infoButton.addTarget(self, action: #selector(infoButtonTapped(_:)), for: .touchUpInside)
        
        containerView.addSubview(infoButton)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: infoButton.leadingAnchor, constant: -8),
            
            infoButton.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            infoButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            infoButton.widthAnchor.constraint(equalToConstant: 24),
            infoButton.heightAnchor.constraint(equalToConstant: 24),
            
            modeSegmentedControl.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            modeSegmentedControl.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            modeSegmentedControl.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            modeSegmentedControl.heightAnchor.constraint(equalToConstant: 32),
            
            descriptionLabel.topAnchor.constraint(equalTo: modeSegmentedControl.bottomAnchor, constant: 12),
            descriptionLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            descriptionLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            descriptionLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16)
        ])
    }
    
    // MARK: - Actions
    
    @objc private func modeChanged(_ sender: UISegmentedControl) {
        let mode: DualCameraManager.TripleOutputMode
        
        switch sender.selectedSegmentIndex {
        case 0:
            mode = .allFiles
        case 1:
            mode = .combinedOnly
        case 2:
            mode = .frontBackOnly
        default:
            mode = .allFiles
        }
        
        currentMode = mode
        onModeChanged?(mode)
        
        // Haptic feedback
        HapticFeedbackManager.shared.selectionChanged()
    }
    
    @objc private func infoButtonTapped(_ sender: UIButton) {
        showInfoAlert()
        
        // Haptic feedback
        HapticFeedbackManager.shared.lightImpact()
    }
    
    // MARK: - UI Updates
    
    private func updateUI() {
        switch currentMode {
        case .allFiles:
            descriptionLabel.text = "Save front, back, and combined videos as separate files"
            modeSegmentedControl.selectedSegmentIndex = 0
            
        case .combinedOnly:
            descriptionLabel.text = "Save only the combined video with both cameras side by side"
            modeSegmentedControl.selectedSegmentIndex = 1
            
        case .frontBackOnly:
            descriptionLabel.text = "Save front and back camera videos separately, no combined file"
            modeSegmentedControl.selectedSegmentIndex = 2
        }
    }
    
    // MARK: - Public Methods
    
    func setMode(_ mode: DualCameraManager.TripleOutputMode) {
        currentMode = mode
    }
    
    func getMode() -> DualCameraManager.TripleOutputMode {
        return currentMode
    }
    
    func setEnabled(_ enabled: Bool) {
        modeSegmentedControl.isEnabled = enabled
        alpha = enabled ? 1.0 : 0.6
    }
    
    // MARK: - Info Alert
    
    private func showInfoAlert() {
        let alert = UIAlertController(
            title: "Recording Modes",
            message: """
            **All Files**: Saves three separate videos - front camera, back camera, and a combined video with both cameras side by side.
            
            **Combined Only**: Saves only the combined video with both cameras side by side. Uses less storage space.
            
            **Front & Back**: Saves front and back camera videos separately, without creating a combined file.
            """,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Got it", style: .default))
        
        // Find the nearest view controller and present the alert
        if let viewController = findViewController() {
            viewController.present(alert, animated: true)
        }
    }
    
    // Helper to find the view controller
    private func findViewController() -> UIViewController? {
        var responder: UIResponder? = self
        while responder != nil {
            responder = responder?.next
            if let viewController = responder as? UIViewController {
                return viewController
            }
        }
        return nil
    }
    
    // MARK: - Animation
    
    func animateSelection() {
        UIView.animate(withDuration: 0.2, animations: {
            self.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }) { _ in
            UIView.animate(withDuration: 0.2) {
                self.transform = .identity
            }
        }
    }
    
    // MARK: - Accessibility
    
    override var isAccessibilityElement: Bool {
        get { return true }
        set { }
    }
    
    override var accessibilityLabel: String? {
        get { return "Recording mode control" }
        set { }
    }
    
    override var accessibilityValue: String? {
        get {
            switch currentMode {
            case .allFiles:
                return "All files"
            case .combinedOnly:
                return "Combined only"
            case .frontBackOnly:
                return "Front and back"
            }
        }
        set { }
    }
    
    override var accessibilityTraits: UIAccessibilityTraits {
        get { return .adjustable }
        set { }
    }
    
    override func accessibilityIncrement() {
        let currentIndex = modeSegmentedControl.selectedSegmentIndex
        let nextIndex = (currentIndex + 1) % modeSegmentedControl.numberOfSegments
        modeSegmentedControl.selectedSegmentIndex = nextIndex
        modeChanged(modeSegmentedControl)
    }
    
    override func accessibilityDecrement() {
        let currentIndex = modeSegmentedControl.selectedSegmentIndex
        let previousIndex = currentIndex > 0 ? currentIndex - 1 : modeSegmentedControl.numberOfSegments - 1
        modeSegmentedControl.selectedSegmentIndex = previousIndex
        modeChanged(modeSegmentedControl)
    }
}