// Dual Camera App
import SwiftUI
import AVFoundation

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

@MainActor
struct ContentView: View {
    @State private var cameraManager = CameraManagerWrapper()
    @State private var isRecording = false
    @State private var recordingTime = 0
    @State private var timer: Timer?
    @State private var isFrontPrimary = true
    @State private var videoQuality: VideoQuality = .hd1080
    @State private var isPhotoMode = false
    @State private var showQualityPicker = false
    @State private var showGallery = false
    @State private var showMergeOptions = false
    @State private var mergeProgress: Float = 0.0
    @State private var isMerging = false
    @State private var permissionsGranted = false
    @State private var showPermissionAlert = false
    @State private var showFlashPulse = false
    
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black,
                    Color(hex: "0A0A0F"),
                    Color(hex: "0F0F1A")
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                topControlsBar
                    .padding(.top, 8)
                    .padding(.horizontal, 20)

                Spacer()
                    .frame(height: 20)

                cameraPreviews
                    .padding(.horizontal, 16)

                Spacer()

                bottomControls
                    .padding(.bottom, 40)
            }
        }
        .onAppear {
            requestPermissions()
        }
        .alert(isPresented: $showPermissionAlert) {
            Alert(
                title: Text("Permissions Required"),
                message: Text("Camera, microphone, and photo library access are required."),
                primaryButton: .default(Text("Settings"), action: openSettings),
                secondaryButton: .cancel()
            )
        }
        .onDisappear {
            cameraManager.stop()
        }
    }

    private var topControlsBar: some View {
        HStack(spacing: 16) {
            LiquidGlassControlButton(
                icon: "video.fill",
                text: videoQuality.rawValue,
                action: { showQualityPicker = true }
            )
            .actionSheet(isPresented: $showQualityPicker) {
                ActionSheet(title: Text("Video Quality"), buttons: VideoQuality.allCases.map { quality in
                    .default(Text(quality.rawValue)) {
                        self.videoQuality = quality
                        cameraManager.setVideoQuality(quality)
                    }
                } + [.cancel()])
            }

            Spacer()

            if isRecording {
                RecordingTimerView(recordingTime: recordingTime)
            }

            Spacer()

            LiquidGlassControlButton(
                icon: "photo.stack.fill",
                action: { showGallery = true }
            )
            .sheet(isPresented: $showGallery) {
                GalleryView()
            }
        }
    }

    private var cameraPreviews: some View {
        HStack(spacing: 12) {
            CameraPreviewCard(
                title: "Front",
                previewLayer: cameraManager.frontPreviewLayer,
                isFlashOn: cameraManager.isFlashOn,
                showFlashPulse: $showFlashPulse,
                onFlashToggle: {
                    cameraManager.toggleFlash()
                    withAnimation(reduceMotion ? .none : .spring(response: 0.3)) {
                        showFlashPulse.toggle()
                    }
                },
                onZoom: { scale in
                    cameraManager.setZoom(for: .front, scale: scale)
                }
            )

            CameraPreviewCard(
                title: "Back",
                previewLayer: cameraManager.backPreviewLayer,
                isFlashOn: false,
                showFlashPulse: .constant(false),
                onSwap: {
                    withAnimation(reduceMotion ? .none : .spring(response: 0.4, dampingFraction: 0.7)) {
                        isFrontPrimary.toggle()
                    }
                },
                onZoom: { scale in
                    cameraManager.setZoom(for: .back, scale: scale)
                }
            )
        }
    }

    private var bottomControls: some View {
        VStack(spacing: 24) {
            HStack(spacing: 40) {
                LiquidGlassCircularButton(
                    icon: cameraManager.isFlashOn ? "bolt.fill" : "bolt.slash.fill",
                    size: 56,
                    isActive: cameraManager.isFlashOn,
                    action: {
                        cameraManager.toggleFlash()
                        withAnimation(reduceMotion ? .none : .spring(response: 0.3)) {
                            showFlashPulse.toggle()
                        }
                    }
                )

                MainRecordButton(
                    isRecording: isRecording,
                    isPhotoMode: isPhotoMode,
                    action: {
                        if isPhotoMode {
                            cameraManager.capturePhoto()
                            withAnimation(reduceMotion ? .none : .spring(response: 0.2, dampingFraction: 0.5)) {
                                showFlashPulse.toggle()
                            }
                        } else {
                            if isRecording {
                                stopRecording()
                            } else {
                                startRecording()
                            }
                        }
                    }
                )

                LiquidGlassCircularButton(
                    icon: "arrow.triangle.2.circlepath",
                    size: 56,
                    isActive: false,
                    action: {
                        withAnimation(reduceMotion ? .none : .spring(response: 0.4, dampingFraction: 0.7)) {
                            isFrontPrimary.toggle()
                        }
                    }
                )
                .rotationEffect(.degrees(isFrontPrimary ? 0 : 180))
            }

            if !isRecording && cameraManager.hasRecordings {
                LiquidGlassButton(
                    title: "Merge Videos",
                    icon: "square.stack.3d.up.fill",
                    gradient: [Color.blue.opacity(0.6), Color.purple.opacity(0.5)],
                    action: { showMergeOptions = true }
                )
                .actionSheet(isPresented: $showMergeOptions) {
                    ActionSheet(title: Text("Merge Options"), buttons: [
                        .default(Text("Side by Side")) {
                            mergeVideos(layout: .sideBySide)
                        },
                        .default(Text("Picture in Picture")) {
                            mergeVideos(layout: .pictureInPicture)
                        },
                        .cancel()
                    ])
                }
            }

            if isMerging {
                MergeProgressView(progress: mergeProgress)
            }
        }
    }

    private func startRecording() {
        cameraManager.startRecording()
        isRecording = true
        recordingTime = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                recordingTime += 1
            }
        }
    }

    private func stopRecording() {
        cameraManager.stopRecording()
        isRecording = false
        timer?.invalidate()
        timer = nil
    }

    private func requestPermissions() {
        let permissionManager = PermissionManager.shared
        permissionManager.requestAllPermissions { allGranted, deniedPermissions in
            Task { @MainActor in
                self.permissionsGranted = allGranted
                if !allGranted {
                    self.showPermissionAlert = true
                } else {
                    self.cameraManager.setup()
                }
            }
        }
    }

    private func openSettings() {
        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsURL)
        }
    }

    private func mergeVideos(layout: MergeLayout) {
        let urls = cameraManager.getRecordingURLs()
        guard let frontURL = urls.front,
              let backURL = urls.back else {
            return
        }

        isMerging = true
        mergeProgress = 0.0

        let merger = VideoMerger()
        merger.mergeVideos(frontURL: frontURL, backURL: backURL, layout: layout == .sideBySide ? .sideBySide : .pip, quality: videoQuality) { result in
            DispatchQueue.main.async {
                self.isMerging = false
                switch result {
                case .success:
                    self.mergeProgress = 1.0
                case .failure(let error):
                    print("Merge failed: \(error)")
                }
            }
        }
    }
}

