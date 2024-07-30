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
    }
    
    private func addPlayerLoadingView() {
        addChildVC(
            child: loadingViewController,
            container: videoPlayerView
        )
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
        
        if vlcPlayer.time != nil && (vlcPlayer.media != nil) {
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
