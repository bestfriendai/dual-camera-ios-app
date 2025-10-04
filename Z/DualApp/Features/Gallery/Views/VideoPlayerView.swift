//
//  VideoPlayerView.swift
//  DualApp
//
//  Created by DualApp Team on 10/3/25.
//

import SwiftUI
import AVFoundation
import AVKit

struct VideoPlayerView: View {
    let video: VideoItem
    @StateObject private var playerManager = VideoPlayerManager()
    @StateObject private var dualCameraPlayerManager = DualCameraPlayerManager()
    
    @State private var showingControls = true
    @State private var showingPlaybackSpeed = false
    @State private var showingQualityOptions = false
    @State private var showingShareOptions = false
    @State private var showingExportOptions = false
    @State private var showingTrimEditor = false
    @State private var isFullscreen = false
    @State private var controlsTimer: Timer?
    
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            // Background
            Color.black
                .ignoresSafeArea()
            
            // Video player
            if video.metadata.customMetadata["isDualCamera"] == "true" {
                DualCameraPlayerView(
                    manager: dualCameraPlayerManager,
                    video: video,
                    showingControls: showingControls
                )
            } else {
                SingleCameraPlayerView(
                    manager: playerManager,
                    video: video,
                    showingControls: showingControls
                )
            }
            
            // Controls overlay
            if showingControls {
                VStack(spacing: 0) {
                    // Top controls
                    topControls
                    
                    Spacer()
                    
                    // Bottom controls
                    bottomControls
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            
            // Loading indicator
            if playerManager.isLoading {
                VStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                    
                    Text("Loading...")
                        .foregroundColor(.white)
                        .padding(.top)
                }
            }
        }
        .navigationBarHidden(true)
        .statusBarHidden(isFullscreen)
        .onTapGesture {
            toggleControls()
        }
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            playerManager.cleanup()
            dualCameraPlayerManager.cleanup()
        }
        .sheet(isPresented: $showingPlaybackSpeed) {
            PlaybackSpeedView(
                currentSpeed: playerManager.playbackSpeed,
                onSpeedChanged: { speed in
                    playerManager.setPlaybackSpeed(speed)
                }
            )
        }
        .sheet(isPresented: $showingQualityOptions) {
            QualityOptionsView(
                currentQuality: playerManager.currentQuality,
                onQualityChanged: { quality in
                    playerManager.setQuality(quality)
                }
            )
        }
        .sheet(isPresented: $showingShareOptions) {
            ShareSheet(items: [video.url])
        }
        .sheet(isPresented: $showingExportOptions) {
            ExportOptionsView(
                videos: [video],
                onExport: { destination in
                    Task {
                        do {
                            _ = try await playerManager.exportTo(destination)
                        } catch {
                            // Handle error
                        }
                    }
                }
            )
        }
        .sheet(isPresented: $showingTrimEditor) {
            VideoTrimEditorView(
                video: video,
                onTrimComplete: { startTime, endTime in
                    Task {
                        do {
                            _ = try await playerManager.trim(from: startTime, to: endTime)
                        } catch {
                            // Handle error
                        }
                    }
                }
            )
        }
    }
    
    // MARK: - Top Controls
    
    private var topControls: some View {
        HStack {
            // Back button
            GlassButton(
                icon: "chevron.left",
                action: {
                    presentationMode.wrappedValue.dismiss()
                }
            )
            .frame(width: 44, height: 44)
            
            Spacer()
            
            // Video title
            VStack {
                Text(video.metadata.title)
                    .foregroundColor(.white)
                    .font(.headline)
                    .lineLimit(1)
                
                Text(video.formattedDuration)
                    .foregroundColor(.white.opacity(0.7))
                    .font(.caption)
            }
            .frame(maxWidth: 200)
            
            Spacer()
            
            // More options
            Menu {
                Button(action: { showingShareOptions = true }) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                
                Button(action: { showingExportOptions = true }) {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                
                Button(action: { showingTrimEditor = true }) {
                    Label("Trim", systemImage: "crop")
                }
                
                Button(action: { showingQualityOptions = true }) {
                    Label("Quality", systemImage: "tv")
                }
                
                Button(action: { showingPlaybackSpeed = true }) {
                    Label("Playback Speed", systemImage: "speedometer")
                }
                
                Button(action: { isFullscreen.toggle() }) {
                    Label(isFullscreen ? "Exit Fullscreen" : "Fullscreen", systemImage: isFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                }
            } label: {
                GlassButton(
                    icon: "ellipsis.circle",
                    action: {}
                )
                .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }
    
    // MARK: - Bottom Controls
    
    private var bottomControls: some View {
        VStack(spacing: 16) {
            // Progress bar
            VideoProgressBar(
                currentTime: playerManager.currentTime,
                duration: playerManager.duration,
                onSeek: { time in
                    playerManager.seek(to: time)
                }
            )
            .padding(.horizontal, 20)
            
            // Playback controls
            HStack(spacing: 20) {
                // Previous frame
                GlassButton(
                    icon: "backward.frame",
                    action: {
                        playerManager.stepBackward()
                    }
                )
                .frame(width: 44, height: 44)
                
                // Rewind
                GlassButton(
                    icon: "gobackward.10",
                    action: {
                        playerManager.skipBackward()
                    }
                )
                .frame(width: 44, height: 44)
                
                // Play/Pause
                GlassButton(
                    icon: playerManager.isPlaying ? "pause.fill" : "play.fill",
                    color: .blue,
                    action: {
                        playerManager.togglePlayPause()
                    }
                )
                .frame(width: 60, height: 60)
                
                // Fast forward
                GlassButton(
                    icon: "goforward.10",
                    action: {
                        playerManager.skipForward()
                    }
                )
                .frame(width: 44, height: 44)
                
                // Next frame
                GlassButton(
                    icon: "forward.frame",
                    action: {
                        playerManager.stepForward()
                    }
                )
                .frame(width: 44, height: 44)
            }
            
            // Time labels
            HStack {
                Text(formatTime(playerManager.currentTime))
                    .foregroundColor(.white)
                    .font(.caption)
                
                Spacer()
                
                Text(formatTime(playerManager.duration))
                    .foregroundColor(.white)
                    .font(.caption)
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 20)
        .background(
            GlassBackground(
                blur: 20,
                opacity: 0.5
            )
        )
    }
    
    // MARK: - Helper Methods
    
    private func setupPlayer() {
        Task {
            await playerManager.loadVideo(video.url)
        }
    }
    
    private func toggleControls() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showingControls.toggle()
        }
        
        if showingControls {
            startControlsTimer()
        } else {
            stopControlsTimer()
        }
    }
    
    private func startControlsTimer() {
        stopControlsTimer()
        controlsTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                showingControls = false
            }
        }
    }
    
    private func stopControlsTimer() {
        controlsTimer?.invalidate()
        controlsTimer = nil
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Single Camera Player View

struct SingleCameraPlayerView: View {
    @ObservedObject var manager: VideoPlayerManager
    let video: VideoItem
    let showingControls: Bool
    
    var body: some View {
        GeometryReader { geometry in
            AVPlayerView(player: manager.player)
                .onTapGesture {
                    // Handle tap gesture
                }
        }
    }
}

// MARK: - Dual Camera Player View

struct DualCameraPlayerView: View {
    @ObservedObject var manager: DualCameraPlayerManager
    let video: VideoItem
    let showingControls: Bool
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Front camera view
                AVPlayerView(player: manager.frontPlayer)
                    .frame(width: geometry.size.width / 2)
                    .overlay(
                        VStack {
                            HStack {
                                Text("Front")
                                    .foregroundColor(.white)
                                    .font(.caption)
                                    .padding(8)
                                    .background(
                                        GlassBackground(
                                            blur: 10,
                                            opacity: 0.5
                                        )
                                    )
                                    .cornerRadius(6)
                                Spacer()
                            }
                            Spacer()
                        }
                        .opacity(showingControls ? 1 : 0)
                    )
                
                // Back camera view
                AVPlayerView(player: manager.backPlayer)
                    .frame(width: geometry.size.width / 2)
                    .overlay(
                        VStack {
                            HStack {
                                Text("Back")
                                    .foregroundColor(.white)
                                    .font(.caption)
                                    .padding(8)
                                    .background(
                                        GlassBackground(
                                            blur: 10,
                                            opacity: 0.5
                                        )
                                    )
                                    .cornerRadius(6)
                                Spacer()
                            }
                            Spacer()
                        }
                        .opacity(showingControls ? 1 : 0)
                    )
            }
        }
    }
}

