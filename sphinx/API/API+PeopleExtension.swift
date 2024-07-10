//
//  APIPeopleExtension.swift
//  sphinx
//
//  Created by Tomas Timinskas on 26/05/2021.
//  Copyright © 2021 Tomas Timinskas. All rights reserved.
//

import Foundation
import Alamofire
import SwiftyJSON

extension API {
    
    typealias VerifyExternalCallback = ((Bool, NSDictionary?) -> ())
    typealias SignVerifyCallback = ((String?) -> ())
    typealias GetPersonInfoCallback = ((Bool, JSON?) -> ())
    typealias GetExternalRequestByKeyCallback = ((Bool, JSON?) -> ())
    typealias PeopleTorRequestCallback = ((Bool) -> ())
    typealias GetPersonProfileCallback = ((Bool, JSON?) -> ())
    typealias GetTribeMemberProfileCallback = ((Bool, TribeMemberStruct?) -> ())
    typealias SearchBTGatewayCallback = (([BTFeedSearchDataMapper]) -> ())
    
    public func authorizeBTGateway(
        url: String,
        signedTimestamp:String,
        callback: @escaping AuthorizeBTCallback
    ){
        var params = [String: AnyObject]()
        params["signed_timestamp"] = signedTimestamp as? AnyObject
        guard let request = createRequest(url, bodyParams: params as NSDictionary, method: "POST") else {
            callback(nil)
            return
        }
        
        AF.request(request).responseJSON { (response) in
            switch response.result {
            case .success(let data):
                if let dict = data as? NSDictionary {
                    callback(dict)
                }
            case .failure(_):
                callback(nil)
            }
        }
    }
    
    public func searchBTGatewayForFeeds(
        url:String,
        authorizeDict:[String:String],
        keyword:String,
        callback: @escaping SearchBTGatewayCallback
    ){
        var params = [String: AnyObject]()
        params["keyword"] = keyword as? AnyObject
        guard let request = createRequest(
            url,
            bodyParams: params as NSDictionary,
            headers: authorizeDict,
            method: "POST"
        ) else {
            callback([BTFeedSearchDataMapper]())
            return
        }
        
        AF.request(request).responseJSON { (response) in
            switch response.result {
            case .success(let value):
                guard let jsonArray = value as? [[String: Any]] else {
                    callback([BTFeedSearchDataMapper]())
                    return
                }
                
                let feeds = jsonArray.compactMap { dict -> BTFeedSearchDataMapper? in
                    return BTFeedSearchDataMapper(JSON: dict)
                }
                
                callback(feeds)
            case .failure(_):
                callback([BTFeedSearchDataMapper]())
            }
        }
    }
    
    public func getMagnetDetails(
            url:String,
            authorizeDict:[String:String],
            magnetLink:String,
            callback: @escaping ((MagnetDetailsResponse?) -> ())
    ){
        var params = [String: AnyObject]()
        params["magnet"] = magnetLink as? AnyObject
        guard let request = createRequest(
            url,
            bodyParams: params as NSDictionary,
            headers: authorizeDict,
            method: "POST"
        ) else {
            callback(nil)
            return
        }
        
        AF.request(request).responseJSON { (response) in
            switch response.result {
            case .success(let value):
                if let json = value as? [String: Any],
                   let torrentDetails = MagnetDetailsResponse(JSON: json) {
                    callback(torrentDetails)
                } else {
                    callback(nil)
                }
            case .failure(let error):
                print("Request failed with error: \(error)")
                callback(nil)
            }
        }
    }
    
    public func requestTorrentDownload(
        url: String,
        authorizeDict: [String: String],
        magnetLink: String,
        initialPeers: [String],
        callback: @escaping ((Bool?) -> ())
    ) {
        var params = [String: AnyObject]()
        var options = [String: AnyObject]()
        params["magnet"] = magnetLink as AnyObject
        options["peers"] = initialPeers as AnyObject
        options["overwrite"] = true as AnyObject
        options["list_only"] = false as AnyObject // Adding the list_only field with a default value
        options["disable_trackers"] = false as AnyObject
        options["paused"] = false as AnyObject // Adding the paused field with a default value
        params["options"] = options as AnyObject
        guard let request = createRequest(
            url,
            bodyParams: params as NSDictionary,
            headers: authorizeDict,
            method: "POST"
        ) else {
            callback(nil)
            return
        }

        AF.request(request).responseJSON { (response) in
            switch response.result {
            case .success(let value):
                callback(true)
            case .failure(let error):
                print("Request failed with error: \(error)")
                if let data = response.data {
                    let responseString = String(data: data, encoding: .utf8)
                    print("Response data: \(responseString ?? "nil")")
                }
                callback(nil)
            }
        }
    }
    
