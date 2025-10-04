import UIKit
import Metal

enum MaterialStyle {
    case prominent
    case subtle
    case chrome
    case liquid
    case frosted
    
    var blurRadius: CGFloat {
        switch self {
        case .prominent: return 40
        case .subtle: return 20
        case .chrome: return 30
        case .liquid: return 50
        case .frosted: return 25
        }
    }
    
    var fresnelStrength: Float {
        switch self {
        case .prominent: return 1.2
        case .subtle: return 0.6
        case .chrome: return 1.5
        case .liquid: return 1.0
        case .frosted: return 0.8
        }
    }
    
    var tintIntensity: CGFloat {
        switch self {
        case .prominent: return 0.4
        case .subtle: return 0.2
        case .chrome: return 0.5
        case .liquid: return 0.3
        case .frosted: return 0.25
        }
    }
}

class MaterialSystemManager {
    static let shared = MaterialSystemManager()
    
    private var metalDevice: MTLDevice?
    private var isMetalAvailable: Bool = false
    
    private init() {
        metalDevice = MTLCreateSystemDefaultDevice()
        isMetalAvailable = metalDevice != nil
    }
    
    static func createProminentContainer() -> LiquidGlassView {
        let view = LiquidGlassView(frame: .zero)
        shared.applyMaterialStyle(.prominent, to: view)
        return view
    }
    
    static func createSubtleContainer() -> LiquidGlassView {
        let view = LiquidGlassView(frame: .zero)
        shared.applyMaterialStyle(.subtle, to: view)
        return view
    }
    
    static func createChromeContainer() -> LiquidGlassView {
        let view = LiquidGlassView(frame: .zero)
        shared.applyMaterialStyle(.chrome, to: view)
        return view
    }
    
    static func createLiquidContainer(tint: UIColor = .white, cornerRadius: CGFloat = 24) -> LiquidGlassView {
        let view = LiquidGlassView(frame: .zero)
        view.tintColor = tint
        view.layer.cornerRadius = cornerRadius
        shared.applyMaterialStyle(.liquid, to: view)
        return view
    }
    
    static func createFrostedContainer() -> LiquidGlassView {
        let view = LiquidGlassView(frame: .zero)
        shared.applyMaterialStyle(.frosted, to: view)
        return view
    }
    
    static func createCustomContainer(tint: UIColor = .white, cornerRadius: CGFloat = 24, blurRadius: CGFloat = 30, fresnelStrength: Float = 1.0) -> LiquidGlassView {
        let view = LiquidGlassView(frame: .zero)
        view.tintColor = tint
        view.layer.cornerRadius = cornerRadius
        return view
    }
    
    private func applyMaterialStyle(_ style: MaterialStyle, to view: LiquidGlassView) {
        view.tintColor = view.tintColor.withAlphaComponent(style.tintIntensity)
    }
}
