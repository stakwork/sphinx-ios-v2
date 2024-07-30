import UIKit
import MobileVLCKit

class GeneralVideoFeedEpisodePlayerViewController: UIViewController, VideoFeedEpisodePlayerViewController {
    @IBOutlet private weak var videoPlayerView: UIView!
    @IBOutlet private weak var episodeTitleLabel: UILabel!
    @IBOutlet private weak var episodeViewCountLabel: UILabel!
    @IBOutlet private weak var episodeSubtitleCircularDivider: UIView!
    @IBOutlet private weak var episodePublishDateLabel: UILabel!
    
    private var contentReadyTimer: Timer?
    private var contentReadyAttempts = 0
    private let maxContentReadyAttempts = 100
    
    private lazy var vlcPlayer: VLCMediaPlayer = {
        let player = VLCMediaPlayer()
        player.delegate = self
        return player
    }()
    private lazy var loadingViewController = LoadingViewController()
    
    private lazy var controlsView: PlayerControlsView = {
        let controls = PlayerControlsView()
        controls.isUserInteractionEnabled = true
        controls.playPauseButton.addTarget(self, action: #selector(playPauseTapped), for: .touchUpInside)
        controls.rewindButton.addTarget(self, action: #selector(rewindTapped), for: .touchUpInside)
        controls.forwardButton.addTarget(self, action: #selector(forwardTapped), for: .touchUpInside)
        controls.layer.zPosition = 1
        controls.translatesAutoresizingMaskIntoConstraints = false
        return controls
    }()
    
    var videoPlayerEpisode: Video! {
        didSet {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.updateVideoPlayer(withNewEpisode: self.videoPlayerEpisode)
            }
        }
    }
}


// MARK: -  Static Methods
extension GeneralVideoFeedEpisodePlayerViewController {
    
    static func instantiate(
        videoPlayerEpisode: Video
    ) -> GeneralVideoFeedEpisodePlayerViewController {
        let viewController = StoryboardScene
            .VideoFeed
            .generalVideoFeedEpisodePlayerViewController
            .instantiate()
        
        viewController.videoPlayerEpisode = videoPlayerEpisode
        
        return viewController
    }
}


// MARK: -  Lifecycle
extension GeneralVideoFeedEpisodePlayerViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        contentReadyTimer?.invalidate()
        contentReadyTimer = nil
        
        vlcPlayer.stop()
    }
}


// MARK: -  Private Helpers
extension GeneralVideoFeedEpisodePlayerViewController {
    
    private func setupViews() {
        episodeSubtitleCircularDivider.makeCircular()
        
        episodeTitleLabel.text = videoPlayerEpisode.titleForDisplay
        episodeViewCountLabel.text = "\(Int.random(in: 100...999)) Views"
        episodePublishDateLabel.text = videoPlayerEpisode.publishDateText
        
        view.addSubview(controlsView)
        NSLayoutConstraint.activate([
            controlsView.leadingAnchor.constraint(equalTo: videoPlayerView.leadingAnchor),
            controlsView.trailingAnchor.constraint(equalTo: videoPlayerView.trailingAnchor),
            controlsView.topAnchor.constraint(equalTo: videoPlayerView.topAnchor),
            controlsView.bottomAnchor.constraint(equalTo: videoPlayerView.bottomAnchor)
        ])
    }
    
    private func updateVideoPlayer(withNewEpisode video: Video) {
        guard let mediaURL = video.mediaURL else { return }
        
        vlcPlayer.stop()
        addPlayerLoadingView()
        
        let media = VLCMedia(url: mediaURL)
        vlcPlayer.media = media
        vlcPlayer.drawable = videoPlayerView
        vlcPlayer.play()
        
        episodeTitleLabel.text = videoPlayerEpisode.titleForDisplay
        episodeViewCountLabel.text = "\(Int.random(in: 100...999)) Views"
        episodePublishDateLabel.text = videoPlayerEpisode.publishDateText
        
        view.bringSubviewToFront(controlsView) // Ensure controls are on top
    }
    
    private func addPlayerLoadingView() {
        addChildVC(
            child: loadingViewController,
            container: videoPlayerView
        )
        view.bringSubviewToFront(controlsView) // Ensure controls are on top
    }
    
