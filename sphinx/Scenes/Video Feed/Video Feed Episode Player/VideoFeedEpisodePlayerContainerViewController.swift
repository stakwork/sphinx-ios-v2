// VideoFeedEpisodePlayerContainerViewController.swift
//
// Created by CypherPoet.
// ✌️
//
    

import UIKit
import CoreData

protocol VideoFeedEpisodePlayerViewControllerDelegate: AnyObject {
    
    func viewController(
        _ viewController: UIViewController,
        didSelectVideoFeedWithID videoFeedID: String
    )
    
    func viewController(
        _ viewController: UIViewController,
        didSelectVideoEpisodeWithID videoEpisodeID: String
    )
    
    func viewControllerShouldDismiss(
        _ viewController: UIViewController
    )
}


protocol VideoFeedEpisodePlayerViewController: UIViewController {
    var videoPlayerEpisode: Video! { get set }
}


class VideoFeedEpisodePlayerContainerViewController: UIViewController {
    
    @IBOutlet weak var playerViewContainer: UIView!
    @IBOutlet weak var collectionViewContainer: UIView!
    
    internal var managedObjectContext: NSManagedObjectContext!
    
    var deeplinkedTimestamp : Int? = nil
    
    var videoPlayerEpisode: Video! {
        didSet {
            DispatchQueue.main.async { [weak self] in
                guard
                    let self = self,
                    let videoPlayerEpisode = self.videoPlayerEpisode
                else { return }
                
                self.collectionViewController
                    .updateWithNew(
                        videoPlayerEpisode: videoPlayerEpisode,
                        shouldAnimate: true
                    )
            }
        }
    }
    
    
    var dismissButtonStyle: ModalDismissButtonStyle!

    weak var delegate: VideoFeedEpisodePlayerViewControllerDelegate?
    weak var boostDelegate: CustomBoostDelegate?

    lazy var youtubeVideoPlayerViewController: YouTubeVideoFeedEpisodePlayerViewController = {
        YouTubeVideoFeedEpisodePlayerViewController.instantiate(
            videoPlayerEpisode: videoPlayerEpisode,
            delegate: self,
            dismissButtonStyle: dismissButtonStyle,
            onDismiss: { self.delegate?.viewControllerShouldDismiss(self) }
        )
    }()
    
    internal lazy var generalVideoPlayerViewController: FeedEpisodeVideoPlayerViewController = {
        FeedEpisodeVideoPlayerViewController.instantiate(
            videoPlayerEpisode: videoPlayerEpisode,
            delegate: self
        )
    }()
    
    
    internal lazy var collectionViewController: VideoFeedEpisodePlayerCollectionViewController = {
        let vc = VideoFeedEpisodePlayerCollectionViewController.instantiate(
            videoPlayerEpisode: videoPlayerEpisode,
            videoFeedEpisodes: videoFeedEpisodes,
            boostDelegate: boostDelegate,
            onVideoEpisodeCellSelected: handleVideoEpisodeCellSelection(_:),
            onVideoChapterSelected: handleVideoChapterSelection(_:timeInSeconds:)
        )
        vc.delegate = self
        return vc
    }()
    
}


// MARK: -  Static Methods
extension VideoFeedEpisodePlayerContainerViewController {
    
    static func instantiate(
        videoPlayerEpisode: Video,
        dismissButtonStyle: ModalDismissButtonStyle,
        delegate: VideoFeedEpisodePlayerViewControllerDelegate,
        boostDelegate: CustomBoostDelegate,
        managedObjectContext: NSManagedObjectContext = CoreDataManager.sharedManager.persistentContainer.viewContext
    ) -> VideoFeedEpisodePlayerContainerViewController {
        let viewController = StoryboardScene
            .VideoFeed
            .videoFeedEpisodePlayerContainerViewController
            .instantiate()
        
        viewController.videoPlayerEpisode = videoPlayerEpisode
        viewController.dismissButtonStyle = dismissButtonStyle
        viewController.delegate = delegate
        viewController.boostDelegate = boostDelegate
        viewController.managedObjectContext = managedObjectContext
        
        return viewController
    }
}


// MARK: -  Lifecycle
extension VideoFeedEpisodePlayerContainerViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configurePlayerView()
        configureCollectionView()
        
        updateFeed()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5, execute: {
            if let _ = self.deeplinkedTimestamp{
                self.youtubeVideoPlayerViewController.startPlay()
            }
        })
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0, execute: {
            if let timestamp = self.deeplinkedTimestamp{
                self.youtubeVideoPlayerViewController.seekTo(time: timestamp)
            }
        })
        
        NotificationCenter.default.removeObserver(self, name: .refreshFeedDataAndUI, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(refreshFeedInfo), name: .refreshFeedDataAndUI, object: nil)
    }
    
    @objc func refreshFeedInfo() {
        let videoId = videoPlayerEpisode.id
        
        if let feedId = videoPlayerEpisode.videoFeed?.feedID, let feed = ContentFeed.getFeedById(feedId: feedId) {
            let videoFeed = VideoFeed.convertFrom(contentFeed: feed)
            self.videoPlayerEpisode = videoFeed.videosArray.first(where: { $0.id == videoId })
            
            if let downloadedVideoUrl = videoPlayerEpisode.downloadedVideoUrl, downloadedVideoUrl.absoluteString.isNotEmpty {
                configurePlayerView()
                
                collectionViewController.refreshVideos()
                collectionViewController.refreshCellForVideo(video: videoPlayerEpisode)
                
                currentVideoPlayerViewController.videoPlayerEpisode = videoPlayerEpisode
            }
        }
    }
}