// MARK: - Video Progress Bar

struct VideoProgressBar: View {
    let currentTime: TimeInterval
    let duration: TimeInterval
    let onSeek: (TimeInterval) -> Void
    
    @State private var isDragging = false
    @State private var dragValue: Double = 0
    
    private var progress: Double {
        guard duration > 0 else { return 0 }
        return isDragging ? dragValue : currentTime / duration
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(height: 4)
                    .cornerRadius(2)
                
                // Progress track
                Rectangle()
                    .fill(Color.blue)
                    .frame(width: geometry.size.width * progress, height: 4)
                    .cornerRadius(2)
                
                // Thumb
                Circle()
                    .fill(Color.white)
                    .frame(width: 16, height: 16)
                    .offset(x: geometry.size.width * progress - 8)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                isDragging = true
                                let newProgress = max(0, min(1, value.location.x / geometry.size.width))
                                dragValue = newProgress
                                onSeek(duration * newProgress)
                            }
                            .onEnded { _ in
                                isDragging = false
                            }
                    )
            }
        }
        .frame(height: 20)
    }
}

// MARK: - Playback Speed View

struct PlaybackSpeedView: View {
    let currentSpeed: Float
    let onSpeedChanged: (Float) -> Void
    @Environment(\.presentationMode) var presentationMode
    
