//
//  APIPodcastExtension.swift
//  sphinx
//
//  Created by Tomas Timinskas on 08/10/2020.
//  Copyright © 2020 Sphinx. All rights reserved.
//

import Foundation
import Alamofire
import CryptoKit
import SwiftyJSON
import ObjectMapper


extension API {
    public func searchForFeeds(
        with type: FeedType,
        matching queryString: String,
        then completionHandler: @escaping FeedSearchCompletionHandler
    ) {
        
        let route = (type == FeedType.Podcast) ? "search_podcasts" : "search_youtube"
        let hostProtocol = UserDefaults.Keys.isProductionEnv.get(defaultValue: false) ? "https" : "http"
        let urlPath = "https://tribes.sphinx.chat/search_podcasts"//"\(hostProtocol)://\(SphinxOnionManager.sharedInstance.tribesServerIP)/\(route)" //temporary hard code
        
        var urlComponents = URLComponents(string: urlPath)!
        urlComponents.queryItems = [
            URLQueryItem(name: "q", value: queryString)
        ]

        guard let urlString = urlComponents.url?.absoluteString else {
            completionHandler(.failure(.failedToCreateRequestURL))
            return
        }

        guard let request = createRequest(
            urlString,
            bodyParams: nil,
            method: "GET"
        ) else {
            completionHandler(.failure(.failedToCreateRequest(urlPath: urlPath)))
            return
        }

        podcastSearchRequest?.cancel()
        
        podcastSearchRequest = AF.request(request).responseJSON { response in
            switch response.result {
            case .success(let data):
                var results = [FeedSearchResult]()
                
                if let itemsArray = data as? NSArray {
                    itemsArray.forEach {
                        results.append(
                            FeedSearchResult.convertFrom(
                                searchResult: JSON($0),
                                type: type
                            )
                        )
                    }
                }
                
                completionHandler(.success(results))
            case .failure(let error):
                completionHandler(.failure(.networkError(error)))
            }
        }
    }
    
    func searchBroadFeedforAudioFiles( //searches a specific directory path for underlying files (i.e. Joe Rogan -> #911 with Duncan Trussell.mp3, RHCP Californication -> Californication.mp3
        feedOrAlbumString:String,
        completionHandler: @escaping FeedSearchCompletionHandler
    ) {
        let urlString = "\(btBaseUrl)/\(feedOrAlbumString)/?json"
        
        guard let encodedURLString = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: encodedURLString) else {
            completionHandler(.failure(.failedToCreateRequest(urlPath: urlString)))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        podcastSearchRequest?.cancel()
        
        podcastSearchRequest = AF.request(request).responseJSON { response in
            switch response.result {
            case .success(let data):
                var mediaArray = [FeedSearchResult]()
                if let resultDict = data as? NSDictionary,
                   let pathsArray = resultDict["paths"] as? [[String: Any]] {
                    
                    for pathDict in pathsArray {
                        if let media = BTMedia(JSON: pathDict) {
                            let result = media.convertBTMediaToFeedSearchResult(type: .Track)
                            if result.feedURLPath.isNotEmpty {
                                mediaArray.append(result)
                            }
                        }
                    }
                }
                completionHandler(.success(mediaArray))
            case .failure(let error):
                completionHandler(.failure(.networkError(error)))
            }
        }
    }
    
    public func searchBTFeed(
        matching queryString: String,
        type: FeedType,
        then completionHandler: @escaping FeedSearchCompletionHandler
    ) {
        let urlString = "\(btBaseUrl)/?json&q=\(queryString)"

        guard let request = createRequest(
            urlString,
            bodyParams: nil,
            method: "GET"
        ) else {
            completionHandler(.failure(.failedToCreateRequest(urlPath: urlString)))
            return
        }

        podcastSearchRequest?.cancel()
        
        podcastSearchRequest = AF.request(request).responseJSON { response in
            switch response.result {
            case .success(let data):
                var mediaArray = [FeedSearchResult]()
                if let resultDict = data as? NSDictionary,
                   let pathsArray = resultDict["paths"] as? [[String: Any]] {
                    
                    for pathDict in pathsArray {
                        if let media = BTMedia(JSON: pathDict) {
                            let result = media.convertBTMediaToFeedSearchResult(type: type)
                            if result.feedURLPath.isNotEmpty {
                                mediaArray.append(result)
                            }
                        }
                    }
                }
                completionHandler(.success(mediaArray))
            case .failure(let error):
                completionHandler(.failure(.networkError(error)))
            }
        }
    }
    
    //@Tom need to decide whether we want this or want to reimplement on V2
//    public func getFeedRecommendations(
//        callback: @escaping RecommendationsCallback,
//        errorCallback: @escaping EmptyCallback
//    ) {
//        if(UserDefaults.Keys.shouldTrackActions.get(defaultValue: false) == false){
//            callback([])//skip the request and return nothing
//        }
//        guard let request = getURLRequest(route: "/feeds", method: "GET") else {
//            errorCallback()
//            return
//        }
//        
//        sphinxRequest(request) { response in
//            switch response.result {
//            case .success(let data):
//                if let json = data as? NSDictionary {
//                    if let success = json["success"] as? Bool, let recommendations = json["response"] as? NSArray, success {
//                        var recommendationsResults: [RecommendationResult] = []
//                        
//                        for r in recommendations {
//                            
//                            recommendationsResults.append(
//                                RecommendationResult.convertFrom(recommendationResult: JSON(r))
//                            )
//                        }
//                        
//                        callback(recommendationsResults)
//                    } else {
//                        errorCallback()
//                    }
//                }
//            case .failure(_):
//                errorCallback()
//            }
//        }
//    }
}