struct LiquidGlassControlButton: View {
    let icon: String
    var text: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                if let text = text {
                    Text(text)
                        .font(.system(size: 14, weight: .semibold))
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, text != nil ? 16 : 12)
            .padding(.vertical, 10)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.25),
                                    Color.white.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.ultraThinMaterial)
                    
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.4),
                                    Color.white.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
            )
            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(LiquidGlassPressStyle())
    }
}

struct LiquidGlassCircularButton: View {
    let icon: String
    let size: CGFloat
    let isActive: Bool
    let action: () -> Void
    
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.25),
                                Color.white.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Circle()
                    .fill(.ultraThinMaterial)
                
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.4),
                                Color.white.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                
                Image(systemName: icon)
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundColor(isActive ? .yellow : .white)
            }
            .frame(width: size, height: size)
            .shadow(color: isActive ? .yellow.opacity(0.3) : .black.opacity(0.2), radius: 12, x: 0, y: 4)
        }
        .buttonStyle(LiquidGlassPressStyle())
        .scaleEffect(isActive ? 1.05 : 1.0)
        .animation(reduceMotion ? .none : .spring(response: 0.3), value: isActive)
    }
}

struct MainRecordButton: View {
    let isRecording: Bool
    let isPhotoMode: Bool
    let action: () -> Void
    
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        Button(action: action) {
            ZStack {
                if isRecording && !reduceMotion {
                    Circle()
                        .stroke(Color.red.opacity(0.5), lineWidth: 4)
                        .frame(width: 90, height: 90)
                        .scaleEffect(isRecording ? 1.1 : 1.0)
                        .opacity(isRecording ? 1.0 : 0.0)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isRecording)
                }

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.3),
                                Color.white.opacity(0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 76, height: 76)
                
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 76, height: 76)
                
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.5),
                                Color.white.opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .frame(width: 76, height: 76)

                if isPhotoMode {
                    Image(systemName: "camera.aperture")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundColor(.white)
                } else if isRecording {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.red)
                        .frame(width: 28, height: 28)
                } else {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 28, height: 28)
                }
            }
            .shadow(color: isRecording ? .red.opacity(0.4) : .black.opacity(0.3), radius: 16, x: 0, y: 6)
        }
        .buttonStyle(LiquidGlassPressStyle())
        .scaleEffect(isRecording ? 0.95 : 1.0)
        .animation(reduceMotion ? .none : .easeInOut, value: isRecording)
    }
}

