// AdvancedMaterialSystem.swift - Temporarily simplified for build
import UIKit

class MaterialSystemManager {
    static let shared = MaterialSystemManager()
    private init() {}
    
    static func createProminentContainer() -> EnhancedGlassmorphismView {
        return EnhancedGlassmorphismView(material: .regular)
    }
    
    static func createSubtleContainer() -> EnhancedGlassmorphismView {
        return EnhancedGlassmorphismView(material: .thin)
    }
    
    static func createChromeContainer() -> EnhancedGlassmorphismView {
        return EnhancedGlassmorphismView(material: .regular)
    }
}
