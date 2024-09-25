// ContentFeedKind.swift
//
// Created by CypherPoet.
// ✌️
//
    
import Foundation

public enum FeedSource: Int16{
    case BitTorrent
    case RSS
}

public enum FeedType: Int16 {
    case Podcast
    case Video
    case Newsletter
    case Album
    case Track
    case SearchTorrent
    case BrowseTorrent
}

public enum OldFeedType: Int16 {
    case Podcast
    case Video
    case Newsletter
}

public struct FeedContentType {
    
    let id: Int16
    var description: String
    
    static var podcast: Self = .init(
        id: FeedType.Podcast.rawValue,
        description: "Podcast"
    )
    static var video: Self = .init(
        id: FeedType.Video.rawValue,
        description: "Video"
    )
    static var newsletter: Self = .init(
        id: FeedType.Newsletter.rawValue,
        description: "Newsletter"
    )
    
    static var allCases: [Self] {
        [
            .podcast,
            .video,
            .newsletter,
        ]
    }
    
    static var defaultValue: Self {
        .podcast
    }
    
    var isPodcast: Bool {
        return self.id == FeedType.Podcast.rawValue
    }
    
    var isVideo: Bool {
        return self.id == FeedType.Video.rawValue
    }
    
    var isNewsletter: Bool {
        return self.id == FeedType.Newsletter.rawValue
    }
    
    static func getFeedTypeFrom(oldFeedType: OldFeedType) -> FeedType {
        switch (oldFeedType) {
        case .Podcast:
            return FeedType.Podcast
        case .Video:
            return FeedType.Video
        case .Newsletter:
            return FeedType.Newsletter
        }
    }
}
