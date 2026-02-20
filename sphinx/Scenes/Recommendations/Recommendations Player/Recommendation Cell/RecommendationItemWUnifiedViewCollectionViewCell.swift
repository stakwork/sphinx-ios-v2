//
//  RecommendationItemWUnifiedViewCollectionViewCell.swift
//  sphinx
//
//  Created by James Carucci on 3/6/23.
//  Copyright © 2023 sphinx. All rights reserved.
//

import UIKit

class RecommendationItemWUnifiedViewCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var unifiedEpisodeView: NewUnifiedEpisodeView!
    @IBOutlet weak var unifiedEpisodeViewHeightConstraint: NSLayoutConstraint!
    
    weak var delegate : FeedItemRowDelegate?
    
    let kViewHeight: CGFloat = 200
    let kChapterHeight: CGFloat = 40
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }

    func configure(
        withItem item: PodcastEpisode,
        andDelegate delegate: FeedItemRowDelegate,
        isPlaying: Bool
    ) {
        if let feedID = item.feedID, let contentFeed = ContentFeed.getFeedById(feedId: feedID) {
            self.delegate = delegate
            
            unifiedEpisodeView.configureWith(
                podcast: PodcastFeed.convertFrom(contentFeed: contentFeed),
                and: item,
                download: nil,
                delegate: self,
                isLastRow: false,
                playing: isPlaying
            )
        }
    }
    
    func configure(
        withVideoEpisode videoEpisode: Video,
        expanded: Bool = false,
        playing: Bool,
        and delegate: FeedItemRowDelegate
    ) {
        self.delegate = delegate
        
        unifiedEpisodeView.configure(
            withVideoEpisode: videoEpisode,
            download: nil,
            expanded: expanded,
            playing: playing,
            and: self
        )
        
        if expanded {
            unifiedEpisodeViewHeightConstraint.constant = kViewHeight + (CGFloat((videoEpisode.chapters?.count ?? 0)) * kChapterHeight)
        } else {
            unifiedEpisodeViewHeightConstraint.constant = kViewHeight
        }
        
        unifiedEpisodeView.layoutIfNeeded()
    }
    
}

extension RecommendationItemWUnifiedViewCollectionViewCell : PodcastEpisodeRowDelegate {
    func shouldToggleChapters(episode: PodcastEpisode) {}
    
    func shouldPlayChapterWith(index: Int, on episode: PodcastEpisode) {}
    
    func shouldShowDescription(episode: PodcastEpisode) {
        delegate?.shouldShowDescription(episode: episode,cell:UITableViewCell())
    }
    func shouldStartDownloading(episode: PodcastEpisode) {
        delegate?.shouldStartDownloading(episode: episode, cell: self)
    }
    
    func shouldDeleteFile(episode: PodcastEpisode) {
        delegate?.shouldDeleteFile(episode: episode, cell: self)
    }
    
    func shouldShowMore(episode: PodcastEpisode) {
        delegate?.shouldShowMore(episode: episode, cell: self)
    }
    
    func shouldShare(episode: PodcastEpisode) {
        delegate?.shouldShare(episode: episode)
    }
}

extension RecommendationItemWUnifiedViewCollectionViewCell : VideoRowDelegate {
    func shouldToggleChapters(video: Video) {
        delegate?.shouldToggleChapters(video: video, cell: self)
    }
    
    func shouldPlayChapterWith(index: Int, on video: Video) {
        delegate?.shouldPlayChapterWith(index: index, on: video)
    }
    
    func shouldStartDownloading(video: Video) {
        if let delegate = delegate as? VideoFeedEpisodePlayerCollectionViewController{
            delegate.shouldDownloadVideo(video: video)
        }
    }
    
    func shouldShowDescription(video: Video) {
        delegate?.shouldShowDescription(video: video)
    }
    
    func shouldShowMore(video: Video) {
        delegate?.shouldShowMore(video: video, cell: self)
    }
    
    func shouldShare(video: Video) {
        delegate?.shouldShare(video: video)
    }
    
}

// MARK: - Static Properties
extension RecommendationItemWUnifiedViewCollectionViewCell {
    
    static let reuseID = "RecommendationItemWUnifiedViewCollectionViewCell"
    
    static let nib: UINib = .init(
        nibName: "RecommendationItemWUnifiedViewCollectionViewCell",
        bundle: nil
    )
}
