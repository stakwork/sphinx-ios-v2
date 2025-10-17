// ContentFeedItemVariant.swift
//
// Created by CypherPoet.
// ✌️
//
    
import Foundation
import CoreData
import SwiftyJSON


@objc(ContentFeedItem)
public final class ContentFeedItem: NSManagedObject {
    
    public static func createObjectFrom(
        json: JSON,
        context: NSManagedObjectContext? = nil,
        itemsData: [String: (String, String?)] = [:]
    ) -> ContentFeedItem? {
        
        guard let itemId = json[CodingKeys.itemID.rawValue].string else {
            return nil
        }
        
        var contentFeedItem: ContentFeedItem
        
        if let managedObjectContext = context {
            contentFeedItem = ContentFeedItem(context: managedObjectContext)
        } else {
            contentFeedItem = ContentFeedItem(entity: ContentFeedItem.entity(), insertInto: nil)
        }
        
        contentFeedItem.itemID = itemId
        
        contentFeedItem.title = json[CodingKeys.title.rawValue].stringValue
        contentFeedItem.authorName = json[CodingKeys.authorName.rawValue].stringValue
        contentFeedItem.itemDescription = json[CodingKeys.itemDescription.rawValue].stringValue
        contentFeedItem.datePublished = Date(timeIntervalSince1970: json[CodingKeys.datePublished.rawValue].doubleValue)
        contentFeedItem.enclosureURL = URL(string: json[CodingKeys.enclosureURL.rawValue].stringValue)
        contentFeedItem.enclosureKind = json[CodingKeys.enclosureKind.rawValue].stringValue
        contentFeedItem.imageURL = URL(string: json[CodingKeys.imageURL.rawValue].stringValue)
        contentFeedItem.linkURL = URL(string: json[CodingKeys.linkURL.rawValue].stringValue)
        contentFeedItem.referenceId = itemsData[itemId]?.0
        contentFeedItem.chaptersData = itemsData[itemId]?.1
        
        return contentFeedItem
    }
    
    public static func getChaptersFrom(json: String) -> (String?, [Chapter]) {
        var chapters: [Chapter] = []
        var mediaUrl: String? = nil
        
        if let jsonData = json.data(using: .utf8) {
            do {
                let graphData = try JSONDecoder().decode(GraphData.self, from: jsonData)
                
                for node in graphData.nodes {
                    let timestamp: TimeInterval = node.date_added_to_graph
                    let date = Date(timeIntervalSince1970: timestamp)
                    
                    if node.node_type == "Episode" {
                        mediaUrl = node.properties.media_url
                    } else if node.node_type == "Chapter" {
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
        
        return (mediaUrl, chapters.sorted(by: { $0.timestamp.toSeconds() < $1.timestamp.toSeconds() }))
    }
}

