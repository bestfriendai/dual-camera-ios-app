// Dual Camera App - Frame Synchronization Coordinator
import AVFoundation
import Foundation

@available(iOS 15.0, *)
actor FrameSyncCoordinator {
    private var frontFrameBuffer: CMSampleBuffer?
    private var backFrameBuffer: CMSampleBuffer?
    
    enum CameraSource {
        case front
        case back
    }
    
    func processFrame(from source: CameraSource, buffer: CMSampleBuffer) async -> (front: CMSampleBuffer, back: CMSampleBuffer)? {
        switch source {
        case .front:
            frontFrameBuffer = buffer
        case .back:
            backFrameBuffer = buffer
        }
        
        guard let front = frontFrameBuffer, let back = backFrameBuffer else {
            return nil
        }
        
        // Clear buffers after pairing
        let pair = (front, back)
        frontFrameBuffer = nil
        backFrameBuffer = nil
        
        return pair
    }
    
    func reset() async {
        frontFrameBuffer = nil
        backFrameBuffer = nil
    }
}
