// Dual Camera App
import Foundation
import AVFoundation
import Photos
import os.log

@MainActor
final class RecordingRepository {
    
    static let shared = RecordingRepository()
    
    private let logger = Logger(subsystem: "com.dualcameraapp", category: "RecordingRepository")
    private let fileManager = FileManager.default
    
    private(set) var recordings: [Recording] = []
    
    struct Recording: Identifiable {
        let id: UUID
        let frontURL: URL
        let backURL: URL
        let mergedURL: URL?
        let createdAt: Date
        let duration: TimeInterval
        let fileSize: Int64
        
        var displayName: String {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            return formatter.string(from: createdAt)
        }
    }
    
    enum RepositoryError: LocalizedError {
        case invalidURL
        case fileNotFound
        case saveFailed(Error)
        case deleteFailed(Error)
        case mergeInProgress
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid file URL"
            case .fileNotFound:
                return "Recording file not found"
            case .saveFailed(let error):
                return "Failed to save: \(error.localizedDescription)"
            case .deleteFailed(let error):
                return "Failed to delete: \(error.localizedDescription)"
            case .mergeInProgress:
                return "Another merge operation is in progress"
            }
        }
    }
    
    private init() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.loadRecordings()
        }
    }
    
    func add(frontURL: URL, backURL: URL, completion: @escaping (Result<Recording, RepositoryError>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            guard self.fileManager.fileExists(atPath: frontURL.path),
                  self.fileManager.fileExists(atPath: backURL.path) else {
                DispatchQueue.main.async {
                    completion(.failure(.fileNotFound))
                }
                return
            }
            
            let duration = self.getDuration(for: frontURL)
            let fileSize = self.getFileSize(for: frontURL) + self.getFileSize(for: backURL)
            
            let recording = Recording(
                id: UUID(),
                frontURL: frontURL,
                backURL: backURL,
                mergedURL: nil,
                createdAt: Date(),
                duration: duration,
                fileSize: fileSize
            )
            
            DispatchQueue.main.async {
                self.recordings.append(recording)
                self.logger.info("Added recording: \(recording.id)")
                completion(.success(recording))
            }
        }
    }
    
    func delete(_ recording: Recording, completion: @escaping (Result<Void, RepositoryError>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            do {
                try self.fileManager.removeItem(at: recording.frontURL)
                try self.fileManager.removeItem(at: recording.backURL)
                
                if let mergedURL = recording.mergedURL {
                    try? self.fileManager.removeItem(at: mergedURL)
                }
                
                DispatchQueue.main.async {
                    self.recordings.removeAll { $0.id == recording.id }
                    self.logger.info("Deleted recording: \(recording.id)")
                    completion(.success(()))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(.deleteFailed(error)))
                }
            }
        }
    }
    
    func cleanupOldRecordings(olderThan days: Int, completion: @escaping (Int) -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
            let oldRecordings = self.recordings.filter { $0.createdAt < cutoffDate }
            
            DispatchQueue.global(qos: .utility).async {
                var deletedCount = 0
                
                for recording in oldRecordings {
                    try? self.fileManager.removeItem(at: recording.frontURL)
                    try? self.fileManager.removeItem(at: recording.backURL)
                    if let mergedURL = recording.mergedURL {
                        try? self.fileManager.removeItem(at: mergedURL)
                    }
                    deletedCount += 1
                }
                
                DispatchQueue.main.async {
                    self.recordings.removeAll { $0.createdAt < cutoffDate }
                    self.logger.info("Cleaned up \(deletedCount) old recordings")
                    completion(deletedCount)
                }
            }
        }
    }
    
    func saveToPhotoLibrary(_ recording: Recording, completion: @escaping (Result<Void, RepositoryError>) -> Void) {
        guard let urlToSave = recording.mergedURL ?? (FileManager.default.fileExists(atPath: recording.frontURL.path) ? recording.frontURL : nil) else {
            completion(.failure(.fileNotFound))
            return
        }
        
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: urlToSave)
        }) { success, error in
            DispatchQueue.main.async {
                if success {
                    self.logger.info("Saved to photo library: \(recording.id)")
                    completion(.success(()))
                } else if let error = error {
                    completion(.failure(.saveFailed(error)))
                } else {
                    completion(.failure(.saveFailed(NSError(domain: "RecordingRepository", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown error"]))))
                }
            }
        }
    }
    
    func getTotalStorageUsed() -> Int64 {
        return recordings.reduce(0) { $0 + $1.fileSize }
    }
    
    private func loadRecordings() {
        let tempDir = fileManager.temporaryDirectory
        
        do {
            let contents = try fileManager.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: [.creationDateKey], options: .skipsHiddenFiles)
            
            let videoFiles = contents.filter { $0.pathExtension == "mov" }
            
            logger.info("Found \(videoFiles.count) video files in temp directory")
        } catch {
            logger.error("Failed to load recordings: \(error.localizedDescription)")
        }
    }
    
    private func getDuration(for url: URL) -> TimeInterval {
        let asset = AVAsset(url: url)
        return asset.duration.seconds
    }
    
    private func getFileSize(for url: URL) -> Int64 {
        do {
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            return attributes[.size] as? Int64 ?? 0
        } catch {
            return 0
        }
    }
}
