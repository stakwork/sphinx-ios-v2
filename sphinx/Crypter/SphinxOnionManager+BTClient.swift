//
//  SphinxOnionManager+BTClient.swift
//  sphinx
//
//  Created by James Carucci on 7/9/24.
//  Copyright © 2024 sphinx. All rights reserved.
//

import Foundation
extension SphinxOnionManager {
    
    func authorizeBT(){
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
    
    func searchAllTorrents(keyword:String){
        if let authDict = btAuthDict,
           let authString = unpackAuthString(dict: authDict){
            API.sharedInstance.searchBTGatewayForFeeds(
                url: "\(kAllTorrentLookupBaseURL)/search",
                authorizeDict: authString,
                keyword: keyword,
                callback:{ result in
                    print(result)
                }
            )
        }
    }
    
    
}
