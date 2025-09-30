import CoreImage
import Metal
import AVFoundation
import UIKit

enum RecordingLayout {
    case sideBySide
    case pictureInPicture(position: PIPPosition, size: PIPSize)
    case frontPrimary
    case backPrimary
    
    enum PIPPosition {
        case topLeft, topRight, bottomLeft, bottomRight
    }
    
    enum PIPSize: CGFloat {
        case small = 0.25
        case medium = 0.33
        case large = 0.40
    }
}

class FrameCompositor {
    private let ciContext: CIContext
    private let metalDevice: MTLDevice
    private var renderSize: CGSize
    private var layout: RecordingLayout
    
    init(layout: RecordingLayout, quality: VideoQuality) {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal not supported on this device")
        }
        
        self.metalDevice = device
        self.ciContext = CIContext(mtlDevice: device, options: [
            .workingColorSpace: CGColorSpaceCreateDeviceRGB(),
            .outputColorSpace: CGColorSpaceCreateDeviceRGB()
        ])
        self.renderSize = quality.renderSize
        self.layout = layout
    }
    
    func updateLayout(_ newLayout: RecordingLayout) {
        self.layout = newLayout
    }
    
    func composite(frontBuffer: CVPixelBuffer, 
                   backBuffer: CVPixelBuffer,
                   timestamp: CMTime) -> CVPixelBuffer? {
        
        let frontImage = CIImage(cvPixelBuffer: frontBuffer)
        let backImage = CIImage(cvPixelBuffer: backBuffer)
        
        let composedImage: CIImage
        switch layout {
        case .sideBySide:
            composedImage = composeSideBySide(front: frontImage, back: backImage)
        case .pictureInPicture(let position, let size):
            composedImage = composePIP(front: frontImage, back: backImage, 
                                      position: position, size: size)
        case .frontPrimary:
            composedImage = composePrimary(primary: frontImage, secondary: backImage)
        case .backPrimary:
            composedImage = composePrimary(primary: backImage, secondary: frontImage)
        }
        
        return renderToPixelBuffer(composedImage)
    }
    
    private func composeSideBySide(front: CIImage, back: CIImage) -> CIImage {
        let halfWidth = renderSize.width / 2
        
        // Scale and position front camera (left side)
        let frontScaled = front
            .transformed(by: CGAffineTransform(scaleX: halfWidth / front.extent.width,
                                               y: renderSize.height / front.extent.height))
        
        // Scale and position back camera (right side)
        let backScaled = back
            .transformed(by: CGAffineTransform(scaleX: halfWidth / back.extent.width,
                                              y: renderSize.height / back.extent.height))
            .transformed(by: CGAffineTransform(translationX: halfWidth, y: 0))
        
        // Create background
        let background = CIImage(color: CIColor.black)
            .cropped(to: CGRect(origin: .zero, size: renderSize))
        
        // Composite both images
        return backScaled.composited(over: frontScaled).composited(over: background)
    }
    
    private func composePIP(front: CIImage, back: CIImage, 
                           position: RecordingLayout.PIPPosition,
                           size: RecordingLayout.PIPSize) -> CIImage {
        
        // Back camera as main background
        let mainScaled = back
            .transformed(by: CGAffineTransform(scaleX: renderSize.width / back.extent.width,
                                               y: renderSize.height / back.extent.height))
        
        // Calculate PIP dimensions
        let pipScale = size.rawValue
        let pipWidth = renderSize.width * pipScale
        let pipHeight = renderSize.height * pipScale
        
        // Scale front camera for PIP
        let pipScaled = front
            .transformed(by: CGAffineTransform(scaleX: pipWidth / front.extent.width,
                                               y: pipHeight / front.extent.height))
        
        // Position PIP based on corner
        let margin: CGFloat = 20
        let pipPosition: CGPoint
        switch position {
        case .topLeft:
            pipPosition = CGPoint(x: margin, y: renderSize.height - pipHeight - margin)
        case .topRight:
            pipPosition = CGPoint(x: renderSize.width - pipWidth - margin, 
                                 y: renderSize.height - pipHeight - margin)
        case .bottomLeft:
            pipPosition = CGPoint(x: margin, y: margin)
        case .bottomRight:
            pipPosition = CGPoint(x: renderSize.width - pipWidth - margin, y: margin)
        }
        
        let pipPositioned = pipScaled
            .transformed(by: CGAffineTransform(translationX: pipPosition.x, y: pipPosition.y))
        
        // Add border to PIP
        let pipWithBorder = addBorder(to: pipPositioned, 
                                     rect: CGRect(origin: pipPosition, 
                                                 size: CGSize(width: pipWidth, height: pipHeight)),
                                     width: 3, 
                                     color: .white)
        
        // Create background
        let background = CIImage(color: CIColor.black)
            .cropped(to: CGRect(origin: .zero, size: renderSize))
        
        // Composite PIP over main
        return pipWithBorder.composited(over: mainScaled).composited(over: background)
    }
    
    private func composePrimary(primary: CIImage, secondary: CIImage) -> CIImage {
        // Primary takes 75% of width, secondary takes 25%
        let primaryWidth = renderSize.width * 0.75
        let secondaryWidth = renderSize.width * 0.25
        
        // Scale primary (left side)
        let primaryScaled = primary
            .transformed(by: CGAffineTransform(scaleX: primaryWidth / primary.extent.width,
                                               y: renderSize.height / primary.extent.height))
        
        // Scale secondary (right side)
        let secondaryScaled = secondary
            .transformed(by: CGAffineTransform(scaleX: secondaryWidth / secondary.extent.width,
                                              y: renderSize.height / secondary.extent.height))
            .transformed(by: CGAffineTransform(translationX: primaryWidth, y: 0))
        
        // Create background
        let background = CIImage(color: CIColor.black)
            .cropped(to: CGRect(origin: .zero, size: renderSize))
        
        return secondaryScaled.composited(over: primaryScaled).composited(over: background)
    }
    
    private func addBorder(to image: CIImage, rect: CGRect, width: CGFloat, color: UIColor) -> CIImage {
        // Create a simple border by overlaying the image on a slightly larger colored rectangle
        let borderRect = rect.insetBy(dx: -width, dy: -width)
        let borderColor = CIColor(color: color)
        
        let borderImage = CIImage(color: borderColor)
            .cropped(to: borderRect)
        
        return image.composited(over: borderImage)
    }
    
    private func renderToPixelBuffer(_ image: CIImage) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue as Any,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue as Any,
            kCVPixelBufferMetalCompatibilityKey: kCFBooleanTrue as Any,
            kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary
        ] as CFDictionary
        
        let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                        Int(renderSize.width),
                                        Int(renderSize.height),
                                        kCVPixelFormatType_32BGRA,
                                        attrs,
                                        &pixelBuffer)
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            print("Failed to create pixel buffer: \(status)")
            return nil
        }
        
        ciContext.render(image, to: buffer, bounds: CGRect(origin: .zero, size: renderSize), colorSpace: CGColorSpaceCreateDeviceRGB())
        return buffer
    }
}

