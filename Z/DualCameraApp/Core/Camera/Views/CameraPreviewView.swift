//
//  CameraPreviewView.swift
//  DualApp
//
//  Created by DualApp Team on 10/3/25.
//

import SwiftUI
import MetalKit
import AVFoundation

// MARK: - Camera Preview View

struct CameraPreviewView: UIViewRepresentable {
    
    // MARK: - Properties
    
    let cameraPosition: CameraPosition
    let dualCameraSession: DualCameraSession
    let renderMode: RenderMode
    let filter: RenderFilter
    
    @Binding var isRecording: Bool
    @Binding var zoomLevel: Float
    
    // MARK: - State
    
    @State private var metalView: MTKView?
    @State private var metalRenderer: MetalRenderer?
    @State private var previewLayer: AVCaptureVideoPreviewLayer?
    
    // MARK: - Initialization
    
    init(
        cameraPosition: CameraPosition,
        dualCameraSession: DualCameraSession,
        renderMode: RenderMode = .single,
        filter: RenderFilter = .none,
        isRecording: Binding<Bool>,
        zoomLevel: Binding<Float>
    ) {
        self.cameraPosition = cameraPosition
        self.dualCameraSession = dualCameraSession
        self.renderMode = renderMode
        self.filter = filter
        self._isRecording = isRecording
        self._zoomLevel = zoomLevel
    }
    
    // MARK: - UIViewRepresentable
    
    func makeUIView(context: Context) -> MTKView {
        let metalView = MTKView()
        metalView.delegate = context.coordinator
        metalView.preferredFramesPerSecond = 60
        metalView.enableSetNeedsDisplay = false
        
        // Create Metal device
        if let device = MTLCreateSystemDefaultDevice() {
            metalView.device = device
            
            // Initialize Metal renderer
            Task { @MainActor in
                let renderer = MetalRenderer(device: device)
                try? await renderer.initialize()
                await renderer.setRenderMode(renderMode)
                await renderer.setFilter(filter)
                
                self.metalRenderer = renderer
                context.coordinator.metalRenderer = renderer
            }
        }
        
        self.metalView = metalView
        return metalView
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) {
        Task { @MainActor in
            await metalRenderer?.setRenderMode(renderMode)
            await metalRenderer?.setFilter(filter)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject, MTKViewDelegate {
        let parent: CameraPreviewView
        var metalRenderer: MetalRenderer?
        var frameStreamTask: Task<Void, Never>?
        
        init(_ parent: CameraPreviewView) {
            self.parent = parent
            super.init()
            
            // Start frame stream processing
            startFrameStreamProcessing()
        }
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            Task { @MainActor in
                await metalRenderer?.setViewportSize(size)
            }
        }
        
        func draw(in view: MTKView) {
            // Drawing is handled by the Metal renderer
        }
        
        private func startFrameStreamProcessing() {
            frameStreamTask = Task {
                for await frame in await parent.dualCameraSession.frameStream {
                    if frame.position == parent.cameraPosition {
                        await processFrame(frame, in: view)
                    }
                }
            }
        }
        
        private func processFrame(_ frame: DualCameraFrame, in view: MTKView) async {
            guard let renderer = metalRenderer else { return }
            
            do {
                try await renderer.renderFrame(frame, to: view)
            } catch {
                print("Error rendering frame: \(error)")
            }
        }
        
        deinit {
            frameStreamTask?.cancel()
        }
    }
}

// MARK: - Dual Camera Preview View

struct DualCameraPreviewView: View {
    
    // MARK: - Properties
    
    let dualCameraSession: DualCameraSession
    @Binding var renderMode: RenderMode
    @Binding var filter: RenderFilter
    @Binding var isRecording: Bool
    @Binding var frontZoomLevel: Float
    @Binding var backZoomLevel: Float
    
    // MARK: - State
    
    @State private var selectedCamera: CameraPosition = .back
    @State private var showComposite: Bool = true
    @State private var performanceMetrics: RenderPerformanceMetrics?
    
    // MARK: - Body
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if showComposite {
                    // Composite view showing both cameras
                    compositePreviewView(size: geometry.size)
                } else {
                    // Single camera view
                    singleCameraPreviewView(size: geometry.size)
                }
                
                // Recording indicator
                if isRecording {
                    recordingIndicator
                }
                
