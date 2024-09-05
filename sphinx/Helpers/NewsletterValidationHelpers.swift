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
        return "https://www.\(host)/feed"
        
    case .medium:
        if host == "medium.com", let path = url.path.split(separator: "/").first {
            return "https://medium.com/\(path)/feed/"
        } else {
            return "https://www.\(host)/feed"
        }
        
    case .wordpress:
        return "https://www.\(host)/feed"
        
    case .blogspot:
        return "https://www.\(host)/feeds/posts/default"
        
    case .ghost:
        return "https://www.\(host)/rss"
        
    case .tumblr:
        return "https://www.\(host)/feed"
        
    case .unknown:
        // Try to extract the main domain for generic RSS feed
        if components.count >= 2 {
            let domain = components.suffix(2).joined(separator: ".")
            return "https://www.\(domain)/feed"
        } else {
            return "https://www.\(host)/feed"
        }
    }
}

func validateRSSFeed(
    from urlString: String,
    triedPermutations: Set<String> = [],
    completion: @escaping (Bool) -> ()
) {
    let managedContext = CoreDataManager.sharedManager.persistentContainer.viewContext
    ContentFeed.fetchContentFeed(
        at: urlString,
        chat: nil,
        searchResultDescription: nil,
        searchResultImageUrl: nil,
        persistingIn: managedContext
    ) { result in
        if case .success(_) = result {
            print(result)
            let items = (try? result.get())?.items ?? []
            let success = items.count > 0
            completion(success)
        }else {
            let permutations = generatePermutations(for: urlString)
            let newPermutations = permutations.subtracting(triedPermutations)
            
            if let nextUrl = newPermutations.first {
                let updatedTriedPermutations = triedPermutations.union([urlString])
                validateRSSFeed(from: nextUrl, triedPermutations: updatedTriedPermutations, completion: completion)
            } else {
                completion(false)
            }
        }
    }
}

func generatePermutations(for urlString: String) -> Set<String> {
    var permutations = Set<String>()
    
    let url = URL(string: urlString)!
    var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
    
    // Swap /rss and /feed
    if components.path.hasSuffix("/rss") {
        components.path = components.path.replacingOccurrences(of: "/rss", with: "/feed")
    } else if components.path.hasSuffix("/feed") {
        components.path = components.path.replacingOccurrences(of: "/feed", with: "/rss")
    } else {
        components.path += "/rss"
        permutations.insert(components.url!.absoluteString)
        components.path = components.path.replacingOccurrences(of: "/rss", with: "/feed")
    }
    permutations.insert(components.url!.absoluteString)
    
    // Add or remove www.
    if components.host?.hasPrefix("www.") == true {
        components.host = components.host?.replacingOccurrences(of: "www.", with: "")
    } else {
        components.host = "www." + (components.host ?? "")
    }
    permutations.insert(components.url!.absoluteString)
    
    return permutations
}
