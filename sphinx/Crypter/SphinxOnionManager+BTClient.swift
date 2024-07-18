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
            paymenHash: nil,
            callback: { success,bolt11 in
                if let bolt11 = bolt11,
                   let paymentHash = try? paymentHashFromInvoice(bolt11: bolt11){
                    self.handlePaymentAndRetry(
                        authString:authString,
                        magnetLink:magnetLink,
                        magnetDetails:magnetDetails,
                        initialPeers: initialPeers,
                        paymentHash: paymentHash,
                        callback: completion
                    )
                }
                else{
                    completion(success)
                }
            })
    }
    
    func handlePaymentAndRetry(
        authString: [String: String],
        magnetLink: String,
        magnetDetails: MagnetDetailsResponse,
        initialPeers: [String],
        paymentHash: String,
        callback: @escaping (Bool) -> Void
    ) {
        var paymentObserver: NSObjectProtocol?
        var finishedFlag = false
        paymentObserver = NotificationCenter.default.addObserver(
            forName: .invoiceIPaidSettled,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            if let userInfo = notification.userInfo,
               let receivedHash = userInfo["payment_hash"] as? String,
               receivedHash == paymentHash {
                if let observer = paymentObserver {
                    NotificationCenter.default.removeObserver(observer)
                }
                API.sharedInstance.requestTorrentDownload(
                    url: "\(self.kAllTorrentLookupBaseURL)/add_magnet",
                    authorizeDict: authString,
                    magnetLink: magnetLink,
                    initialPeers: initialPeers,
                    paymenHash: paymentHash,
                    callback: { success, _ in
                        finishedFlag = true
                        callback(success)
                    }
                )
            }
        }

        // Set a 15-second timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
            guard let self = self else { return }
            if let observer = paymentObserver {
                NotificationCenter.default.removeObserver(observer)
                if(finishedFlag == false){callback(false)}
            }
        }
    }
    
}
