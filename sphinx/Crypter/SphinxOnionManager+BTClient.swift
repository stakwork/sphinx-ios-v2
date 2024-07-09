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
            let timestamp = try signMs(seed: seed, idx: 0, time: getTimeWithEntropy(), network: self.network)
            API.sharedInstance.authorizeBTGateway(
                url: url,
                signedTimestamp: timestamp,
                callback: { success in
                    print(success)
                })
        }
        catch{
            print("failed authorizeBT")
        }
    }
    
    
}
