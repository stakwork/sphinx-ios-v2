// PodcastEpisode+CoreDataProperties.swift
//
// Created by CypherPoet.
// ✌️
//

import Foundation
import CoreData
import SwiftyJSON

public class PodcastEpisode: NSObject {
    
    public var itemID: String
    public var feedID: String?
    public var title: String?
    public var author: String?
    public var episodeDescription: String?
    public var datePublished: Date?
    public var dateUpdated: Date?
    public var urlPath: String?
    public var imageURLPath: String?
    public var linkURLPath: String?
    public var clipStartTime: Int?
    public var clipEndTime: Int?
    public var showTitle: String?
    public var feedURLPath: String?
    public var feedImageURLPath: String?
    public var feedTitle: String?
    public var people: [String] = []
    public var topics: [String] = []
    public var destination: PodcastDestination? = nil
    public var referenceId: String? = nil
    public var chapters: Array<Chapter>? = nil

    //For recommendations podcast
    public var type: String?
    
    init(_ itemID: String) {
        self.itemID = itemID
        
        self.chapters = [
            Chapter(dateAddedToGraph: Date.now, nodeType: "Chapter", isAd: false, name: "Chapter 1: solution for money supply", sourceLink: "", timestamp: "00:15:00", referenceId: "asdkjhasdkjhsadkjhad"),
            Chapter(dateAddedToGraph: Date.now, nodeType: "Chapter", isAd: true, name: "Chapter 2: and now what?", sourceLink: "", timestamp: "00:35:25", referenceId: "asdkjhasdkjhsadkjhadsadjhasd"),
            Chapter(dateAddedToGraph: Date.now, nodeType: "Chapter", isAd: false, name: "Chapter 3: new chapter episode?", sourceLink: "", timestamp: "00:45:20", referenceId: "asdkjhasdkjhsadkjhadsadjhasd")
        ]
    }
    
    var wasPlayed: Bool? {
        get {
            return UserDefaults.standard.value(forKey: "wasPlayed-\(feedAndItemId)") as? Bool
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "wasPlayed-\(feedAndItemId)")
        }
    }
    
    var duration: Int? {
        get {
            return UserDefaults.standard.value(forKey: "duration-\(feedAndItemId)") as? Int
        }
        set {
            if (newValue ?? 0 > 0) {
                UserDefaults.standard.set(newValue, forKey: "duration-\(feedAndItemId)")
            }
        }
    }
    
    var currentTime: Int? {
        get {
            return UserDefaults.standard.value(forKey: "current-time-\(feedAndItemId)") as? Int
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "current-time-\(feedAndItemId)")
        }
    }
    
    var feedAndItemId: String {
        get {
            if let feedID = feedID {
                return "\(feedID)-\(itemID)"
            }
            return "\(itemID)"
        }
    }
    
    var dateString : String?{
        let date = self.datePublished
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        if let valid_date = date{
            let dateString = formatter.string(from: valid_date)
            return dateString
        }
        return nil
    }
    
    public enum TimeStringType{
        case elapsed
        case total
        case remaining
    }
    
    var youtubeVideoId: String? {
        get {
            var videoId: String? = nil
        
            if let urlPath = self.linkURLPath {
                if let range = urlPath.range(of: "v=") {
                    videoId = String(urlPath[range.upperBound...])
                } else if let range = urlPath.range(of: "v/") {
                    videoId = String(urlPath[range.upperBound...])
                }
            }
            
            return videoId
        }
    }
}


extension PodcastEpisode {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ContentFeedItem> {
        return NSFetchRequest<ContentFeedItem>(entityName: "ContentFeedItem")
    }
    
}

extension PodcastEpisode: Identifiable {}



// MARK: -  Public Methods
extension PodcastEpisode {
    
    public static func convertFrom(
        contentFeedItem: ContentFeedItem,
        feed: PodcastFeed? = nil
    ) -> PodcastEpisode {
        
        let podcastEpisode = PodcastEpisode(
            contentFeedItem.itemID
        )
        
        podcastEpisode.author = contentFeedItem.authorName
        podcastEpisode.datePublished = contentFeedItem.datePublished
        podcastEpisode.dateUpdated = contentFeedItem.dateUpdated
        podcastEpisode.episodeDescription = contentFeedItem.itemDescription
        podcastEpisode.urlPath = contentFeedItem.enclosureURL?.absoluteString
        podcastEpisode.linkURLPath = contentFeedItem.linkURL?.absoluteString
        podcastEpisode.imageURLPath = contentFeedItem.imageURL?.absoluteString
        podcastEpisode.title = contentFeedItem.title
        podcastEpisode.feedID = feed?.feedID
        podcastEpisode.feedURLPath = feed?.feedURLPath
        podcastEpisode.feedImageURLPath = feed?.imageURLPath
        podcastEpisode.feedTitle = feed?.title
        podcastEpisode.type = RecommendationsHelper.PODCAST_TYPE
        podcastEpisode.referenceId = contentFeedItem.referenceId
        
        if let chaptersData = contentFeedItem.chaptersData {
            podcastEpisode.chapters = PodcastEpisode.getChaptersFrom(json: chaptersData)
        }
        
        return podcastEpisode
    }
    