// BTMedia Model
class BTMedia: Mappable {
    var size: Int64?
    var pathType: String?
    var name: String?
    var mtime: Int64?
    
    required init?(map: Map) {
        // Initialize if needed
    }
    
    func mapping(map: Map) {
        size       <- (map["size"], transformToInt64)
        pathType   <- map["path_type"]
        name       <- map["name"]
        mtime      <- (map["mtime"], transformToInt64)
    }
    
    func convertBTMediaToFeedSearchResult(type: FeedType) -> FeedSearchResult {
        let btMedia = self
        let feedId = btMedia.name ?? "Unknown"
        let title = btMedia.name ?? "No Title"
        let feedDescription = "Type: \(btMedia.pathType ?? "Unknown"), Size: \(btMedia.size ?? 0)"
        var imageUrl = type == .Podcast
            ? "https://png.pngtree.com/png-vector/20211018/ourmid/pngtree-simple-podcast-logo-design-png-image_3991612.png"
            : "https://png.pngtree.com/png-clipart/20210309/original/pngtree-movie-clip-art-movie-film-field-clapper-board-png-image_5862049.jpg"
        var feedURLPath = ""
        var finalType = type
        
        if let fileName = btMedia.name?.lowercased() {
            let videoExtensions = [".m4v", ".avi", ".mp4", ".mov", ".mkv"]
            let audioExtensions = [".mp3", ".m4a", ".aac", ".wav", ".ogg", ".flac", ".wma", ".aiff", ".opus"]
            let readerExtensions = [".epub",".pdf"]
            switch type {
            case .Podcast where btMedia.pathType == "Dir":
                feedURLPath = "\(btMedia.name!)"
            case .Track where audioExtensions.contains(where: fileName.hasSuffix):
                feedURLPath = "\(btMedia.name!)"
            case .Video where videoExtensions.contains(where: fileName.hasSuffix):
                feedURLPath = "\(API.sharedInstance.btBaseUrl)/\(btMedia.name!)"
            case .BrowseTorrent where btMedia.pathType == "Dir" || videoExtensions.contains(where: fileName.hasSuffix):
                let isVideo = (videoExtensions.contains(where: fileName.hasSuffix))
                finalType = isVideo ? .Video : .Podcast
                imageUrl = (isVideo == false) ? "https://png.pngtree.com/png-vector/20211018/ourmid/pngtree-simple-podcast-logo-design-png-image_3991612.png"
                : "https://png.pngtree.com/png-clipart/20210309/original/pngtree-movie-clip-art-movie-film-field-clapper-board-png-image_5862049.jpg"
                feedURLPath = isVideo ? "\(API.sharedInstance.btBaseUrl)/\(btMedia.name!)" : "\(btMedia.name!)"
            case .Newsletter where readerExtensions.contains(where: fileName.hasSuffix):
                imageUrl = "https://png.pngtree.com/png-vector/20231016/ourmid/pngtree-isolated-book-sticker-png-image_10188106.png"
                feedURLPath = "\(API.sharedInstance.btBaseUrl)/\(btMedia.name!)"
                print("Newsletter tab retrieved:\(feedURLPath)")
            default:
                break
            }
        }
        
        return FeedSearchResult(feedId, title, feedDescription, imageUrl, feedURLPath, finalType)
    }

    private func isAudioFile() -> Bool {
        let audioExtensions = [".mp3", ".m4a", ".aac", ".wav", ".ogg", ".flac", ".wma", ".aiff", ".opus"]
        return audioExtensions.contains { (self.name ?? "").lowercased().hasSuffix($0) }
    }
    
    // Custom transform to handle Int64 and null values
    let transformToInt64 = TransformOf<Int64, Any>(fromJSON: { (value: Any?) -> Int64? in
        if let intValue = value as? Int64 {
            return intValue
        } else if let intValue = value as? Int {
            return Int64(intValue)
        } else if let stringValue = value as? String, let intValue = Int64(stringValue) {
            return intValue
        } else {
            return nil
        }
    }, toJSON: { (value: Int64?) -> Any? in
        if let value = value {
            return value
        }
        return nil
    })
    
    // Computed property to get the file extension
    var fileExtension: String? {
        return (name as NSString?)?.pathExtension
    }
}

// BTMediaResponse Model
class BTMediaResponse: Mappable {
    var paths: [BTMedia]?
    
    required init?(map: Map) {
        // Initialize if needed
    }
    
    func mapping(map: Map) {
        paths <- map["paths"]
    }
}

// Function to parse JSON
func parsePaths(json: Any) -> [BTMedia]? {
    if let resultDict = json as? [String: Any], let pathsArray = resultDict["paths"] {
        guard let jsonString = (pathsArray as AnyObject).description else { return nil }
        if let pathsResponse = BTMediaResponse(JSONString: jsonString) {
            return pathsResponse.paths
        }
    }
    return nil
}
