import UIKit
import AVFoundation

class FocusExposureControl: UIView {
    
    private let focusSquare = UIView()
    private let exposureSlider = UISlider()
    private var displayLink: CADisplayLink?
    
    var onFocusPoint: ((CGPoint) -> Void)?
    var onExposureAdjust: ((Float) -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        isUserInteractionEnabled = false
        
        focusSquare.frame = CGRect(x: 0, y: 0, width: 80, height: 80)
        focusSquare.layer.borderWidth = 2
        focusSquare.layer.borderColor = UIColor.systemYellow.cgColor
        focusSquare.alpha = 0
        addSubview(focusSquare)
        
        exposureSlider.frame = CGRect(x: 0, y: 0, width: 30, height: 150)
        exposureSlider.transform = CGAffineTransform(rotationAngle: -CGFloat.pi / 2)
        exposureSlider.minimumValue = -2.0
        exposureSlider.maximumValue = 2.0
        exposureSlider.value = 0.0
        exposureSlider.minimumTrackTintColor = .systemYellow
        exposureSlider.maximumTrackTintColor = .white.withAlphaComponent(0.3)
        exposureSlider.alpha = 0
        exposureSlider.addTarget(self, action: #selector(exposureChanged), for: .valueChanged)
        addSubview(exposureSlider)
    }
    
    func showFocusIndicator(at point: CGPoint, showExposure: Bool = true) {
        focusSquare.center = point
        focusSquare.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
        focusSquare.alpha = 1.0
        
        if showExposure {
            exposureSlider.center = CGPoint(x: point.x + 100, y: point.y)
            exposureSlider.alpha = 1.0
        }
        
        UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseOut]) {
            self.focusSquare.transform = .identity
        }
        
        UIView.animate(withDuration: 0.5, delay: 1.5) {
            self.focusSquare.alpha = 0
            self.exposureSlider.alpha = 0
        }
    }
    
    @objc private func exposureChanged() {
        onExposureAdjust?(exposureSlider.value)
    }
}

class TapToFocusGestureHandler {
    
    weak var previewView: UIView?
    var device: AVCaptureDevice?
    var focusControl: FocusExposureControl?
    
    init(previewView: UIView, device: AVCaptureDevice?, focusControl: FocusExposureControl) {
        self.previewView = previewView
        self.device = device
        self.focusControl = focusControl
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        previewView.addGestureRecognizer(tapGesture)
    }
    
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard let device = device, let previewView = previewView else { return }
        
        let point = gesture.location(in: previewView)
        let devicePoint = CGPoint(
            x: point.y / previewView.bounds.height,
            y: 1.0 - point.x / previewView.bounds.width
        )
        
        focusControl?.showFocusIndicator(at: point, showExposure: true)
        
        do {
            try device.lockForConfiguration()
            
            if device.isFocusPointOfInterestSupported && device.isFocusModeSupported(.autoFocus) {
                device.focusPointOfInterest = devicePoint
                device.focusMode = .autoFocus
            }
            
            if device.isExposurePointOfInterestSupported && device.isExposureModeSupported(.autoExpose) {
                device.exposurePointOfInterest = devicePoint
                device.exposureMode = .autoExpose
            }
            
            device.unlockForConfiguration()
        } catch {
            print("Error setting focus: \(error)")
        }
    }
}