    public func authorizeExternal(host: String,
                                  challenge: String,
                                  token: String,
                                  params: [String: AnyObject],
                                  callback: @escaping SuccessCallback) {
        
        let url = "https://\(host)/verify/\(challenge)?token=\(token)"
        
        guard let request = createRequest(url, bodyParams: params as NSDictionary, method: "POST") else {
            callback(false)
            return
        }
        
        AF.request(request).responseJSON { (response) in
            switch response.result {
            case .success(let data):
                if let _ = data as? NSDictionary {
                    callback(true)
                }
            case .failure(_):
                callback(false)
            }
        }
    }
    
    public func getPersonInfo(host: String,
                              pubkey: String,
                              callback: @escaping GetPersonInfoCallback) {
        
        let url = "https://\(host)/person/\(pubkey)"
        
        guard let request = createRequest(url, bodyParams: nil, method: "GET") else {
            callback(false, nil)
            return
        }
        
        AF.request(request).responseJSON { (response) in
            switch response.result {
            case .success(let data):
                if let json = data as? NSDictionary {
                    callback(true, JSON(json))
                    return
                }
                callback(false, nil)
            case .failure(_):
                callback(false, nil)
            }
        }
    }
    
    public func getExternalRequestByKey(host: String,
                                        key: String,
                                        callback: @escaping GetExternalRequestByKeyCallback) {
        
        let url = "https://\(host)/save/\(key)"
        
        guard let request = createRequest(url, bodyParams: nil, method: "GET") else {
            callback(false, nil)
            return
        }
        
        AF.request(request).responseJSON { (response) in
            switch response.result {
            case .success(let data):
                if let json = data as? NSDictionary {
                    callback(true, JSON(json))
                    return
                }
                callback(false, nil)
            case .failure(_):
                callback(false, nil)
            }
        }
    }
    
    public func savePeopleProfile(params: [String: AnyObject],
                                  callback: @escaping PeopleTorRequestCallback) {
        
//        guard let request = getURLRequest(route: "/profile", params: params as NSDictionary, method: "POST") else {
//            callback(false)
//            return
//        }
//        
//        sphinxRequest(request) { response in
//            switch response.result {
//            case .success(let data):
//                if let json = data as? NSDictionary {
//                    if let success = json["success"] as? Bool,
//                       let _ = json["response"] as? NSDictionary, success {
//                        callback(true)
//                        return
//                    }
//                }
//                callback(false)
//            case .failure(_):
//                callback(false)
//            }
//        }
    }
    
    public func deletePeopleProfile(params: [String: AnyObject],
                                    callback: @escaping PeopleTorRequestCallback) {
        
//        guard let request = getURLRequest(route: "/profile", params: params as NSDictionary, method: "DELETE") else {
//            callback(false)
//            return
//        }
//        
//        sphinxRequest(request) { response in
//            switch response.result {
//            case .success(let data):
//                if let json = data as? NSDictionary {
//                    if let success = json["success"] as? Bool,
//                       let _ = json["response"] as? NSDictionary, success {
//                        callback(true)
//                        return
//                    }
//                }
//                callback(false)
//            case .failure(_):
//                callback(false)
//            }
//        }
    }
    
    public func redeemBadgeTokens(params: [String: AnyObject],
                                  callback: @escaping PeopleTorRequestCallback) {
        
//        guard let request = getURLRequest(route: "/claim_on_liquid", params: params as NSDictionary, method: "POST") else {
//            callback(false)
//            return
//        }
//        
//        sphinxRequest(request) { response in
//            switch response.result {
//            case .success(let data):
//                if let json = data as? NSDictionary {
//                    if let success = json["success"] as? Bool,
//                       let _ = json["response"] as? NSDictionary, success {
//                        callback(true)
//                        return
//                    }
//                }
//                callback(false)
//            case .failure(_):
//                callback(false)
//            }
//        }
    }
    
    public func getTribeMemberInfo(
        person: String,
        callback: @escaping GetTribeMemberProfileCallback
    ) {
        
        guard let host = person.personHost, let uuid = person.personUUID else {
            callback(false, nil)
            return
        }
        
        //let test = "cd9dm5ua5fdtsj2c2mtg"
        let url = "https://\(host)/person/uuid/\(uuid)"
        
        guard let request = createRequest(url, bodyParams: nil, method: "GET") else {
            callback(false, nil)
            return
        }
        
        AF.request(request).responseJSON { (response) in
            switch response.result {
            case .success(let data):
                if let json = data as? NSDictionary {
                    let tribeMember = TribeMemberStruct(json: JSON(json))
                    callback(true, tribeMember)
                    return
                }
                callback(false, nil)
            case .failure(_):
                callback(false, nil)
            }
        }
    }
}
