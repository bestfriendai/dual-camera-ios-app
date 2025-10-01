//
//  VisualCountdownView.swift
//  DualCameraApp
//

import UIKit

class VisualCountdownView: UIView {
    
    private let countdownLabel = UILabel()
    private var countdownTimer: Timer?
    private var remainingTime: Int = 0
    
    var onCountdownComplete: (() -> Void)?
    var onCountdownTick: ((Int) -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        backgroundColor = UIColor.black.withAlphaComponent(0.8)
        layer.cornerRadius = 20
        layer.masksToBounds = true
        
        countdownLabel.font = UIFont.systemFont(ofSize: 60, weight: .bold)
        countdownLabel.textColor = .white
        countdownLabel.textAlignment = .center
        countdownLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(countdownLabel)
        
        NSLayoutConstraint.activate([
            countdownLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            countdownLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        
        isHidden = true
    }
    
    func startCountdown(from seconds: Int) {
        remainingTime = max(0, seconds)
        isHidden = false
        updateLabel()
        onCountdownTick?(remainingTime)
        
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            self.remainingTime -= 1
            if self.remainingTime > 0 {
                self.updateLabel()
                self.onCountdownTick?(self.remainingTime)
            } else {
                self.countdownTimer?.invalidate()
                self.countdownTimer = nil
                self.updateLabelForCompletion()
                self.onCountdownTick?(0)
                self.onCountdownComplete?()
            }
        }
    }
    
    private func updateLabel() {
        countdownLabel.text = "\(remainingTime)"
        animatePulse()
    }
    
    private func updateLabelForCompletion() {
        countdownLabel.text = "GO"
        animatePulse()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            self.isHidden = true
            self.countdownLabel.text = ""
        }
    }
    
    private func animatePulse() {
        UIView.animate(withDuration: 0.3, animations: {
            self.countdownLabel.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
        }) { _ in
            UIView.animate(withDuration: 0.3) {
                self.countdownLabel.transform = .identity
            }
        }
    }
    
    func stopCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        isHidden = true
    }
}