                // Performance metrics overlay (in debug mode)
                #if DEBUG
                if let metrics = performanceMetrics {
                    performanceMetricsOverlay(metrics)
                }
                #endif
            }
        }
        .onAppear {
            setupPerformanceMonitoring()
        }
        .onChange(of: renderMode) { _ in
            updateRenderMode()
        }
        .onChange(of: filter) { _ in
            updateFilter()
        }
    }
    
    // MARK: - Composite Preview View
    
    private func compositePreviewView(size: CGSize) -> some View {
        HStack(spacing: 0) {
            // Front camera preview
            CameraPreviewView(
                cameraPosition: .front,
                dualCameraSession: dualCameraSession,
                renderMode: .single,
                filter: filter,
                isRecording: $isRecording,
                zoomLevel: $frontZoomLevel
            )
            .frame(width: size.width / 2)
            .clipped()
            
            // Back camera preview
            CameraPreviewView(
                cameraPosition: .back,
                dualCameraSession: dualCameraSession,
                renderMode: .single,
                filter: filter,
                isRecording: $isRecording,
                zoomLevel: $backZoomLevel
            )
            .frame(width: size.width / 2)
            .clipped()
        }
    }
    
    // MARK: - Single Camera Preview View
    
    private func singleCameraPreviewView(size: CGSize) -> some View {
        CameraPreviewView(
            cameraPosition: selectedCamera,
            dualCameraSession: dualCameraSession,
            renderMode: renderMode,
            filter: filter,
            isRecording: $isRecording,
            zoomLevel: selectedCamera == .front ? $frontZoomLevel : $backZoomLevel
        )
        .frame(width: size.width, height: size.height)
    }
    
    // MARK: - Recording Indicator
    
    private var recordingIndicator: some View {
        VStack {
            HStack {
                Spacer()
                
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 12, height: 12)
                        .scaleEffect(isRecording ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.5).repeatForever(), value: isRecording)
                    
                    Text("REC")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.6))
                .cornerRadius(16)
                .padding(.trailing, 16)
                .padding(.top, 16)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Performance Metrics Overlay
    
    #if DEBUG
    private func performanceMetricsOverlay(_ metrics: RenderPerformanceMetrics) -> some View {
        VStack {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("FPS: \(metrics.formattedFPS)")
                    Text("Frame Time: \(metrics.formattedAverageFrameTime)")
                    Text("Frames: \(metrics.frameCount)")
                    Text("Mode: \(metrics.renderMode.description)")
                    Text("Filter: \(metrics.filter.description)")
                }
                .font(.system(size: 10, family: .monospaced))
                .foregroundColor(.white)
                .padding(8)
                .background(Color.black.opacity(0.6))
                .cornerRadius(8)
                
                Spacer()
            }
            .padding(.leading, 16)
            .padding(.top, 16)
            
            Spacer()
        }
    }
    #endif
    
    // MARK: - Helper Methods
    
    private func setupPerformanceMonitoring() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                if let renderer = getMetalRenderer() {
                    performanceMetrics = await renderer.getPerformanceMetrics()
                }
            }
        }
    }
    
    private func getMetalRenderer() -> MetalRenderer? {
        // This would get the metal renderer from the preview view
        // Implementation depends on the specific architecture
        return nil
    }
    
    private func updateRenderMode() {
        // Update render mode in metal renderer
    }
    
    private func updateFilter() {
        // Update filter in metal renderer
    }
}

// MARK: - Camera Controls Overlay

struct CameraControlsOverlay: View {
    
    // MARK: - Properties
    
    let dualCameraSession: DualCameraSession
    @Binding var renderMode: RenderMode
    @Binding var filter: RenderFilter
    @Binding var isRecording: Bool
    @Binding var showComposite: Bool
    @Binding var selectedCamera: CameraPosition
    @Binding var frontZoomLevel: Float
    @Binding var backZoomLevel: Float
    
    // MARK: - Body
    
