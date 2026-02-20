// ContentFeed+Computeds.swift
//
// Created by CypherPoet.
// ✌️
//
    
import Foundation
import CoreData


extension ContentFeed {
    
    public var feedKind: FeedType {
        get {
            .init(rawValue: feedKindValue)!
        }
        set {
            feedKindValue = newValue.rawValue
        }
    }
    
    
    public var contentMediaKind: ContentFeedMediaKind {
        get {
            .init(rawValue: mediaKindValue)!
        }
        set {
            mediaKindValue = newValue.rawValue
        }
    }
    
    var isPodcast: Bool {
        return self.feedKind.rawValue == FeedType.Podcast.rawValue
    }
    
    var isVideo: Bool {
        return self.feedKind.rawValue == FeedType.Video.rawValue
    }
    
    var isNewsletter: Bool {
        return self.feedKind.rawValue == FeedType.Newsletter.rawValue
    }
    
    var destinationsArray: [ContentFeedPaymentDestination] {
        guard let destinations = paymentDestinations else { return [] }
        
        return Array(destinations)
    }
    
    var itemsArray: [ContentFeedItem] {
        guard let items = items else {
            return []
        }
        
        if !sortedItemsArray.isEmpty {
               return sortedItemsArray
        }
        
        sortedItemsArray = items.sorted { (first, second) in
            if first.datePublished == nil {
                return false
            } else if second.datePublished == nil {
                return true
            }
            
            return first.datePublished! > second.datePublished!
        }
        
        return sortedItemsArray
    }
    
    var currentItemId: String {
        get {
            return UserDefaults.standard.string(forKey: "current-item-id-\(feedID)") ?? ""
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "current-item-id-\(feedID)")
        }
    }
    
    var currentItem: ContentFeedItem? {
        if !itemsArray.isEmpty {
            // First try to get the current playing item
            let currentId = currentItemId
            if !currentId.isEmpty,
               let currentItem = itemsArray.first(where: { $0.id == currentId }) {
                return currentItem
            }
            // Then try the last consumed item
            if let lastConsumedId = lastConsumedItemId,
               let lastConsumedItem = itemsArray.first(where: { $0.id == lastConsumedId }) {
                return lastConsumedItem
            }
            // Finally fall back to most recent item
            return itemsArray.first
        }
        return nil
    }
    
    var lastConsumedItemId: String? {
        get {
            return UserDefaults.standard.string(forKey: "last-consumed-item-id-\(feedID)")
        }
        set {
            if let newValue = newValue {
                UserDefaults.standard.set(newValue, forKey: "last-consumed-item-id-\(feedID)")
            } else {
                UserDefaults.standard.removeObject(forKey: "last-consumed-item-id-\(feedID)")
            }
        }
    }
    
    func updateLastPlayedItem(_ item: ContentFeedItem) {
        updateLastPlayedItem(item.id)
    }
    
    func updateLastPlayedItem(_ id: String) {
        lastConsumedItemId = id
        dateLastConsumed = Date()
    }
}
