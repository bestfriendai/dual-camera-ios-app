//
//  ModernHapticFeedback.swift
//  DualCameraApp
//
//  iOS 26 SwiftUI sensoryFeedback implementation with automatic Reduce Motion handling
//

import SwiftUI

@available(iOS 17.0, *)
extension View {
    func recordingStartFeedback(trigger value: some Equatable) -> some View {
        self.sensoryFeedback(.impact(weight: .medium, intensity: 0.7), trigger: value)
    }
    
    func recordingStopFeedback(trigger value: some Equatable) -> some View {
        self.sensoryFeedback(.impact(weight: .heavy, intensity: 0.9), trigger: value)
    }
    
    func photoCaptureFeedback(trigger value: some Equatable) -> some View {
        self.sensoryFeedback(.impact(weight: .medium, intensity: 0.8), trigger: value)
    }
    
    func successFeedback(trigger value: some Equatable) -> some View {
        self.sensoryFeedback(.success, trigger: value)
    }
    
    func errorFeedback(trigger value: some Equatable) -> some View {
        self.sensoryFeedback(.error, trigger: value)
    }
    
    func selectionFeedback(trigger value: some Equatable) -> some View {
        self.sensoryFeedback(.selection, trigger: value)
    }
    
    func lightImpactFeedback(trigger value: some Equatable) -> some View {
        self.sensoryFeedback(.impact(weight: .light, intensity: 0.5), trigger: value)
    }
}
