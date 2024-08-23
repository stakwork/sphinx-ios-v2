// FeedSearchEmptyStateViewController.swift
//
// Created by CypherPoet.
// ✌️
//
    

import UIKit


class FeedSearchEmptyStateViewController: UIViewController {
    
    @IBOutlet weak var searchPlaceholderImage: UIImageView!
    @IBOutlet weak var searchPlaceholder1: UILabel!
    @IBOutlet weak var searchPlaceholder2: UILabel!
    @IBOutlet weak var searchPlaceholder3: UILabel!
    
    var feedType: FeedType? = nil
    var feedSource:FeedSource = .RSS
}
    

// MARK: -  Static Members
extension FeedSearchEmptyStateViewController {
    
    static func instantiate() -> FeedSearchEmptyStateViewController {
        let viewController = StoryboardScene
            .Dashboard
            .FeedSearchEmptyStateViewController
            .instantiate()

        return viewController
    }
}


// MARK: -  Lifecycle
extension FeedSearchEmptyStateViewController {
    
    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        
        configureStartingEmptyStateView()
    }
    
    func configureStartingEmptyStateView() {
        searchPlaceholder1.text = "feed.search-over".localized
        
        switch(feedType) {
        case .Podcast:
            searchPlaceholderImage.isHidden = false
            searchPlaceholderImage.image = UIImage(named: "podcastIndexLogo")
            let isTorrentSource = (feedSource == .BitTorrent)
            searchPlaceholder2.text = (isTorrentSource) ? "feed.search-tracks-quantity".localized : "feed.search-podcast-quantity".localized
            searchPlaceholder3.text = (isTorrentSource) ? "feed.search-torrent-source".localized : "feed.search-podcast-source".localized
            break
        case .Video:
            searchPlaceholderImage.isHidden = false
            searchPlaceholderImage.image = UIImage(named: "videoPlaceholder")
            
            searchPlaceholder2.text = "feed.search-video-quantity".localized
            searchPlaceholder3.text = "feed.search-video-source".localized
            break
        default:
            searchPlaceholderImage.isHidden = true
            
            //@BTRefactor: make this conditional based on rss vs bt
            if(feedSource == .BitTorrent){
                searchPlaceholder2.text = "feed.search-other-source-bittorrent".localized
            }
            else if(feedSource == .RSS){
                searchPlaceholder2.text = "feed.search-other-source-rss".localized
            }
            
            searchPlaceholder3.text = ""
            break
        }
    }

}
