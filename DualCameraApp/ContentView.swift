import SwiftUI
import AVFoundation

// MARK: - Color Extensions
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
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

struct ContentView: View {
    @StateObject private var cameraManager = CameraManagerWrapper()
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

    var body: some View {
        ZStack {
            // Dark theme background with blue accent
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: "0A0A0F"),
                    Color(hex: "0F0F1A"),
                    Color(hex: "1A1A2E")
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .edgesIgnoringSafeArea(.all)

            // Subtle blue accent overlay
            Color.blue.opacity(0.02)
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 16) {
                // Top overlay controls
                HStack {
                    Button(action: { showQualityPicker = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "video")
                                .font(.system(size: 14, weight: .medium))
                            Text(videoQuality.rawValue)
                                .font(.system(size: 14, weight: .semibold, design: .default))
                        }
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial.opacity(0.8))
                        .cornerRadius(20)
                        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                    }
                    .actionSheet(isPresented: $showQualityPicker) {
                        ActionSheet(title: Text("Video Quality"), buttons: VideoQuality.allCases.map { quality in
                            .default(Text(quality.rawValue)) {
                                self.videoQuality = quality
                                cameraManager.setVideoQuality(quality)
                            }
                        } + [.cancel()])
                    }

                    Spacer()

                    // Recording timer overlay
                    if isRecording {
                        Text(String(format: "%02d:%02d", recordingTime / 60, recordingTime % 60))
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(.red)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial.opacity(0.9))
                            .cornerRadius(16)
                            .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 6)
                    }

                    Spacer()

                    Button(action: { showGallery = true }) {
                        Image(systemName: "photo.stack")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                            .padding(12)
                            .background(.ultraThinMaterial.opacity(0.8))
                            .cornerRadius(20)
                            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                    }
                    .sheet(isPresented: $showGallery) {
                        GalleryView()
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)

                // Camera previews - Side by side layout
                ZStack {
                    HStack(spacing: 12) {
                        CameraPreviewViewWrapper(
                            previewLayer: cameraManager.frontPreviewLayer,
                            onTap: { location in
                                // Handle front camera focus
                                // This would need to be passed to the manager
                            }
                        )
                            .frame(maxWidth: .infinity)
                            .aspectRatio(16/9, contentMode: .fit)
                            .cornerRadius(16)
                            .overlay(
                                VStack {
                                    HStack {
                                        Text("Front Camera")
                                            .font(.system(size: 12, weight: .semibold, design: .default))
                                            .foregroundColor(.white.opacity(0.9))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(.ultraThinMaterial.opacity(0.8))
                                            .cornerRadius(8)
                                        Spacer()
                                    }
                                    Spacer()
                                    // Overlay controls for front camera
                                    HStack {
                                        Button(action: {
                                            cameraManager.toggleFlash()
                                        }) {
                                            Image(systemName: cameraManager.isFlashOn ? "bolt.fill" : "bolt.slash")
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundColor(.white.opacity(0.9))
                                                .padding(8)
                                                .background(.ultraThinMaterial.opacity(0.6))
                                                .clipShape(Circle())
                                        }
                                        Spacer()
                                    }
                                    .padding(12)
                                }
                                .padding(8),
                                alignment: .topLeading
                            )
                            .gesture(
                                MagnificationGesture()
                                    .onChanged { scale in
                                        cameraManager.setZoom(for: .front, scale: scale)
                                    }
                            )

                        CameraPreviewViewWrapper(
                            previewLayer: cameraManager.backPreviewLayer,
                            onTap: { location in
                                // Handle back camera focus
                                // This would need to be passed to the manager
                            }
                        )
                            .frame(maxWidth: .infinity)
                            .aspectRatio(16/9, contentMode: .fit)
                            .cornerRadius(16)
                            .overlay(
                                VStack {
                                    HStack {
                                        Text("Back Camera")
                                            .font(.system(size: 12, weight: .semibold, design: .default))
                                            .foregroundColor(.white.opacity(0.9))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(.ultraThinMaterial.opacity(0.8))
                                            .cornerRadius(8)
                                        Spacer()
                                    }
                                    Spacer()
                                    // Overlay controls for back camera
                                    HStack {
                                        Spacer()
                                        Button(action: {
                                            isFrontPrimary.toggle()
                                            // Swap views logic
                                        }) {
                                            Image(systemName: "arrow.left.arrow.right")
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundColor(.white.opacity(0.9))
                                                .padding(8)
                                                .background(.ultraThinMaterial.opacity(0.6))
                                                .clipShape(Circle())
                                        }
                                    }
                                    .padding(12)
                                }
                                .padding(8),
                                alignment: .topLeading
                            )
                            .gesture(
                                MagnificationGesture()
                                    .onChanged { scale in
                                        cameraManager.setZoom(for: .back, scale: scale)
                                    }
                            )
                    }
                    .padding(.horizontal)
                    .overlay(
                        // Recording indicator overlay
                        Group {
                            if isRecording {
                                VStack {
                                    Spacer()
                                    HStack {
                                        Spacer()
                                        ZStack {
                                            Circle()
                                                .fill(Color.red.opacity(0.2))
                                                .frame(width: 80, height: 80)
                                                .blur(radius: 2)
                                            Circle()
                                                .fill(Color.red.opacity(0.8))
                                                .frame(width: 24, height: 24)
                                                .shadow(color: .red.opacity(0.5), radius: 8, x: 0, y: 0)
                                        }
                                        .padding(.trailing, 20)
                                        .padding(.bottom, 20)
                                    }
                                }
                            }
                        }
                    )
                }

                Spacer()

                // Modern bottom controls with glassmorphism
                VStack(spacing: 20) {
                    HStack(spacing: 24) {
                        // Flash control (moved to overlay, but keeping for consistency)
                        Button(action: cameraManager.toggleFlash) {
                            ZStack {
                                Circle()
                                    .fill(.ultraThinMaterial.opacity(0.8))
                                    .frame(width: 50, height: 50)
                                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                                Image(systemName: cameraManager.isFlashOn ? "bolt.fill" : "bolt.slash")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.white.opacity(0.9))
                            }
                        }
                        .scaleEffect(cameraManager.isFlashOn ? 1.1 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: cameraManager.isFlashOn)

                        // Main record/capture button
                        Button(action: {
                            if isPhotoMode {
                                cameraManager.capturePhoto()
                                // Add capture animation
                                withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                                    // Flash effect
                                }
                            } else {
                                if isRecording {
                                    stopRecording()
                                } else {
                                    startRecording()
                                }
                            }
                        }) {
                            ZStack {
                                // Outer ring for recording state
                                if isRecording {
                                    Circle()
                                        .stroke(Color.red.opacity(0.5), lineWidth: 4)
                                        .frame(width: 80, height: 80)
                                        .scaleEffect(isRecording ? 1.2 : 1.0)
                                        .opacity(isRecording ? 1.0 : 0.0)
                                        .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: isRecording)
                                }

                                // Main button background
                                Circle()
                                    .fill(.ultraThinMaterial.opacity(0.9))
                                    .frame(width: 72, height: 72)
                                    .shadow(color: isRecording ? .red.opacity(0.3) : .black.opacity(0.3), radius: 12, x: 0, y: 6)

                                // Icon
                                Image(systemName: isPhotoMode ? "camera.aperture" : (isRecording ? "stop.fill" : "record.circle"))
                                    .font(.system(size: isPhotoMode ? 28 : 32, weight: .medium))
                                    .foregroundColor(isRecording ? .red : .white.opacity(0.9))
                            }
                        }
                        .scaleEffect(isRecording ? 0.95 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isRecording)

                        // Camera switch control (moved to overlay, but keeping for consistency)
                        Button(action: {
                            isFrontPrimary.toggle()
                            // Swap views logic with animation
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                // Camera swap animation
                            }
                        }) {
                            ZStack {
                                Circle()
                                    .fill(.ultraThinMaterial.opacity(0.8))
                                    .frame(width: 50, height: 50)
                                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.white.opacity(0.9))
                            }
                        }
                        .rotationEffect(.degrees(isFrontPrimary ? 0 : 180))
                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isFrontPrimary)
                    }

                    // Merge controls with enhanced styling
                    if !isRecording && cameraManager.hasRecordings {
                        Button(action: { showMergeOptions = true }) {
                            HStack(spacing: 8) {
                                Image(systemName: "square.stack.3d.up")
                                    .font(.system(size: 16, weight: .medium))
                                Text("Merge Videos")
                                    .font(.system(size: 16, weight: .semibold, design: .default))
                            }
                            .foregroundColor(.white.opacity(0.9))
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.blue.opacity(0.6), Color.blue.opacity(0.4)]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                                .opacity(0.8)
                            )
                            .cornerRadius(25)
                            .shadow(color: .blue.opacity(0.3), radius: 12, x: 0, y: 6)
                        }
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
                        VStack(spacing: 12) {
                            Text("Merging Videos...")
                                .font(.system(size: 14, weight: .medium, design: .default))
                                .foregroundColor(.white.opacity(0.8))
                            ProgressView(value: mergeProgress)
                                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                                .frame(width: 200)
                                .scaleEffect(x: 1, y: 2, anchor: .center)
                        }
                        .padding(.vertical, 8)
                    }
                }
                .padding(.bottom, 20)
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

    private func startRecording() {
        cameraManager.startRecording()
        isRecording = true
        recordingTime = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            recordingTime += 1
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
            self.permissionsGranted = allGranted
            if !allGranted {
                self.showPermissionAlert = true
            } else {
                self.cameraManager.setup()
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
                    // Show success
                case .failure(let error):
                    print("Merge failed: \(error)")
                    // Show error
                }
            }
        }
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
            layer.frame = view.bounds
            view.layer.addSublayer(layer)
        }
        return view
    }

    func updateUIView(_ uiView: FocusableCameraView, context: Context) {
        uiView.onTap = onTap
        if let layer = previewLayer {
            layer.frame = uiView.bounds
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

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: self)
        onTap?(location)

        // Add focus animation
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

class CameraManagerWrapper: NSObject, ObservableObject, DualCameraManagerDelegate {
    private let dualCameraManager = DualCameraManager()
    @Published var frontPreviewLayer: AVCaptureVideoPreviewLayer?
    @Published var backPreviewLayer: AVCaptureVideoPreviewLayer?
    @Published var isFlashOn = false
    @Published var hasRecordings = false

    override init() {
        super.init()
        dualCameraManager.delegate = self
    }

    func setup() {
        dualCameraManager.setupCameras()
        // Wait for layers to be set
        // Preview layer update removed - not needed
        // DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
        //     self.dualCameraManager.updatePreviewLayers()
        // }
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

    // Delegate methods
    func didStartRecording() {
        // Handle start
    }

    func didStopRecording() {
        hasRecordings = true
    }

    func didFailWithError(_ error: Error) {
        print("Error: \(error)")
    }

    func didUpdateVideoQuality(to quality: VideoQuality) {
        // Handle quality update
    }
    
    func didFinishCameraSetup() {
        DispatchQueue.main.async {
            self.frontPreviewLayer = self.dualCameraManager.frontPreviewLayer
            self.backPreviewLayer = self.dualCameraManager.backPreviewLayer
        }
    }

    func didCapturePhoto(frontImage: UIImage?, backImage: UIImage?) {
        // Handle photo capture
    }

    // Custom method to set preview layers after setup
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
    @StateObject private var galleryManager = GalleryManager()
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            ZStack {
                // Dark theme background
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(hex: "0A0A0F"),
                        Color(hex: "0F0F1A"),
                        Color(hex: "1A1A2E")
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .edgesIgnoringSafeArea(.all)

                if galleryManager.videos.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "video.slash")
                            .font(.system(size: 64, weight: .light))
                            .foregroundColor(.white.opacity(0.5))
                        Text("No videos yet")
                            .font(.system(size: 20, weight: .medium, design: .default))
                            .foregroundColor(.white.opacity(0.7))
                        Text("Record some videos to see them here")
                            .font(.system(size: 16, weight: .regular, design: .default))
                            .foregroundColor(.white.opacity(0.5))
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
                                VideoThumbnailView(video: video) {
                                    // Handle video selection
                                    galleryManager.selectedVideo = video
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Video Gallery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
        }
        .accentColor(.blue)
    }
}

struct VideoThumbnailView: View {
    let video: VideoItem
    let onSelect: () -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.1))
                .frame(height: 120)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )

            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 70)

                    Image(systemName: "play.fill")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }

                VStack(spacing: 4) {
                    Text(video.fileName)
                        .font(.system(size: 12, weight: .medium, design: .default))
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(1)

                    Text(video.duration)
                        .font(.system(size: 10, weight: .regular, design: .default))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.horizontal, 8)
            }
        }
        .onTapGesture {
            onSelect()
        }
    }
}

class GalleryManager: ObservableObject {
    @Published var videos: [VideoItem] = []
    @Published var selectedVideo: VideoItem?

    init() {
        loadVideos()
    }

    private func loadVideos() {
        // Load videos from documents directory
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension.lowercased() == "mov" || $0.pathExtension.lowercased() == "mp4" }
                .sorted { url1, url2 in
                    let date1 = (try? FileManager.default.attributesOfItem(atPath: url1.path)[.creationDate] as? Date) ?? Date.distantPast
                    let date2 = (try? FileManager.default.attributesOfItem(atPath: url2.path)[.creationDate] as? Date) ?? Date.distantPast
                    return date1 > date2
                }

            videos = fileURLs.map { VideoItem(url: $0) }
        } catch {
            print("Error loading videos: \(error)")
        }
    }
}

struct VideoItem: Identifiable {
    let id = UUID()
    let url: URL
    var fileName: String { url.lastPathComponent }
    var duration: String {
        // Calculate duration (simplified)
        return "00:00"
    }
}