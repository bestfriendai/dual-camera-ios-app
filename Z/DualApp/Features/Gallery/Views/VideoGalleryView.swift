//
//  VideoGalleryView.swift
//  DualApp
//
//  Created by DualApp Team on 10/3/25.
//

import SwiftUI
import AVFoundation
import Photos

struct VideoGalleryView: View {
    @State private var galleryManager = VideoGalleryManager()
    @State private var storageManager = VideoStorageManager()
    @State private var videoProcessor = VideoProcessor()
    
    @State private var selectedVideos: Set<UUID> = []
    @State private var showingVideoPlayer = false
    @State private var selectedVideo: VideoItem?
    @State private var showingShareSheet = false
    @State private var showingDeleteConfirmation = false
    @State private var showingExportOptions = false
    @State private var showingFilterOptions = false
    @State private var showingSortOptions = false
    @State private var searchText = ""
    @State private var isSelecting = false
    @State private var showingStorageInfo = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.black.opacity(0.9),
                        Color.gray.opacity(0.8)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Search and filter bar
                    searchAndFilterBar
                    
                    // Gallery content
                    if galleryManager.isLoading {
                        loadingView
                    } else if galleryManager.videoItems.isEmpty {
                        emptyStateView
                    } else {
                        galleryContent
                    }
                }
                
                // Floating action buttons
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        
                        VStack(spacing: 16) {
                            // Storage info button
                            GlassButton(
                                icon: "info.circle",
                                action: { showingStorageInfo = true }
                            )
                            .frame(width: 56, height: 56)
                            
                            // Select mode button
                            GlassButton(
                                icon: isSelecting ? "checkmark.circle.fill" : "checkmark.circle",
                                action: { toggleSelectionMode() }
                            )
                            .frame(width: 56, height: 56)
                            
                            // Delete button (only visible in select mode)
                            if isSelecting && !selectedVideos.isEmpty {
                                GlassButton(
                                    icon: "trash.fill",
                                    color: .red,
                                    action: { showingDeleteConfirmation = true }
                                )
                                .frame(width: 56, height: 56)
                            }
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("Gallery")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showingFilterOptions = true }) {
                            Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                        }
                        
                        Button(action: { showingSortOptions = true }) {
                            Label("Sort", systemImage: "arrow.up.arrow.down")
                        }
                        
                        Button(action: { galleryManager.refreshGallery() }) {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                        
                        Button(action: { showingStorageInfo = true }) {
                            Label("Storage Info", systemImage: "info.circle")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                }
            }
            .sheet(isPresented: $showingVideoPlayer) {
                if let video = selectedVideo {
                    VideoPlayerView(video: video)
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let video = selectedVideo {
                    ShareSheet(items: [video.url])
                }
            }
            .sheet(isPresented: $showingExportOptions) {
                ExportOptionsView(
                    videos: Array(selectedVideos).compactMap { id in
                        galleryManager.videoItems.first { $0.id == id }
                    },
                    onExport: { destination in
                        Task {
                            do {
                                _ = try await galleryManager.exportSelectedItems(to: destination)
                            } catch {
                                // Handle error
                            }
                        }
                    }
                )
            }
            .sheet(isPresented: $showingFilterOptions) {
                FilterOptionsView(
                    selectedFilter: galleryManager.currentFilter,
                    onFilterChanged: { filter in
                        Task {
                            await galleryManager.setFilterOption(filter)
                        }
                    }
                )
            }
            .sheet(isPresented: $showingSortOptions) {
                SortOptionsView(
                    selectedSort: galleryManager.currentSort,
                    onSortChanged: { sort in
                        Task {
                            await galleryManager.setSortOption(sort)
                        }
                    }
                )
            }
            .sheet(isPresented: $showingStorageInfo) {
                StorageInfoView(
                    storageInfo: storageManager.storageInfo,
                    cacheInfo: storageManager.cacheInfo
                )
            }
            .alert("Delete Videos", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    Task {
                        try await galleryManager.deleteSelectedItems()
                        selectedVideos.removeAll()
                    }
                }
            } message: {
                Text("Are you sure you want to delete \(selectedVideos.count) video(s)? This action cannot be undone.")
            }
            .onAppear {
                Task {
                    await galleryManager.loadVideoItems()
                }
            }
        }
    }
    
    // MARK: - Search and Filter Bar
    
    private var searchAndFilterBar: some View {
        VStack(spacing: 12) {
            // Search bar
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.white.opacity(0.7))
                    
                    TextField("Search videos...", text: $searchText)
                        .foregroundColor(.white)
                        .textFieldStyle(PlainTextFieldStyle())
                        .onChange(of: searchText) { newValue in
                            Task {
                                await galleryManager.setSearchText(newValue)
                            }
                        }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    GlassBackground(
                        blur: 20,
                        opacity: 0.3
                    )
                )
                .cornerRadius(12)
                
                // Filter button
                GlassButton(
                    icon: "line.3.horizontal.decrease.circle",
                    action: { showingFilterOptions = true }
                )
                .frame(width: 44, height: 44)
                
                // Sort button
                GlassButton(
                    icon: "arrow.up.arrow.down",
                    action: { showingSortOptions = true }
                )
                .frame(width: 44, height: 44)
            }
            .padding(.horizontal, 20)
            
            // Selection mode bar
            if isSelecting {
                HStack {
                    Text("\(selectedVideos.count) selected")
                        .foregroundColor(.white)
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Button("Select All") {
                        selectAll()
                    }
                    .foregroundColor(.blue)
                    .font(.subheadline)
                    
                    Button("Deselect All") {
                        selectedVideos.removeAll()
                    }
                    .foregroundColor(.red)
                    .font(.subheadline)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(
                    GlassBackground(
                        blur: 20,
                        opacity: 0.3
                    )
                )
            }
        }
        .padding(.top, 8)
    }
    
    // MARK: - Gallery Content
    
    private var galleryContent: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 150), spacing: 12)
            ], spacing: 12) {
                ForEach(galleryManager.filteredItems) { video in
                    VideoThumbnailView(
                        video: video,
                        isSelected: selectedVideos.contains(video.id),
                        isSelecting: isSelecting,
                        onTap: {
                            if isSelecting {
                                toggleSelection(for: video.id)
                            } else {
                                selectedVideo = video
                                showingVideoPlayer = true
                            }
                        },
                        onLongPress: {
                            if !isSelecting {
                                isSelecting = true
                                selectedVideos.insert(video.id)
                            }
                        },
                        onSelect: {
                            toggleSelection(for: video.id)
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.5)
            
            Text("Loading videos...")
                .foregroundColor(.white)
                .font(.headline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "video.slash")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.7))
            
            Text("No Videos Found")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("Start recording some videos to see them here")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Helper Methods
    
    private func toggleSelectionMode() {
        isSelecting.toggle()
        if !isSelecting {
            selectedVideos.removeAll()
        }
    }
    
    private func toggleSelection(for videoId: UUID) {
        if selectedVideos.contains(videoId) {
            selectedVideos.remove(videoId)
        } else {
            selectedVideos.insert(videoId)
        }
    }
    
    private func selectAll() {
        selectedVideos.removeAll()
        for video in galleryManager.filteredItems {
            selectedVideos.insert(video.id)
        }
    }
}

