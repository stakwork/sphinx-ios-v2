//
//  SphinxOnionManager+BTClient.swift
//  sphinx
//
//  Created by James Carucci on 7/9/24.
//  Copyright © 2024 sphinx. All rights reserved.
//

import Foundation
extension SphinxOnionManager {
    
    func authorizeBT(callback: @escaping (Bool) -> ()){
        let url = self.kAllTorrentLookupBaseURL + "/authorize"
        guard let seed = getAccountSeed() else{
            return
        }
        do{
            let timestamp = try signedTimestamp(seed: seed, idx: 0, time: getTimeWithEntropy(), network: self.network)
            API.sharedInstance.authorizeBTGateway(
                url: url,
                signedTimestamp: timestamp,
                callback: { resultDict in
                    if let resultDict = resultDict{
                        self.btAuthDict = resultDict
                        callback(true)
                    }
                    else{
                        callback(false)
                    }
                })
        }
        catch{
            print("failed authorizeBT")
        }
    }
    
    func unpackAuthString(dict:NSDictionary) -> [String:String]?{
        if let token = dict["token"] as? String,
           let tokenType = dict["token_type"] as? String{
            return [
                "Authorization":"\(tokenType) \(token)"
            ]
        }
        return nil
    }
    
    func searchAllTorrents(keyword:String, callback: @escaping (([BTFeedSearchDataMapper])->())){
        if let authDict = btAuthDict,
           let authString = unpackAuthString(dict: authDict){
            API.sharedInstance.searchBTGatewayForFeeds(
                url: "\(kAllTorrentLookupBaseURL)/search",
                authorizeDict: authString,
                keyword: keyword,
                callback:{ result in
                    callback(result)
                }
            )
        }
    }
    
    func getMagnetDetails(
        data:BTFeedSearchDataMapper,
        callback: @escaping (MagnetDetailsResponse?) -> ()
    ){
        guard let magnet = data.magnet_link,
              let authDict = btAuthDict,
              let authString = unpackAuthString(dict: authDict) else{
            return
        }
        API.sharedInstance.getMagnetDetails(
            url: "\(kAllTorrentLookupBaseURL)/magnet_details",
            authorizeDict: authString,
            magnetLink: magnet,
            callback: { response in
                print(response)
                callback(response)
            }
        )
    }
    
    func downloadTorrentViaMagnet(
        magnetLink:String,
        magnetDetails:MagnetDetailsResponse,
        completion: @escaping (Bool) -> ()
    ){
        guard let initialPeers = magnetDetails.seenPeers,
        let authDict = btAuthDict,
        let authString = unpackAuthString(dict: authDict) else{
            return
        }
        API.sharedInstance.requestTorrentDownload(
            url: "\(kAllTorrentLookupBaseURL)/add_magnet",
            authorizeDict: authString,
            magnetLink: magnetLink,
            initialPeers: initialPeers,
            callback: { success in
                completion(success)
            })
    }
    
    
}