struct CameraPreviewCard: View {
    let title: String
    let previewLayer: AVCaptureVideoPreviewLayer?
    let isFlashOn: Bool
    @Binding var showFlashPulse: Bool
    var onFlashToggle: (() -> Void)? = nil
    var onSwap: (() -> Void)? = nil
    var onZoom: ((CGFloat) -> Void)? = nil

    var body: some View {
        ZStack {
            CameraPreviewViewWrapper(
                previewLayer: previewLayer,
                onTap: { _ in }
            )
            .aspectRatio(9/16, contentMode: .fit)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.3),
                                Color.white.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 8)

            VStack {
                HStack {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.25),
                                                Color.white.opacity(0.1)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(.ultraThinMaterial)
                            }
                        )
                    Spacer()
                }
                .padding(12)

                Spacer()

                HStack {
                    if let flashToggle = onFlashToggle {
                        Button(action: flashToggle) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.25),
                                                Color.white.opacity(0.1)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                
                                Circle()
                                    .fill(.ultraThinMaterial)
                                
                                Image(systemName: isFlashOn ? "bolt.fill" : "bolt.slash.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(isFlashOn ? .yellow : .white)
                            }
                            .frame(width: 40, height: 40)
                        }
                        .buttonStyle(LiquidGlassPressStyle())
                    }
                    
                    Spacer()
                    
                    if let swap = onSwap {
                        Button(action: swap) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.25),
                                                Color.white.opacity(0.1)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                
                                Circle()
                                    .fill(.ultraThinMaterial)
                                
                                Image(systemName: "arrow.left.arrow.right")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            .frame(width: 40, height: 40)
                        }
                        .buttonStyle(LiquidGlassPressStyle())
                    }
                }
                .padding(12)
            }
        }
        .gesture(
            MagnificationGesture()
                .onChanged { scale in
                    onZoom?(scale)
                }
        )
    }
}

struct RecordingTimerView: View {
    let recordingTime: Int
    
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
                .opacity(0.8)
                .scaleEffect(reduceMotion ? 1.0 : 1.2)
                .animation(reduceMotion ? .none : .easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: recordingTime)

            Text(String(format: "%02d:%02d", recordingTime / 60, recordingTime % 60))
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.red.opacity(0.3),
                                Color.red.opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.red.opacity(0.5), lineWidth: 1)
            }
        )
        .shadow(color: .red.opacity(0.3), radius: 12, x: 0, y: 4)
    }
}

struct LiquidGlassButton: View {
    let title: String
    let icon: String
    let gradient: [Color]
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 28)
            .padding(.vertical, 14)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: gradient,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(.ultraThinMaterial)
                    
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.5),
                                    Color.white.opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
            )
            .shadow(color: gradient.first?.opacity(0.4) ?? .clear, radius: 16, x: 0, y: 6)
        }
        .buttonStyle(LiquidGlassPressStyle())
    }
}