// MARK: - Video Thumbnail View

struct VideoThumbnailView: View {
    let video: VideoItem
    let isSelected: Bool
    let isSelecting: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void
    let onSelect: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        ZStack {
            // Video thumbnail
            Group {
                if let thumbnail = video.thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "video")
                                .font(.title)
                                .foregroundColor(.white.opacity(0.5))
                        )
                }
            }
            .frame(height: 150)
            .clipped()
            .cornerRadius(12)
            
            // Glass overlay
            GlassBackground(
                blur: 10,
                opacity: isHovered ? 0.2 : 0.1
            )
            .cornerRadius(12)
            
            // Duration badge
            VStack {
                HStack {
                    Spacer()
                    Text(video.formattedDuration)
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            GlassBackground(
                                blur: 20,
                                opacity: 0.5
                            )
                        )
                        .cornerRadius(6)
                }
                Spacer()
                
                // Video info
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(video.metadata.title)
                            .font(.caption)
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Text(video.formattedFileSize)
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    if isSelecting {
                        Button(action: onSelect) {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.title2)
                                .foregroundColor(isSelected ? .blue : .white)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
        }
        .onTapGesture {
            onTap()
        }
        .onLongPressGesture {
            onLongPress()
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .scaleEffect(isHovered ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
    }
}

// MARK: - Export Options View

