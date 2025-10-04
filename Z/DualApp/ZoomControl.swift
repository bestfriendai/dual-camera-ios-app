// Dual Camera App
import UIKit

class ZoomControl: UIView {
    
    private let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
    private let stackView = UIStackView()
    private var zoomButtons: [ZoomButton] = []
    private let slider = UISlider()
    private let zoomLabel = UILabel()
    
    var onZoomChanged: ((CGFloat) -> Void)?
    var currentZoom: CGFloat = 1.0 {
        didSet {
            updateZoomLabel()
            slider.value = Float(currentZoom)
        }
    }
    var maxZoom: CGFloat = 10.0 {
        didSet {
            slider.maximumValue = Float(maxZoom)
            updateZoomButtons()
        }
    }
    
    private let presetZoomLevels: [CGFloat] = [0.5, 1.0, 2.0, 3.0]
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        blurView.layer.cornerRadius = 22
        blurView.clipsToBounds = true
        blurView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(blurView)
        
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.alignment = .center
        stackView.distribution = .equalSpacing
        stackView.translatesAutoresizingMaskIntoConstraints = false
        blurView.contentView.addSubview(stackView)
        
        updateZoomButtons()
        
        slider.minimumValue = 1.0
        slider.maximumValue = Float(maxZoom)
        slider.value = 1.0
        slider.alpha = 0
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.addTarget(self, action: #selector(sliderChanged), for: .valueChanged)
        slider.addTarget(self, action: #selector(sliderTouchUp), for: [.touchUpInside, .touchUpOutside])
        blurView.contentView.addSubview(slider)
        
        zoomLabel.text = "1×"
        zoomLabel.font = .monospacedSystemFont(ofSize: 13, weight: .semibold)
        zoomLabel.textColor = .white
        zoomLabel.textAlignment = .center
        zoomLabel.alpha = 0
        zoomLabel.translatesAutoresizingMaskIntoConstraints = false
        blurView.contentView.addSubview(zoomLabel)
        
        NSLayoutConstraint.activate([
            blurView.topAnchor.constraint(equalTo: topAnchor),
            blurView.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            stackView.centerYAnchor.constraint(equalTo: blurView.centerYAnchor),
            stackView.leadingAnchor.constraint(equalTo: blurView.leadingAnchor, constant: 12),
            stackView.trailingAnchor.constraint(equalTo: blurView.trailingAnchor, constant: -12),
            
            slider.centerYAnchor.constraint(equalTo: blurView.centerYAnchor),
            slider.leadingAnchor.constraint(equalTo: blurView.leadingAnchor, constant: 16),
            slider.trailingAnchor.constraint(equalTo: blurView.trailingAnchor, constant: -16),
            
            zoomLabel.centerXAnchor.constraint(equalTo: blurView.centerXAnchor),
            zoomLabel.centerYAnchor.constraint(equalTo: blurView.centerYAnchor),
            
            heightAnchor.constraint(equalToConstant: 44)
        ])
        
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress))
        longPress.minimumPressDuration = 0.3
        addGestureRecognizer(longPress)
    }
    
    private func updateZoomButtons() {
        zoomButtons.forEach { $0.removeFromSuperview() }
        zoomButtons.removeAll()
        
        for zoom in presetZoomLevels where zoom <= maxZoom {
            let button = ZoomButton(zoomLevel: zoom)
            button.addTarget(self, action: #selector(zoomButtonTapped(_:)), for: .touchUpInside)
            stackView.addArrangedSubview(button)
            zoomButtons.append(button)
        }
        
        updateSelectedButton()
    }
    
    private func updateSelectedButton() {
        zoomButtons.forEach { $0.isSelected = false }
        
        if let closest = zoomButtons.min(by: { abs($0.zoomLevel - currentZoom) < abs($1.zoomLevel - currentZoom) }) {
            if abs(closest.zoomLevel - currentZoom) < 0.3 {
                closest.isSelected = true
            }
        }
    }
    
    private func updateZoomLabel() {
        if currentZoom >= 10 {
            zoomLabel.text = String(format: "%.0f×", currentZoom)
        } else if currentZoom >= 1 {
            zoomLabel.text = String(format: "%.1f×", currentZoom)
        } else {
            zoomLabel.text = String(format: "%.2f×", currentZoom)
        }
        updateSelectedButton()
    }
    
    @objc private func zoomButtonTapped(_ sender: ZoomButton) {
        currentZoom = sender.zoomLevel
        onZoomChanged?(currentZoom)
        
        UIView.animate(withDuration: 0.2) {
            self.updateSelectedButton()
        }
    }
    
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .began:
            showSlider()
        case .ended, .cancelled:
            hideSlider()
        default:
            break
        }
    }
    
    @objc private func sliderChanged() {
        currentZoom = CGFloat(slider.value)
        onZoomChanged?(currentZoom)
    }
    
    @objc private func sliderTouchUp() {
        hideSlider()
    }
    
    private func showSlider() {
        UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseOut]) {
            self.stackView.alpha = 0
            self.slider.alpha = 1
            self.zoomLabel.alpha = 1
        }
    }
    
    private func hideSlider() {
        UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseOut]) {
            self.stackView.alpha = 1
            self.slider.alpha = 0
            self.zoomLabel.alpha = 0
        }
    }
}

class ZoomButton: UIButton {
    
    let zoomLevel: CGFloat
    
    override var isSelected: Bool {
        didSet {
            updateAppearance()
        }
    }
    
    init(zoomLevel: CGFloat) {
        self.zoomLevel = zoomLevel
        super.init(frame: .zero)
        setupButton()
    }
    
    required init?(coder: NSCoder) {
        self.zoomLevel = 1.0
        super.init(coder: coder)
        setupButton()
    }
    
    private func setupButton() {
        let title = zoomLevel < 1 ? String(format: "%.1f×", zoomLevel) : String(format: "%.0f×", zoomLevel)
        setTitle(title, for: .normal)
        titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(greaterThanOrEqualToConstant: 40),
            heightAnchor.constraint(equalToConstant: 28)
        ])
        
        layer.cornerRadius = 14
        updateAppearance()
    }
    
    private func updateAppearance() {
        if isSelected {
            backgroundColor = UIColor.systemYellow
            setTitleColor(.black, for: .normal)
        } else {
            backgroundColor = .clear
            setTitleColor(.white.withAlphaComponent(0.8), for: .normal)
        }
    }
}
