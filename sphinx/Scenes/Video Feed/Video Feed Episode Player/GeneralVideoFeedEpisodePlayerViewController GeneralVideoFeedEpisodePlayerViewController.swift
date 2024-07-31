import UIKit
import MobileVLCKit

class GeneralVideoFeedEpisodePlayerViewController: UIViewController, VideoFeedEpisodePlayerViewController {
    @IBOutlet private weak var videoPlayerView: UIView!
    @IBOutlet private weak var episodeTitleLabel: UILabel!
    @IBOutlet private weak var episodeViewCountLabel: UILabel!
    @IBOutlet private weak var episodeSubtitleCircularDivider: UIView!
    @IBOutlet private weak var episodePublishDateLabel: UILabel!
    
    @IBOutlet private weak var playerControlsViewTogglePlayButton: UIButton!
    @IBOutlet private weak var controlsView: UIView!
    
    @IBOutlet weak var playerControlsViewForwardButton: UIButton!
    @IBOutlet weak var playerControlsViewReverseButton: UIButton!
    
    private var contentReadyTimer: Timer?
    private var contentReadyAttempts = 0
    private let maxContentReadyAttempts = 100
    private var controlsHideTimer: Timer?
    private let controlsHideTimeout: TimeInterval = 3.0
    
    private lazy var vlcPlayer: VLCMediaPlayer = {
        let player = VLCMediaPlayer()
        player.delegate = self
        return player
    }()
    private lazy var loadingViewController = LoadingViewController()
    
    var videoPlayerEpisode: Video! {
        didSet {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.updateVideoPlayer(withNewEpisode: self.videoPlayerEpisode)
            }
        }
    }
    
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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        setupPlayerControls()
        startControlsHideTimer()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        contentReadyTimer?.invalidate()
        contentReadyTimer = nil
        controlsHideTimer?.invalidate()
        controlsHideTimer = nil
        
        vlcPlayer.stop()
    }
    
    func setupPlayerControls() {
        self.playerControlsViewTogglePlayButton.setTitle("pause", for: .normal)
        self.playerControlsViewTogglePlayButton.addTarget(self, action: #selector(self.playPauseTapped), for: .touchUpInside)
        self.playerControlsViewForwardButton.addTarget(self, action: #selector(self.forwardTapped), for: .touchUpInside)
        self.playerControlsViewReverseButton.addTarget(self, action: #selector(self.rewindTapped), for: .touchUpInside)
        self.playerControlsViewTogglePlayButton.layer.zPosition = 1000
        self.playerControlsViewTogglePlayButton.isUserInteractionEnabled = true
        self.view.bringSubviewToFront(self.playerControlsViewTogglePlayButton)
        self.view.bringSubviewToFront(self.playerControlsViewForwardButton)
        self.view.bringSubviewToFront(self.playerControlsViewReverseButton)
        self.controlsView.layer.zPosition = 1
    }
    
    private func setupViews() {
        episodeSubtitleCircularDivider.makeCircular()
        
        episodeTitleLabel.text = videoPlayerEpisode.titleForDisplay
        episodeViewCountLabel.text = "\(Int.random(in: 100...999)) Views"
        episodePublishDateLabel.text = videoPlayerEpisode.publishDateText
        
        view.addSubview(controlsView)
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
        var titleLabel: String? = nil
        if vlcPlayer.isPlaying {
            vlcPlayer.pause()
            titleLabel = "play_arrow"
        } else {
            vlcPlayer.play()
            titleLabel = "pause"
        }
        view.bringSubviewToFront(controlsView) // Ensure controls are on top
        if let titleLabel = titleLabel {
            playerControlsViewTogglePlayButton.setTitle(titleLabel, for: .normal)
        }
        resetControlsHideTimer()
    }
    
    @objc private func rewindTapped() {
        vlcPlayer.jumpBackward(10)
        view.bringSubviewToFront(controlsView) // Ensure controls are on top
        resetControlsHideTimer()
    }
    
    @objc private func forwardTapped() {
        vlcPlayer.jumpForward(10)
        view.bringSubviewToFront(controlsView) // Ensure controls are on top
        resetControlsHideTimer()
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
    
    private func startControlsHideTimer() {
        controlsHideTimer?.invalidate()
        controlsHideTimer = Timer.scheduledTimer(timeInterval: controlsHideTimeout, target: self, selector: #selector(hideControls), userInfo: nil, repeats: false)
    }
    
    private func resetControlsHideTimer() {
        controlsView.alpha = 1.0
        playerControlsViewTogglePlayButton.alpha = 1.0
        playerControlsViewForwardButton.alpha = 1.0
        playerControlsViewReverseButton.alpha = 1.0
        startControlsHideTimer()
    }
    
    @objc private func hideControls() {
        UIView.animate(withDuration: 0.5) {
            self.controlsView.alpha = 0.05
            self.playerControlsViewTogglePlayButton.alpha = 0.05
            self.playerControlsViewForwardButton.alpha = 0.05
            self.playerControlsViewReverseButton.alpha = 0.05
        }
    }
    
    private func setupTapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(showControls))
        view.addGestureRecognizer(tapGesture)
    }
    
    @objc private func showControls() {
        UIView.animate(withDuration: 0.5) {
            self.controlsView.alpha = 1.0
            self.playerControlsViewTogglePlayButton.alpha = 1.0
            self.playerControlsViewForwardButton.alpha = 1.0
            self.playerControlsViewReverseButton.alpha = 1.0
        }
        resetControlsHideTimer()
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

