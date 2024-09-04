//
//  NewsletterValidationHelpers.swift
//  sphinx
//
//  Created by James Carucci on 8/29/24.
//  Copyright © 2024 sphinx. All rights reserved.
//

import Foundation

enum NewsletterPlatform {
    case substack
    case medium
    case wordpress
    case blogspot
    case ghost
    case tumblr
    case unknown
}

func identifyPlatform(from host: String) -> NewsletterPlatform {
    if host.contains("substack") { return .substack }
    if host.contains("medium") { return .medium }
    if host.contains("wordpress") { return .wordpress }
    if host.contains("blogspot") { return .blogspot }
    if host.contains("ghost") { return .ghost }
    if host.contains("tumblr") { return .tumblr }
    return .unknown
}

func formatAsRssFeedUrl(from urlString: String) -> String? {
    guard let url = URL(string: urlString),
          let host = url.host else {
        return nil
    }
    
    let platform = identifyPlatform(from: host)
    let components = host.components(separatedBy: ".")
    
    switch platform {
    case .substack:
        return "https://\(host)/feed"
        
    case .medium:
        if host == "medium.com", let path = url.path.split(separator: "/").first {
            return "https://medium.com/feed/@\(path)"
        } else {
            return "https://\(host)/feed"
        }
        
    case .wordpress:
        return "https://\(host)/feed/"
        
    case .blogspot:
        return "https://\(host)/feeds/posts/default"
        
    case .ghost:
        return "https://\(host)/rss/"
        
    case .tumblr:
        return "https://\(host)/rss"
        
    case .unknown:
        // Try to extract the main domain for generic RSS feed
        if components.count >= 2 {
            let domain = components.suffix(2).joined(separator: ".")
            return "https://\(domain)/rss"
        } else {
            return "https://\(host)/rss"
        }
    }
}

func validateRSSFeed(
    from urlString: String,
    completion: @escaping (Bool) -> ()
) {
    let managedContext = CoreDataManager.sharedManager.persistentContainer.viewContext
    ContentFeed.fetchContentFeed(
        at: urlString,
        chat: nil,
        searchResultDescription: nil,
        searchResultImageUrl: nil,
        persistingIn: managedContext,
        then: {
            result in
               if case .success(_) = result {
                   print(result)
                   let items = (try? result.get())?.items ?? []
                   let success = items.count > 0
                   completion(success)
               } else {
                   completion(false)
               }
        })
}