    var body: some View {
        VStack {
            // Top controls
            HStack {
                // Camera switcher
                cameraSwitcher
                
                Spacer()
                
                // Render mode selector
                renderModeSelector
                
                Spacer()
                
                // Filter selector
                filterSelector
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
            Spacer()
            
            // Bottom controls
            HStack {
                // Zoom controls
                zoomControls
                
                Spacer()
                
                // Recording button
                recordingButton
                
                Spacer()
                
                // Composite toggle
                compositeToggle
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }
    
    // MARK: - Camera Switcher
    
    private var cameraSwitcher: some View {
        HStack(spacing: 12) {
            ForEach([CameraPosition.front, .back], id: \.self) { position in
                Button(action: {
                    selectedCamera = position
                }) {
                    Image(systemName: position.icon)
                        .font(.title2)
                        .foregroundColor(selectedCamera == position ? .white : .white.opacity(0.6))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(8)
        .background(Color.black.opacity(0.4))
        .cornerRadius(20)
    }
    
    // MARK: - Render Mode Selector
    
    private var renderModeSelector: some View {
        Menu {
            ForEach(RenderMode.allCases, id: \.self) { mode in
                Button(mode.description) {
                    renderMode = mode
                }
            }
        } label: {
            HStack {
                Image(systemName: "rectangle.split.3x1")
                Text(renderMode.description)
                    .font(.caption)
            }
            .foregroundColor(.white)
            .padding(8)
            .background(Color.black.opacity(0.4))
            .cornerRadius(16)
        }
    }
    
    // MARK: - Filter Selector
    
    private var filterSelector: some View {
        Menu {
            ForEach(RenderFilter.allCases, id: \.self) { filter in
                Button(filter.description) {
                    self.filter = filter
                }
            }
        } label: {
            Image(systemName: "camera.filters")
                .font(.title2)
                .foregroundColor(.white)
                .padding(8)
                .background(Color.black.opacity(0.4))
                .cornerRadius(20)
        }
    }
    
    // MARK: - Zoom Controls
    
    private var zoomControls: some View {
        VStack(spacing: 8) {
            Button(action: {
                let currentZoom = selectedCamera == .front ? frontZoomLevel : backZoomLevel
                let newZoom = min(currentZoom + 0.5, 10.0)
                
                if selectedCamera == .front {
                    frontZoomLevel = newZoom
                } else {
                    backZoomLevel = newZoom
                }
                
                Task {
                    try? await dualCameraSession.updateZoomLevel(newZoom)
                }
            }) {
                Image(systemName: "plus.magnifyingglass")
                    .font(.title3)
                    .foregroundColor(.white)
            }
            .buttonStyle(PlainButtonStyle())
            
            Text(String(format: "%.1fx", selectedCamera == .front ? frontZoomLevel : backZoomLevel))
                .font(.caption)
                .foregroundColor(.white)
                .frame(minWidth: 40)
            
            Button(action: {
                let currentZoom = selectedCamera == .front ? frontZoomLevel : backZoomLevel
                let newZoom = max(currentZoom - 0.5, 1.0)
                
                if selectedCamera == .front {
                    frontZoomLevel = newZoom
                } else {
                    backZoomLevel = newZoom
                }
                
                Task {
                    try? await dualCameraSession.updateZoomLevel(newZoom)
                }
            }) {
                Image(systemName: "minus.magnifyingglass")
                    .font(.title3)
                    .foregroundColor(.white)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(12)
        .background(Color.black.opacity(0.4))
        .cornerRadius(20)
    }
    
    // MARK: - Recording Button
    
    private var recordingButton: some View {
        Button(action: {
            Task {
                if isRecording {
                    try? await dualCameraSession.stopRecording()
                } else {
                    try? await dualCameraSession.startRecording()
                }
            }
        }) {
            ZStack {
                Circle()
                    .fill(isRecording ? Color.red : Color.white)
                    .frame(width: 70, height: 70)
                    .scaleEffect(isRecording ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: isRecording)
                
                if !isRecording {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 60, height: 60)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Composite Toggle
    
    private var compositeToggle: some View {
        Button(action: {
            showComposite.toggle()
        }) {
            HStack {
                Image(systemName: showComposite ? "rectangle.split.2x1" : "rectangle")
                Text(showComposite ? "Both" : "Single")
                    .font(.caption)
            }
            .foregroundColor(.white)
            .padding(8)
            .background(Color.black.opacity(0.4))
            .cornerRadius(16)
        }
    }
}

// MARK: - Preview View Modifier

extension View {
    func cameraPreviewOverlay(
        dualCameraSession: DualCameraSession,
        renderMode: Binding<RenderMode>,
        filter: Binding<RenderFilter>,
        isRecording: Binding<Bool>,
        showComposite: Binding<Bool>,
        selectedCamera: Binding<CameraPosition>,
        frontZoomLevel: Binding<Float>,
        backZoomLevel: Binding<Float>
    ) -> some View {
        self.overlay(
            CameraControlsOverlay(
                dualCameraSession: dualCameraSession,
                renderMode: renderMode,
                filter: filter,
                isRecording: isRecording,
                showComposite: showComposite,
                selectedCamera: selectedCamera,
                frontZoomLevel: frontZoomLevel,
                backZoomLevel: backZoomLevel
            )
        )
    }
}