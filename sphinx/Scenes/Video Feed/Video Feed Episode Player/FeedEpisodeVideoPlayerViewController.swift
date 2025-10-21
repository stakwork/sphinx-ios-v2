//
//  FeedEpisodeVideoPlayerViewController.swift
//  sphinx
//
//  Created by Tomas Timinskas on 20/10/2025.
//  Copyright © 2025 sphinx. All rights reserved.
//

import UIKit
import AVKit
import AVFoundation
import Combine

protocol FeedEpisodeVideoPlayerDelegate: AnyObject {
    func didChangePlayingStateFor(videoID: String)
}

class FeedEpisodeVideoPlayerViewController: UIViewController, VideoFeedEpisodePlayerViewController {
    
    weak var delegate: FeedEpisodeVideoPlayerDelegate?
    
    @IBOutlet private weak var playerContainerView: UIView!
    @IBOutlet private weak var episodeTitleLabel: UILabel!
    @IBOutlet private weak var episodePublishDateLabel: UILabel!
    @IBOutlet weak var loadingWheel: UIActivityIndicatorView!
    
    var playerViewController: AVPlayerViewController?
    var player: AVPlayer?
    
    var timeObserverToken: Any?
    private var cancellables = Set<AnyCancellable>()
    
    private var processedAds: Set<Int> = []
    private var showedWarningForAds: Set<Int> = []
    
    let newMessageBubbleHelper = NewMessageBubbleHelper()

    var contentFeed: ContentFeed? = nil
    var videoPlayerEpisode: Video! {
        didSet {
            guard videoPlayerEpisode?.id != oldValue?.id else {
                return
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.updateVideoPlayer(withNewEpisode: self.videoPlayerEpisode)
                self.setupViews()
                self.processAds()
            }
        }
    }
    
    var ads: [(Int, Int)] = []
    
    var initialTimeToPlay: Double? = nil
    
    var isPlaying = false {
        didSet {
            if isPlaying != oldValue {
                delegate?.didChangePlayingStateFor(videoID: videoPlayerEpisode.videoID)
            }
            
            if isPlaying {
                contentFeed?.updateLastPlayedItem(videoPlayerEpisode.videoID)
            }
        }
    }
    
    var loading = false {
        didSet {
            LoadingWheelHelper.toggleLoadingWheel(loading: loading, loadingWheel: loadingWheel, loadingWheelColor: UIColor.white)
        }
    }
    
    static func instantiate(
        videoPlayerEpisode: Video,
        delegate: FeedEpisodeVideoPlayerDelegate?
    ) -> FeedEpisodeVideoPlayerViewController {
        
        let viewController = StoryboardScene
            .VideoFeed
            .feedEpisodeVideoPlayerViewController
            .instantiate()
        
        viewController.videoPlayerEpisode = videoPlayerEpisode
        viewController.delegate = delegate
        viewController.contentFeed = ContentFeed.getFeedById(feedId: videoPlayerEpisode.videoFeed?.feedID ?? "")
        
        return viewController
    }
    
    func togglePlayVideo() {
        if isPlaying {
            player?.pause()
        } else {
            player?.play()
        }
    }
    
    func observePlayerStateWithCombine() {
        guard let player = player else { return }
        
        // Observe timeControlStatus
        player.publisher(for: \.timeControlStatus)
            .sink { [weak self] status in
                switch status {
                case .playing:
                    self?.onPlayerStartedPlaying()
                case .paused:
                    self?.onPlayerPaused()
                case .waitingToPlayAtSpecifiedRate:
                    self?.onPlayerBuffering()
                @unknown default:
                    self?.loading = false
                    break
                }
            }
            .store(in: &cancellables)
        
        // Observe rate changes
        player.publisher(for: \.rate)
            .removeDuplicates()
            .sink { [weak self] rate in
                print("Rate changed to: \(rate)x")
                if rate > 0 {
                    self?.onPlayerStartedPlaying()
                } else {
                    self?.onPlayerPaused()
                }
            }
            .store(in: &cancellables)
    }
    
    func onPlayerStartedPlaying() {
        loading = false
        isPlaying = true
    }
    
    func onPlayerPaused() {
        loading = false
        isPlaying = false
    }
    
    func onPlayerBuffering() {
        loading = true
        isPlaying = true
    }
    
    func isPlayingVideo(with videoID: String) -> Bool {
        return videoID == videoPlayerEpisode.videoID && isPlaying
    }

    private func setupViews() {
        episodeTitleLabel.text = videoPlayerEpisode.titleForDisplay
        episodePublishDateLabel.text = videoPlayerEpisode.publishDateText
    }
    
    private func processAds() {
        let chapters = (videoPlayerEpisode.chapters ?? [])
        
        for (index, chapter) in (videoPlayerEpisode.chapters ?? []).enumerated() {
            if chapter.isAd {
                let nextChapter = chapters.count > index + 1 ? chapters[index + 1] : nil
                ads.append((chapter.timestamp.toSeconds(), nextChapter?.timestamp.toSeconds() ?? 0))
            }
        }
    }
    