    public static func getChaptersFrom(json: String) -> [Chapter] {
        var chapters: [Chapter] = []
        
        if let jsonData = json.data(using: .utf8) {
            do {
                let graphData = try JSONDecoder().decode(GraphData.self, from: jsonData)
                
                for node in graphData.nodes {
                    let timestamp: TimeInterval = node.date_added_to_graph
                    let date = Date(timeIntervalSince1970: timestamp)
                    
                    if node.node_type == "Chapter" {
                        chapters.append(
                            Chapter(
                                dateAddedToGraph: date,
                                nodeType: node.node_type,
                                isAd: (node.properties.is_ad == "True") ? true : false,
                                name: node.properties.name ?? node.properties.episode_title ?? "Unknown",
                                sourceLink: node.properties.source_link ?? "Unknown",
                                timestamp: node.properties.timestamp ?? "Unknown",
                                referenceId: node.ref_id
                            )
                        )
                    }
                }
            } catch {
                print("Error decoding JSON: \(error)")
            }
        } else {
            print("Failed to convert string to Data.")
        }
        
        return chapters
    }
    
    var isMusicClip: Bool {
        return type == RecommendationsHelper.PODCAST_TYPE || type == RecommendationsHelper.TWITTER_TYPE
    }
    
    var isPodcast: Bool {
        return type == RecommendationsHelper.PODCAST_TYPE
    }
    
    var isTwitterSpace: Bool {
        return type == RecommendationsHelper.TWITTER_TYPE
    }
    
    var isYoutubeVideo: Bool {
        return type == RecommendationsHelper.YOUTUBE_VIDEO_TYPE
    }
    
    var isRecommendationsPodcast: Bool {
        feedID == RecommendationsHelper.kRecommendationPodcastId
    }

    var intType: Int {
        get {
            if isMusicClip {
                return Int(FeedType.Podcast.rawValue)
            }
            if isYoutubeVideo {
                return Int(FeedType.Video.rawValue)
            }
            return Int(FeedType.Podcast.rawValue)
        }
    }
    
    var typeIconImage: String? {
        get {
            switch type {
            case RecommendationsHelper.PODCAST_TYPE:
                return "podcastTypeIcon"
            case RecommendationsHelper.YOUTUBE_VIDEO_TYPE:
                return "youtubeVideoTypeIcon"
            case RecommendationsHelper.TWITTER_TYPE:
                return "twitterTypeIcon"
            default:
                return "podcastTypeIcon"
            }
        }
    }
    
    var typeLabel: String {
        get {
            switch type {
            case RecommendationsHelper.PODCAST_TYPE:
                return "Podcast"
            case RecommendationsHelper.YOUTUBE_VIDEO_TYPE:
                return "Youtube"
            case RecommendationsHelper.TWITTER_TYPE:
                return "Twitter"
            default:
                return "Podcast"
            }
        }
    }
    
    func constructShareLink(useTimestamp:Bool=false)->String?{
        var link : String? = nil
        
        if let feedID = self.feedID, let feedURL = self.feedURLPath {
            link = "sphinx.chat://?action=share_content&feedURL=\(feedURL)&feedID=\(feedID)&itemID=\(itemID)"
        }
        
        if useTimestamp == true,
        let timestamp = currentTime,
        let _ = link{
            link! += "&atTime=\(timestamp)"
        }
        return link
    }
    
    func getAdTimestamps() -> [(Int, Int)] {
        guard let chapters = chapters else {
            return []
        }
        
        var timestamps: [(Int, Int)] = []
        
        for (index, chapter) in chapters.enumerated() {
            if chapter.isAd {
                if let nextChapterStart = chapters[index + 1].timestamp.timeStringToSeconds(), let adStart = chapter.timestamp.timeStringToSeconds() {
                    timestamps.append((adStart, nextChapterStart))
                }
            }
        }
        
        return timestamps
    }
    
}