struct ExportOptionsView: View {
    let videos: [VideoItem]
    let onExport: (VideoExportDestination) -> Void
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Export \(videos.count) video(s)")
                    .font(.headline)
                    .padding(.top)
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    ForEach(VideoExportDestination.allCases, id: \.self) { destination in
                        GlassButton(
                            icon: destination.icon,
                            title: destination.rawValue,
                            action: {
                                onExport(destination)
                                presentationMode.wrappedValue.dismiss()
                            }
                        )
                        .frame(height: 80)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("Export Options")
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

// MARK: - Filter Options View

struct FilterOptionsView: View {
    let selectedFilter: VideoFilterOption
    let onFilterChanged: (VideoFilterOption) -> Void
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                ForEach(VideoFilterOption.allCases, id: \.self) { filter in
                    Button(action: {
                        onFilterChanged(filter)
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack {
                            Image(systemName: filter.icon)
                                .font(.title2)
                                .foregroundColor(.white)
                            
                            Text(filter.rawValue)
                                .foregroundColor(.white)
                                .font(.headline)
                            
                            Spacer()
                            
                            if selectedFilter == filter {
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
            .navigationTitle("Filter Options")
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

// MARK: - Sort Options View

struct SortOptionsView: View {
    let selectedSort: VideoSortOption
    let onSortChanged: (VideoSortOption) -> Void
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                ForEach(VideoSortOption.allCases, id: \.self) { sort in
                    Button(action: {
                        onSortChanged(sort)
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack {
                            Image(systemName: sort.icon)
                                .font(.title2)
                                .foregroundColor(.white)
                            
                            Text(sort.rawValue)
                                .foregroundColor(.white)
                                .font(.headline)
                            
                            Spacer()
                            
                            if selectedSort == sort {
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
            .navigationTitle("Sort Options")
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

// MARK: - Storage Info View

struct StorageInfoView: View {
    let storageInfo: VideoStorageInfo
    let cacheInfo: VideoCacheInfo
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Storage overview
                    GlassCard {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Storage Overview")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Total Space")
                                        .font(.subheadline)
                                        .foregroundColor(.white.opacity(0.7))
                                    Text(storageInfo.formattedTotalSpace)
                                        .font(.title3)
                                        .foregroundColor(.white)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing) {
                                    Text("Available")
                                        .font(.subheadline)
                                        .foregroundColor(.white.opacity(0.7))
                                    Text(storageInfo.formattedAvailableSpace)
                                        .font(.title3)
                                        .foregroundColor(.green)
                                }
                            }
                            
                            // Progress bar
                            ProgressView(value: storageInfo.usagePercentage)
                                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                                .scaleEffect(y: 2.0)
                            
                            Text("\(Int(storageInfo.usagePercentage * 100))% used")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .padding()
                    }
                    
                    // Video statistics
                    GlassCard {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Video Statistics")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            HStack {
                                StatItem(
                                    title: "Total Videos",
                                    value: "\(storageInfo.videoCount)",
                                    icon: "video.fill"
                                )
                                
                                Spacer()
                                
                                StatItem(
                                    title: "Total Size",
                                    value: storageInfo.formattedTotalVideoSize,
                                    icon: "doc.fill"
                                )
                            }
                            
                            HStack {
                                StatItem(
                                    title: "Avg Duration",
                                    value: storageInfo.formattedAverageDuration,
                                    icon: "clock.fill"
                                )
                                
                                Spacer()
                                
                                StatItem(
                                    title: "Total Duration",
                                    value: storageInfo.formattedTotalDuration,
                                    icon: "timer"
                                )
                            }
                        }
                        .padding()
                    }
                    
                    // Cache information
                    GlassCard {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Cache Information")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            HStack {
                                StatItem(
                                    title: "Cache Size",
                                    value: cacheInfo.formattedTotalSize,
                                    icon: "externaldrive.fill"
                                )
                                
                                Spacer()
                                
                                StatItem(
                                    title: "Thumbnails",
                                    value: "\(cacheInfo.thumbnailCount)",
                                    icon: "photo.fill"
                                )
                            }
                            
                            Button("Clear Cache") {
                                // Clear cache action
                            }
                            .foregroundColor(.red)
                            .font(.subheadline)
                        }
                        .padding()
                    }
                }
                .padding()
            }
            .navigationTitle("Storage Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Stat Item

struct StatItem: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
            
            Text(value)
                .font(.headline)
                .foregroundColor(.white)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

struct VideoGalleryView_Previews: PreviewProvider {
    static var previews: some View {
        VideoGalleryView()
    }
}