// MARK: -  Computeds
extension VideoFeedEpisodePlayerContainerViewController {
    
    private var videoFeedEpisodes: [Video] {
        videoPlayerEpisode.videoFeed?.videosArray ?? []
    }
    
    private var isVideoFromYouTubeFeed: Bool {
        if videoPlayerEpisode.downloadedVideoUrl != nil {
            return false
        }
        
        guard let videoFeed = videoPlayerEpisode.videoFeed else { return false }
        
        return videoFeed.isYouTubeFeed
    }
    
    private var currentVideoPlayerViewController: VideoFeedEpisodePlayerViewController {
        isVideoFromYouTubeFeed ?
            youtubeVideoPlayerViewController
            : generalVideoPlayerViewController
    }
}


// MARK: -  Private Helpers
extension VideoFeedEpisodePlayerContainerViewController {
    
    private func configurePlayerView() {
        for vc in self.children {
            if !vc.isKind(of: VideoFeedEpisodePlayerCollectionViewController.self) {
                removeChildVC(child: vc)
            }
        }
        
        addChildVC(
            child: currentVideoPlayerViewController,
            container: playerViewContainer
        )
    }

    private func configureCollectionView() {
        for vc in self.children {
            if vc.isKind(of: VideoFeedEpisodePlayerCollectionViewController.self) {
                removeChildVC(child: vc)
            }
        }
        
        addChildVC(
            child: collectionViewController,
            container: collectionViewContainer
        )
    }
}


// MARK: -  Action Handling
extension VideoFeedEpisodePlayerContainerViewController {
    
    private func handleVideoEpisodeCellSelection(
        _ feeditemId: String
    ) {
        handleVideoEpisodeCellSelection(
            feeditemId,
            initialTimeToPlay: nil
        )
    }
    
    private func handleVideoEpisodeCellSelection(
        _ feeditemId: String,
        initialTimeToPlay: Double? = nil
    ) {
        guard
            let selectedFeedItem = ContentFeedItem.getItemWith(itemID: feeditemId)
        else {
            return
        }
        
        if let contentFeed = selectedFeedItem.contentFeed {
            
            let videoFeed = VideoFeed.convertFrom(contentFeed:  contentFeed)
            let selectedEpisode = Video.convertFrom(contentFeedItem: selectedFeedItem, videoFeed: videoFeed)
            
            if selectedEpisode.videoID != videoPlayerEpisode.videoID {
                videoPlayerEpisode = selectedEpisode
                
                configurePlayerView()
                
                (currentVideoPlayerViewController as? FeedEpisodeVideoPlayerViewController)?.initialTimeToPlay = initialTimeToPlay
                currentVideoPlayerViewController.videoPlayerEpisode = videoPlayerEpisode
                
                delegate?.viewController(
                    self,
                    didSelectVideoEpisodeWithID: feeditemId
                )
            } else {
                (currentVideoPlayerViewController as? FeedEpisodeVideoPlayerViewController)?.togglePlayVideo()
                (currentVideoPlayerViewController as? YouTubeVideoFeedEpisodePlayerViewController)?.togglePlayVideo()
            }
        }
    }
    
    private func handleVideoChapterSelection(
        _ feeditemId: String,
        timeInSeconds: Int
    ) {
        guard
            let _ = ContentFeedItem.getItemWith(itemID: feeditemId)
        else {
            return
        }
        
        if let genericPlayerVC = currentVideoPlayerViewController as? FeedEpisodeVideoPlayerViewController {
            if feeditemId == genericPlayerVC.videoPlayerEpisode.videoID {
                genericPlayerVC.seekToTime(Double(timeInSeconds))
                return
            }
        }
        handleVideoEpisodeCellSelection(feeditemId, initialTimeToPlay: Double(timeInSeconds))
    }
    
    
    private func updateFeed() {
        if  let videoFeed = self.videoPlayerEpisode?.videoFeed,
            let feedUrl = videoFeed.feedURL?.absoluteString {
            
            FeedsManager.sharedInstance.fetchItemsFor(feedUrl: feedUrl, feedId: videoFeed.id)
        }
    }
}

extension VideoFeedEpisodePlayerContainerViewController: VideoFeedEpisodePlayerCollectionViewControllerDelegate{
    func requestPlay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.25, execute: {
            self.youtubeVideoPlayerViewController.startPlay()
        })
    }
    
    func isPlayingVideo(with videoID: String) -> Bool {
        if let genericPlayerVC = currentVideoPlayerViewController as? FeedEpisodeVideoPlayerViewController {
            return genericPlayerVC.isPlayingVideo(with: videoID)
        } else if let youtubePlayerVC = currentVideoPlayerViewController as? YouTubeVideoFeedEpisodePlayerViewController {
            return youtubePlayerVC.isPlayingVideo(with: videoID)
        }
        return false
    }
}

extension VideoFeedEpisodePlayerContainerViewController : FeedEpisodeVideoPlayerDelegate {
    func didChangePlayingStateFor(videoID: String) {
        if let video = videoFeedEpisodes.first(where: { $0.videoID == videoID }) {
            self.collectionViewController.refreshCellForVideo(video: video)
        }
    }
}