    private func addTimeObserver() {
        // Check every 0.5 seconds
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        
        timeObserverToken = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            
            let currentSeconds = CMTimeGetSeconds(time)
            
            // Check for upcoming ads and skip current ads
            self.checkForAds(at: currentSeconds)
        }
    }
    
    func checkForAds(at currentTime: Double) {
        if !(videoPlayerEpisode.videoFeed?.skipAds ?? false) {
            return
        }
        
        for (index, ad) in ads.enumerated() {
            
            let timeUntilAd = Double(ad.0) - currentTime
            
            if timeUntilAd > 0 && timeUntilAd <= 3.0 && !showedWarningForAds.contains(index) {
                showedWarningForAds.insert(index)
                showAdWarningToast(secondsUntil: timeUntilAd)
            }
            
            if currentTime >= Double(ad.0) && (currentTime < Double(ad.1) || ad.1 == 0) && !processedAds.contains(index) {
                processedAds.insert(index)
                skipAd(ad, at: index)
            }
            
            if currentTime < Double(ad.0) {
                processedAds.remove(index)
                showedWarningForAds.remove(index)
            }
        }
    }
    
    func skipAd(_ ad: (Int, Int), at index: Int) {
        showAdSkippedToast(ad: ad)
        
        seekToTime(Double(ad.1))
    }
    
    // MARK: - Toast Messages
    func showAdWarningToast(secondsUntil: Double) {
        let message = String(format: "Ad starting in %.0f seconds...", secondsUntil)
        showToast(message: message)
    }
    
    func showAdSkippedToast(ad: (Int, Int)) {
        let duration = Int(ad.1 - ad.0)
        let message = "Skipped \(duration) sseconds ad"
        showToast(message: message)
    }
    
    private func showToast(message: String) {
        self.newMessageBubbleHelper.showGenericMessageView(
            text: message,
            delay: 3,
            textColor: UIColor.white,
            backColor: UIColor.Sphinx.PrimaryGreen,
            backAlpha: 1.0
        )
    }
    
    private func updateVideoPlayer(withNewEpisode video: Video) {
        guard let mediaURL = video.downloadedVideoUrl ?? video.mediaURL else {
            return
        }
        
        if let existingPlayer = player {
            existingPlayer.pause()
            
            let newItem = AVPlayerItem(url: mediaURL)
            existingPlayer.replaceCurrentItem(with: newItem)
            
            if let initialTimeToPlay = initialTimeToPlay {
                let targetTime = CMTime(seconds: initialTimeToPlay, preferredTimescale: 600)
                
                existingPlayer.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero) { finished in
                    if finished {
                        existingPlayer.play()
                    }
                }
                
                self.initialTimeToPlay = nil
            } else {
                existingPlayer.play()
            }
        } else {
            setupNewPlayer(with: mediaURL)
        }
    }
    
    private func setupNewPlayer(with url: URL) {
        let newPlayer = AVPlayer(url: url)
        self.player = newPlayer
        
        if playerViewController == nil {
            let playerVC = AVPlayerViewController()
            playerVC.player = newPlayer
            
            addChild(playerVC)
            playerContainerView.addSubview(playerVC.view)
            
            playerVC.view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                playerVC.view.topAnchor.constraint(equalTo: playerContainerView.topAnchor),
                playerVC.view.leadingAnchor.constraint(equalTo: playerContainerView.leadingAnchor),
                playerVC.view.trailingAnchor.constraint(equalTo: playerContainerView.trailingAnchor),
                playerVC.view.bottomAnchor.constraint(equalTo: playerContainerView.bottomAnchor)
            ])
            
            playerVC.didMove(toParent: self)
            self.playerViewController = playerVC
        } else {
            playerViewController?.player = newPlayer
        }
        
        addTimeObserver()
        observePlayerStateWithCombine()
        
        if let initialTimeToPlay = initialTimeToPlay {
            let targetTime = CMTime(seconds: initialTimeToPlay, preferredTimescale: 600)
            
            newPlayer.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero) { finished in
                if finished {
                    newPlayer.play()
                }
            }
            
            self.initialTimeToPlay = nil
        } else {
            newPlayer.play()
        }
    }
    
    func seekToTime(_ seconds: Double) {
        guard let player = player else {
            return
        }
        
        if let duration = player.currentItem?.duration {
            let durationSeconds = CMTimeGetSeconds(duration)
            
            guard !durationSeconds.isNaN && seconds <= durationSeconds else {
                return
            }
        }
        
        let targetTime = CMTime(seconds: seconds, preferredTimescale: 600)
        
        player.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] finished in
            guard finished else { return }
            
            if seconds > 0 {
                self?.player?.play()
            } else {
                self?.player?.pause()
            }
        }
    }
    
    // MARK: - Cleanup
    private func cleanupPlayer() {
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
        
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
        
        playerViewController?.player = nil
        playerViewController?.view.removeFromSuperview()
        playerViewController?.removeFromParent()
        playerViewController = nil
        
        cancellables.forEach {
            $0.cancel()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        player?.pause()
    }
    
    deinit {
        cleanupPlayer()
    }
}