struct MergeProgressView: View {
    let progress: Float

    var body: some View {
        VStack(spacing: 12) {
            Text("Merging Videos...")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
            
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .frame(width: 220, height: 6)
                
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: CGFloat(progress) * 220, height: 6)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 24)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.2),
                                Color.white.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
        )
        .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 4)
    }
}

struct LiquidGlassPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(reduceMotion ? .none : .spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

enum MergeLayout {
    case sideBySide, pictureInPicture
}

struct CameraPreviewViewWrapper: UIViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer?
    let onTap: ((CGPoint) -> Void)?

    init(previewLayer: AVCaptureVideoPreviewLayer?, onTap: ((CGPoint) -> Void)? = nil) {
        self.previewLayer = previewLayer
        self.onTap = onTap
    }

    func makeUIView(context: Context) -> FocusableCameraView {
        let view = FocusableCameraView()
        view.onTap = onTap
        if let layer = previewLayer {
            view.layer.addSublayer(layer)
            layer.videoGravity = .resizeAspectFill
            DispatchQueue.main.async {
                layer.frame = view.bounds
            }
        }
        return view
    }

    func updateUIView(_ uiView: FocusableCameraView, context: Context) {
        uiView.onTap = onTap
        if let layer = previewLayer {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            layer.frame = uiView.bounds
            CATransaction.commit()
        }
    }
}

class FocusableCameraView: UIView {
    var onTap: ((CGPoint) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupTapGesture()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTapGesture()
    }

    private func setupTapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tapGesture)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.sublayers?.forEach { sublayer in
            if let previewLayer = sublayer as? AVCaptureVideoPreviewLayer {
                previewLayer.frame = bounds
            }
        }
        CATransaction.commit()
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: self)
        onTap?(location)
        showFocusIndicator(at: location)
    }

    private func showFocusIndicator(at point: CGPoint) {
        let indicatorView = UIView(frame: CGRect(x: 0, y: 0, width: 80, height: 80))
        indicatorView.center = point
        indicatorView.backgroundColor = .clear
        indicatorView.layer.borderColor = UIColor.systemYellow.cgColor
        indicatorView.layer.borderWidth = 2
        indicatorView.layer.cornerRadius = 40
        indicatorView.alpha = 0
        addSubview(indicatorView)

        UIView.animate(withDuration: 0.2, animations: {
            indicatorView.alpha = 1.0
            indicatorView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        }) { _ in
            UIView.animate(withDuration: 0.3, delay: 0.5, options: [], animations: {
                indicatorView.alpha = 0
                indicatorView.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
            }) { _ in
                indicatorView.removeFromSuperview()
            }
        }
    }
}

@Observable
class CameraManagerWrapper: NSObject, DualCameraManagerDelegate {
    private let dualCameraManager = DualCameraManager()
    var frontPreviewLayer: AVCaptureVideoPreviewLayer?
    var backPreviewLayer: AVCaptureVideoPreviewLayer?
    var isFlashOn = false
    var hasRecordings = false

    override init() {
        super.init()
        dualCameraManager.delegate = self
    }

    func setup() {
        dualCameraManager.setupCameras()
    }

    func stop() {
        dualCameraManager.stopSessions()
    }

    func startRecording() {
        dualCameraManager.startRecording()
    }

    func stopRecording() {
        dualCameraManager.stopRecording()
    }

    func capturePhoto() {
        dualCameraManager.capturePhoto()
    }

    func toggleFlash() {
        dualCameraManager.toggleFlash()
        isFlashOn = dualCameraManager.isFlashOn
    }

    func setVideoQuality(_ quality: VideoQuality) {
        dualCameraManager.videoQuality = quality
    }

    func setZoom(for position: AVCaptureDevice.Position, scale: CGFloat) {
        dualCameraManager.setZoom(for: position, scale: scale)
    }