    private func removePlayerLoadingView() {
        removeChildVC(child: loadingViewController)
    }
    
    private func addPlayerErrorView() {
        // TODO: Implement error view handling
    }
    
    private func removePlayerErrorView() {
        // TODO: Implement error view handling
    }
    
    @objc private func playPauseTapped() {
        if vlcPlayer.isPlaying {
            vlcPlayer.pause()
        } else {
            vlcPlayer.play()
        }
        view.bringSubviewToFront(controlsView) // Ensure controls are on top
    }
    
    @objc private func rewindTapped() {
        vlcPlayer.jumpBackward(10)
        view.bringSubviewToFront(controlsView) // Ensure controls are on top
    }
    
    @objc private func forwardTapped() {
        vlcPlayer.jumpForward(10)
        view.bringSubviewToFront(controlsView) // Ensure controls are on top
    }
    
    private func startContentReadyTimer() {
        contentReadyAttempts = 0
        contentReadyTimer?.invalidate()
        contentReadyTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkIfContentIsReady()
        }
    }
    
    private func checkIfContentIsReady() {
        guard vlcPlayer.isPlaying else { return }
        
        contentReadyAttempts += 1
        
        if vlcPlayer.time != nil && vlcPlayer.media != nil {
            startPlayingVideo()
        } else if contentReadyAttempts >= maxContentReadyAttempts {
            handleContentReadyTimeout()
        }
    }
    
    private func startPlayingVideo() {
        contentReadyTimer?.invalidate()
        contentReadyTimer = nil
        
        DispatchQueue.main.async { [weak self] in
            self?.removePlayerLoadingView()
            self?.view.bringSubviewToFront(self?.controlsView ?? UIView()) // Ensure controls are on top
        }
    }
    
    private func handleContentReadyTimeout() {
        contentReadyTimer?.invalidate()
        contentReadyTimer = nil
        
        DispatchQueue.main.async { [weak self] in
            self?.removePlayerLoadingView()
            self?.addPlayerErrorView()
            // You might want to show an error message to the user here
        }
    }
}


// MARK: -  VLCMediaPlayerDelegate
extension GeneralVideoFeedEpisodePlayerViewController: VLCMediaPlayerDelegate {
    
    func mediaPlayerStateChanged(_ aNotification: Notification) {
        if vlcPlayer.state == .error {
            handleContentReadyTimeout()
        } else if vlcPlayer.state == .playing {
            startPlayingVideo()
        }
    }
}


import UIKit

class PlayerControlsView: UIView {
    var playPauseButton: UIButton!
    var rewindButton: UIButton!
    var forwardButton: UIButton!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }
    
    private func setupViews() {
        isUserInteractionEnabled = true
        
        playPauseButton = UIButton(type: .system)
        playPauseButton.setTitle("Play/Pause", for: .normal)
        playPauseButton.translatesAutoresizingMaskIntoConstraints = false
        playPauseButton.isUserInteractionEnabled = true
        
        rewindButton = UIButton(type: .system)
        rewindButton.setTitle("<<", for: .normal)
        rewindButton.translatesAutoresizingMaskIntoConstraints = false
        rewindButton.isUserInteractionEnabled = true
        
        forwardButton = UIButton(type: .system)
        forwardButton.setTitle(">>", for: .normal)
        forwardButton.translatesAutoresizingMaskIntoConstraints = false
        forwardButton.isUserInteractionEnabled = true
        
        addSubview(playPauseButton)
        addSubview(rewindButton)
        addSubview(forwardButton)
        
        NSLayoutConstraint.activate([
            playPauseButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            playPauseButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20),
            
            rewindButton.trailingAnchor.constraint(equalTo: playPauseButton.leadingAnchor, constant: -20),
            rewindButton.centerYAnchor.constraint(equalTo: playPauseButton.centerYAnchor),
            
            forwardButton.leadingAnchor.constraint(equalTo: playPauseButton.trailingAnchor, constant: 20),
            forwardButton.centerYAnchor.constraint(equalTo: playPauseButton.centerYAnchor),
        ])
    }
}
