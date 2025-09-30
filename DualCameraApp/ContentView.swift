import SwiftUI
import AVFoundation

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
            Color.black.edgesIgnoringSafeArea(.all)

            VStack(spacing: 16) {
                // Top controls
                HStack {
                    Button(action: { showQualityPicker = true }) {
                        Text(videoQuality.rawValue)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial)
                            .cornerRadius(8)
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

                    Button(action: { showGallery = true }) {
                        Image(systemName: "photo.on.rectangle")
                            .foregroundColor(.white)
                            .padding(8)
                            .background(.ultraThinMaterial)
                            .cornerRadius(8)
                    }
                    .sheet(isPresented: $showGallery) {
                        GalleryView()
                    }
                }
                .padding(.horizontal)

                // Camera previews
                ZStack {
                    VStack(spacing: 16) {
                        CameraPreviewViewWrapper(previewLayer: cameraManager.frontPreviewLayer)
                            .frame(height: UIScreen.main.bounds.height * 0.35)
                            .cornerRadius(12)
                            .overlay(
                                Text("Front Camera")
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(.ultraThinMaterial)
                                    .cornerRadius(6)
                                    .padding(8),
                                alignment: .topLeading
                            )
                            .gesture(
                                MagnificationGesture()
                                    .onChanged { scale in
                                        cameraManager.setZoom(for: .front, scale: scale)
                                    }
                            )
                            .gesture(
                                TapGesture()
                                    .onEnded { _ in
                                        // Handle tap for focus
                                    }
                            )

                        CameraPreviewViewWrapper(previewLayer: cameraManager.backPreviewLayer)
                            .frame(height: UIScreen.main.bounds.height * 0.35)
                            .cornerRadius(12)
                            .overlay(
                                Text("Back Camera")
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(.ultraThinMaterial)
                                    .cornerRadius(6)
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

                    if isRecording {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                ZStack {
                                    Circle()
                                        .fill(Color.red.opacity(0.3))
                                        .frame(width: 60, height: 60)
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 20, height: 20)
                                }
                                .padding()
                            }
                        }
                    }
                }

                Spacer()

                // Bottom controls
                VStack(spacing: 16) {
                    if isRecording {
                        Text(String(format: "%02d:%02d", recordingTime / 60, recordingTime % 60))
                            .foregroundColor(.red)
                            .font(.title.monospaced())
                    }

                    HStack(spacing: 20) {
                        Button(action: cameraManager.toggleFlash) {
                            Image(systemName: cameraManager.isFlashOn ? "bolt.fill" : "bolt.slash.fill")
                                .foregroundColor(.white)
                                .padding(12)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }

                        Button(action: {
                            if isPhotoMode {
                                cameraManager.capturePhoto()
                            } else {
                                if isRecording {
                                    stopRecording()
                                } else {
                                    startRecording()
                                }
                            }
                        }) {
                            Image(systemName: isPhotoMode ? "camera.circle.fill" : (isRecording ? "stop.circle.fill" : "record.circle.fill"))
                                .resizable()
                                .frame(width: 60, height: 60)
                                .foregroundColor(isRecording ? .white : .red)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }

                        Button(action: {
                            isFrontPrimary.toggle()
                            // Swap views logic
                        }) {
                            Image(systemName: "arrow.up.arrow.down.circle.fill")
                                .foregroundColor(.white)
                                .padding(12)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                    }

                    if !isRecording && cameraManager.hasRecordings {
                        Button(action: { showMergeOptions = true }) {
                            Text("Merge Videos")
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(.ultraThinMaterial)
                                .cornerRadius(20)
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
                        ProgressView(value: mergeProgress)
                            .progressViewStyle(LinearProgressViewStyle())
                            .padding(.horizontal)
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
        guard let urls = cameraManager.getRecordingURLs(),
              let frontURL = urls.front,
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

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        if let layer = previewLayer {
            layer.frame = view.bounds
            view.layer.addSublayer(layer)
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let layer = previewLayer {
            layer.frame = uiView.bounds
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.dualCameraManager.updatePreviewLayers()
        }
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

    func didCapturePhoto(frontImage: UIImage?, backImage: UIImage?) {
        // Handle photo capture
    }

    // Custom method to set preview layers after setup
    func updatePreviewLayers() {
        frontPreviewLayer = dualCameraManager.frontPreviewLayer
        backPreviewLayer = dualCameraManager.backPreviewLayer
    }
}

struct GalleryView: View {
    var body: some View {
        Text("Gallery - Coming Soon")
            .foregroundColor(.white)
    }
}