    func didStartRecording() {
        // Delegate method - ensure thread safety
        DispatchQueue.main.async {
            // Update UI state if needed
        }
    }

    func didStopRecording() {
        // Delegate method - ensure thread safety
        DispatchQueue.main.async {
            self.hasRecordings = true
        }
    }

    func didFailWithError(_ error: Error) {
        // Delegate method - ensure thread safety
        DispatchQueue.main.async {
            print("Error: \(error)")
            // Could show error alert here
        }
    }

    func didUpdateVideoQuality(to quality: VideoQuality) {
        // Delegate method - ensure thread safety
        DispatchQueue.main.async {
            // Update UI state if needed
        }
    }

    func didFinishCameraSetup() {
        // Delegate method - ensure thread safety
        DispatchQueue.main.async {
            self.frontPreviewLayer = self.dualCameraManager.frontPreviewLayer
            self.backPreviewLayer = self.dualCameraManager.backPreviewLayer
        }
    }

    func didCapturePhoto(frontImage: UIImage?, backImage: UIImage?) {
        // Delegate method - ensure thread safety
        DispatchQueue.main.async {
            // Handle captured photos if needed
        }
    }

    func didUpdateSetupProgress(_ message: String, progress: Float) {
        // Delegate method - ensure thread safety
        DispatchQueue.main.async {
            // Update setup progress if needed
            print("Setup progress: \(message) (\(Int(progress * 100))%)")
        }
    }

    func updatePreviewLayers() {
        frontPreviewLayer = dualCameraManager.frontPreviewLayer
        backPreviewLayer = dualCameraManager.backPreviewLayer
    }
    
    func getRecordingURLs() -> (front: URL?, back: URL?) {
        let urls = dualCameraManager.getRecordingURLs()
        return (urls.front, urls.back)
    }
}

struct GalleryView: View {
    @State private var galleryManager = GalleryManager()
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.black,
                        Color(hex: "0A0A0F"),
                        Color(hex: "0F0F1A")
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                if galleryManager.videos.isEmpty {
                    VStack(spacing: 20) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.15),
                                            Color.white.opacity(0.05)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 120, height: 120)
                            
                            Image(systemName: "video.slash.fill")
                                .font(.system(size: 48, weight: .light))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        
                        Text("No videos yet")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                        
                        Text("Record some videos to see them here")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                } else {
                    ScrollView {
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 16),
                            GridItem(.flexible(), spacing: 16)
                        ], spacing: 16) {
                            ForEach(galleryManager.videos) { video in
                                VideoThumbnailView(
                                    video: video,
                                    isSelected: galleryManager.selectedVideo?.id == video.id,
                                    isSelecting: false,
                                    onTap: {
                                        galleryManager.selectedVideo = video
                                    },
                                    onLongPress: {},
                                    onSelect: {}
                                )
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Gallery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 32, height: 32)
                            
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                }
            }
        }
    }
}



@Observable
class GalleryManager {
    var videos: [VideoItem] = []
    var selectedVideo: VideoItem?

    init() {
        loadVideos()
    }

    private func loadVideos() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension.lowercased() == "mov" || $0.pathExtension.lowercased() == "mp4" }
                .sorted { url1, url2 in
                    let date1 = (try? FileManager.default.attributesOfItem(atPath: url1.path)[.creationDate] as? Date) ?? Date.distantPast
                    let date2 = (try? FileManager.default.attributesOfItem(atPath: url2.path)[.creationDate] as? Date) ?? Date.distantPast
                    return date1 > date2
                }

            videos = fileURLs.map { url in
                let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
                let createdAt = attributes?[.creationDate] as? Date ?? Date()
                let fileSize = attributes?[.size] as? Int64 ?? 0

                return VideoItem(
                    id: UUID(),
                    url: url,
                    source: .dualCamera,
                    metadata: VideoMetadata(
                        title: url.lastPathComponent
                    ),
                    thumbnail: nil,
                    createdAt: createdAt,
                    duration: 0.0,
                    fileSize: fileSize
                )
            }
        } catch {
            print("Error loading videos: \(error)")
        }
    }
}


