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
    
    public func searchBTFeed(
            matching queryString: String,
            then completionHandler: @escaping BTSearchCompletionHandler
        ) {
            
            let hostProtocol = UserDefaults.Keys.isProductionEnv.get(defaultValue: false) ? "https" : "http"
            let urlString = "http://guava.whatbox.ca:30433/?json&q=\(queryString)" // temporary hard code

//            var urlComponents = URLComponents(string: urlPath)!
//            urlComponents.queryItems = [
//                URLQueryItem(name: "q", value: queryString)
//            ]

//            guard let urlString = urlComponents.url?.absoluteString else {
//                completionHandler(.failure(.failedToCreateRequestURL))
//                return
//            }

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
                    var mediaArray = [BTMedia]()
                    if let resultDict = data as? NSDictionary,
                       let pathsArray = resultDict["paths"] as? [[String: Any]] {
                        
                        for pathDict in pathsArray {
                            if let media = BTMedia(JSON: pathDict) {
                                mediaArray.append(media)
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