    private let speeds: [Float] = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Playback Speed")
                    .font(.headline)
                    .padding(.top)
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    ForEach(speeds, id: \.self) { speed in
                        Button(action: {
                            onSpeedChanged(speed)
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            VStack {
                                Text("\(speed)x")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                if speed == currentSpeed {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                            .frame(height: 60)
                            .frame(maxWidth: .infinity)
                            .background(
                                GlassBackground(
                                    blur: 20,
                                    opacity: 0.3
                                )
                            )
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("Playback Speed")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Quality Options View

struct QualityOptionsView: View {
    let currentQuality: VideoQuality
    let onQualityChanged: (VideoQuality) -> Void
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                ForEach(VideoQuality.allCases, id: \.self) { quality in
                    Button(action: {
                        onQualityChanged(quality)
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(quality.description)
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                Text("\(quality.resolution.width)×\(quality.resolution.height)")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            
                            Spacer()
                            
                            if quality == currentQuality {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                                    .font(.title2)
                            }
                        }
                        .padding()
                        .background(
                            GlassBackground(
                                blur: 20,
                                opacity: 0.3
                            )
                        )
                        .cornerRadius(12)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Quality Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Video Trim Editor View

struct VideoTrimEditorView: View {
    let video: VideoItem
    let onTrimComplete: (TimeInterval, TimeInterval) -> Void
    @Environment(\.presentationMode) var presentationMode
    
    @State private var startTime: TimeInterval = 0
    @State private var endTime: TimeInterval = 0
    @State private var isPlaying = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Video preview
                VideoPreviewView(url: video.url)
                    .frame(height: 200)
                    .cornerRadius(12)
                
                // Trim controls
                VStack(spacing: 16) {
                    // Time range slider
                    TimeRangeSlider(
                        startTime: $startTime,
                        endTime: $endTime,
                        duration: video.duration
                    )
                    
                    // Time labels
                    HStack {
                        Text(formatTime(startTime))
                            .foregroundColor(.white)
                            .font(.caption)
                        
                        Spacer()
                        
                        Text(formatTime(endTime))
                            .foregroundColor(.white)
                            .font(.caption)
                    }
                    
                    // Duration
                    Text("Duration: \(formatTime(endTime - startTime))")
                        .foregroundColor(.white.opacity(0.7))
                        .font(.subheadline)
                }
                .padding()
                .background(
                    GlassBackground(
                        blur: 20,
                        opacity: 0.3
                    )
                )
                .cornerRadius(12)
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 16) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        GlassBackground(
                            blur: 20,
                            opacity: 0.3
                        )
                    )
                    .cornerRadius(12)
                    
                    Button("Trim") {
                        onTrimComplete(startTime, endTime)
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.blue)
                    .cornerRadius(12)
                }
            }
            .padding()
            .navigationTitle("Trim Video")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                endTime = video.duration
            }
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Video Preview View

struct VideoPreviewView: View {
    let url: URL
    @StateObject private var playerManager = VideoPlayerManager()
    
    var body: some View {
        AVPlayerView(player: playerManager.player)
            .onAppear {
                Task {
                    await playerManager.loadVideo(url)
                }
            }
    }
}

// MARK: - Time Range Slider

struct TimeRangeSlider: View {
    @Binding var startTime: TimeInterval
    @Binding var endTime: TimeInterval
    let duration: TimeInterval
    
    @State private var isDraggingStart = false
    @State private var isDraggingEnd = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background track
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(height: 4)
                    .cornerRadius(2)
                
                // Selected range
                Rectangle()
                    .fill(Color.blue)
                    .frame(
                        width: geometry.size.width * ((endTime - startTime) / duration),
                        height: 4
                    )
                    .offset(x: geometry.size.width * (startTime / duration))
                    .cornerRadius(2)
                
                // Start thumb
                Circle()
                    .fill(Color.white)
                    .frame(width: 20, height: 20)
                    .offset(x: geometry.size.width * (startTime / duration) - 10)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                isDraggingStart = true
                                let newTime = max(0, min(endTime - 1, (value.location.x / geometry.size.width) * duration))
                                startTime = newTime
                            }
                            .onEnded { _ in
                                isDraggingStart = false
                            }
                    )
                
                // End thumb
                Circle()
                    .fill(Color.white)
                    .frame(width: 20, height: 20)
                    .offset(x: geometry.size.width * (endTime / duration) - 10)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                isDraggingEnd = true
                                let newTime = max(startTime + 1, min(duration, (value.location.x / geometry.size.width) * duration))
                                endTime = newTime
                            }
                            .onEnded { _ in
                                isDraggingEnd = false
                            }
                    )
            }
        }
        .frame(height: 40)
    }
}

// MARK: - Preview

struct VideoPlayerView_Previews: PreviewProvider {
    static var previews: some View {
        VideoPlayerView(
            video: VideoItem(
                id: UUID(),
                url: URL(fileURLWithPath: "/tmp/video.mp4"),
                source: .documents,
                metadata: VideoMetadata(),
                thumbnail: nil,
                createdAt: Date(),
                duration: 60,
                fileSize: 1000000
            )
        )
    }
}