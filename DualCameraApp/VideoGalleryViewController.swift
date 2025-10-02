import UIKit
import AVFoundation
import AVKit

class VideoGalleryViewController: UIViewController {
    
    private let collectionView: UICollectionView
    private var videoURLs: [URL] = []
    private var gradientLayer: CAGradientLayer?
    
    init() {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumInteritemSpacing = 10
        layout.minimumLineSpacing = 10
        layout.sectionInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        
        self.collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadVideos()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradientLayer?.frame = view.bounds
        CATransaction.commit()
    }
    
    private func setupUI() {
        let gradient = CAGradientLayer()
        gradient.colors = [
            UIColor(hex: "0A0A0F").cgColor,
            UIColor(hex: "0F0F1A").cgColor,
            UIColor(hex: "1A1A2E").cgColor
        ]
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 0, y: 1)
        gradient.frame = view.bounds
        view.layer.insertSublayer(gradient, at: 0)
        gradientLayer = gradient

        title = "Video Gallery"

        // Setup navigation bar with modern styling
        navigationController?.navigationBar.barStyle = .black
        navigationController?.navigationBar.tintColor = .white
        navigationController?.navigationBar.titleTextAttributes = [
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: 18, weight: .semibold)
        ]
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            style: .plain,
            target: self,
            action: #selector(dismissGallery)
        )

        // Setup collection view with modern styling
        collectionView.backgroundColor = .clear
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(VideoCell.self, forCellWithReuseIdentifier: "VideoCell")
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func loadVideos() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: nil)
            videoURLs = fileURLs.filter { $0.pathExtension == "mov" || $0.pathExtension == "mp4" }
                .sorted { url1, url2 in
                    let date1 = (try? FileManager.default.attributesOfItem(atPath: url1.path)[.creationDate] as? Date) ?? Date.distantPast
                    let date2 = (try? FileManager.default.attributesOfItem(atPath: url2.path)[.creationDate] as? Date) ?? Date.distantPast
                    return date1 > date2
                }
            collectionView.reloadData()
        } catch {
            print("Error loading videos: \(error)")
        }
    }
    
    @objc private func dismissGallery() {
        dismiss(animated: true)
    }
    
    private func playVideo(at url: URL) {
        let player = AVPlayer(url: url)
        let playerViewController = AVPlayerViewController()
        playerViewController.player = player
        present(playerViewController, animated: true) {
            player.play()
        }
    }
    
    private func shareVideo(at url: URL) {
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        present(activityVC, animated: true)
    }
    
    private func deleteVideo(at index: Int) {
        let url = videoURLs[index]
        
        let alert = UIAlertController(title: "Delete Video", message: "Are you sure you want to delete this video?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            do {
                try FileManager.default.removeItem(at: url)
                self?.videoURLs.remove(at: index)
                self?.collectionView.deleteItems(at: [IndexPath(item: index, section: 0)])
            } catch {
                print("Error deleting video: \(error)")
            }
        })
        present(alert, animated: true)
    }
}

// MARK: - UICollectionViewDataSource
extension VideoGalleryViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return videoURLs.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "VideoCell", for: indexPath) as! VideoCell
        cell.configure(with: videoURLs[indexPath.item])
        return cell
    }
}

// MARK: - UICollectionViewDelegate
extension VideoGalleryViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let url = videoURLs[indexPath.item]
        
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Play", style: .default) { [weak self] _ in
            self?.playVideo(at: url)
        })
        alert.addAction(UIAlertAction(title: "Share", style: .default) { [weak self] _ in
            self?.shareVideo(at: url)
        })
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.deleteVideo(at: indexPath.item)
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
}

// MARK: - UICollectionViewDelegateFlowLayout
extension VideoGalleryViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = (collectionView.bounds.width - 30) / 2
        return CGSize(width: width, height: width * 1.5)
    }
}

// MARK: - VideoCell
class VideoCell: UICollectionViewCell {
    private let thumbnailImageView = UIImageView()
    private let durationLabel = UILabel()
    private let nameLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        contentView.backgroundColor = .clear
        contentView.layer.cornerRadius = 16
        contentView.clipsToBounds = true

        let glassmorphismView = UIView()
        glassmorphismView.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        glassmorphismView.layer.cornerRadius = 16
        glassmorphismView.layer.borderWidth = 1
        glassmorphismView.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
        glassmorphismView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(glassmorphismView)

        thumbnailImageView.contentMode = .scaleAspectFill
        thumbnailImageView.clipsToBounds = true
        thumbnailImageView.layer.cornerRadius = 12
        thumbnailImageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(thumbnailImageView)

        durationLabel.textColor = .white
        durationLabel.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        durationLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        durationLabel.textAlignment = .center
        durationLabel.layer.cornerRadius = 8
        durationLabel.clipsToBounds = true
        durationLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(durationLabel)

        nameLabel.textColor = .white
        nameLabel.font = UIFont.systemFont(ofSize: 11, weight: .medium)
        nameLabel.numberOfLines = 2
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(nameLabel)

        NSLayoutConstraint.activate([
            glassmorphismView.topAnchor.constraint(equalTo: contentView.topAnchor),
            glassmorphismView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            glassmorphismView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            glassmorphismView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            thumbnailImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            thumbnailImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
            thumbnailImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
            thumbnailImageView.bottomAnchor.constraint(equalTo: nameLabel.topAnchor, constant: -4),
            
            durationLabel.bottomAnchor.constraint(equalTo: thumbnailImageView.bottomAnchor, constant: -8),
            durationLabel.trailingAnchor.constraint(equalTo: thumbnailImageView.trailingAnchor, constant: -8),
            durationLabel.heightAnchor.constraint(equalToConstant: 20),
            durationLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 50),
            
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            nameLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            nameLabel.heightAnchor.constraint(equalToConstant: 30)
        ])
    }
    
    func configure(with url: URL) {
        nameLabel.text = url.lastPathComponent
        
        // Generate thumbnail
        let asset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        let time = CMTime(seconds: 1, preferredTimescale: 60)
        imageGenerator.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) { [weak self] _, image, _, _, _ in
            if let image = image {
                DispatchQueue.main.async {
                    self?.thumbnailImageView.image = UIImage(cgImage: image)
                }
            }
        }
        
        // Get duration
        let duration = asset.duration
        let seconds = CMTimeGetSeconds(duration)
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        durationLabel.text = String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

