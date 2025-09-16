//
//  GroupsManager+TribesInfo.swift
//  sphinx
//
//  Created by Tomas Timinskas on 25/10/2021.
//  Copyright © 2021 sphinx. All rights reserved.
//

import Foundation
import SwiftyJSON
import CoreData

extension GroupsManager {
    
    struct TribeInfo: Equatable {
        var name : String? = nil
        var description : String? = nil
        var img : String? = nil
        var groupKey : String? = nil
        var ownerPubkey : String? = nil
        var ownerAlias : String? = nil
        var pin : String? = nil
        var host : String! = nil
        var uuid : String! = nil
        var tags : [Tag] = []
        var priceToJoin : Int? = nil
        var pricePerMessage : Int? = nil
        var amountToStake : Int? = nil
        var timeToStake : Int? = nil
        var unlisted : Bool = false
        var privateTribe : Bool = false
        var deleted : Bool = false
        var appUrl : String? = nil
        var secondBrainUrl : String? = nil
        var feedUrl : String? = nil
        var feedContentType : FeedContentType? = nil
        var ownerRouteHint : String? = nil
        var bots : [Bot] = []
        var badgeIds: [Int] = []
        
        var nonZeroPriceToJoin: Int {
            if let priceToJoin = priceToJoin, priceToJoin > 0 {
                return priceToJoin
            }
            return 1000
        }
        
        static func == (lhs: TribeInfo, rhs: TribeInfo) -> Bool {
            return lhs.name           == rhs.name &&
                   lhs.description    == rhs.description &&
                   lhs.uuid           == rhs.uuid &&
                   lhs.host           == rhs.host &&
                   lhs.groupKey       == rhs.groupKey
        }
        
        var hasLoopoutBot : Bool {
            get {
                for bot in bots {
                    if bot.prefix == "/loopout" {
                        return true
                    }
                }
                return false
            }
        }
        
        var isValid: Bool {
            get {
                return name != nil && description != nil && groupKey != nil
            }
        }
    }
    
    ///Sphinx v2
    static func getChatJSON(
        tribeInfo: TribeInfo
    ) -> JSON? {
        let chatDict : [String: Any] = [
            "id": SphinxOnionManager.sharedInstance.generateCryptographicallySecureRandomInt(upperBound: Int(1e5)) as Any,
            "owner_pubkey": tribeInfo.ownerPubkey as Any,
            "name" : tribeInfo.name ?? "Unknown Name",
            "private": tribeInfo.privateTribe,
            "photo_url": tribeInfo.img ?? "",
            "unlisted": tribeInfo.unlisted,
            "price_per_message": tribeInfo.pricePerMessage ?? 0,
            "escrow_amount": max(tribeInfo.amountToStake ?? 3, 3)
        ]
        let chatJSON = JSON(chatDict)
        return chatJSON
    }
    
    func getV2Pubkey(qrString: String) -> String? {
        if let url = URL(string: "\(API.kHUBServerUrl)?\(qrString)"),
            let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
            let queryItems = components.queryItems,
            let pubkey = queryItems.first(where: { $0.name == "pubkey" })?.value
        {
            return cleanPubKey(pubkey)
        }
        return nil
    }
    
    func getV2Host(qrString: String) -> String? {
        if let url = URL(string: "\(API.kHUBServerUrl)?\(qrString)"),
            let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
            let queryItems = components.queryItems,
            let host = queryItems.first(where: { $0.name == "host" })?.value
        {
            return cleanPubKey(host)
        }
        return nil
    }
    
    func cleanPubKey(_ key: String) -> String {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasSuffix("\")") {
            return String(trimmed.dropLast(2))
        } else {
            return trimmed
        }
    }
    
    func fetchTribeInfo(
        host: String,
        uuid: String,
        useSSL: Bool = false,
        completion: @escaping CreateGroupCallback,
        errorCallback: @escaping EmptyCallback
    ){
        API.sharedInstance.getTribeInfo(
            host: host,
            uuid: uuid,
            callback: { groupInfo in
                completion(groupInfo)
            }, errorCallback: {
                errorCallback()
            }
        )
    }
    
    func finalizeTribeJoin(
        tribeInfo: TribeInfo,
        qrString: String
    ){
        if let pubkey = getV2Pubkey(qrString: qrString),
           let chatJSON = GroupsManager.getChatJSON(tribeInfo:tribeInfo),
           let routeHint = tribeInfo.ownerRouteHint
        {
            let isPrivate = tribeInfo.privateTribe
            let priceToJoin = tribeInfo.nonZeroPriceToJoin
            
            if SphinxOnionManager.sharedInstance.joinTribe(
                tribePubkey: pubkey,
                routeHint: routeHint,
                joinAmountMsats: priceToJoin,
                alias: UserContact.getOwner()?.nickname,
                isPrivate: isPrivate,
                errorCallback: { error in
                    AlertHelper.showAlert(
                        title: "generic.error.title".localized,
                        message: error.localizedDescription
                    )
                }
            ) {
                if let chat = Chat.insertChat(chat: chatJSON) {
                    chat.status = (isPrivate) ? Chat.ChatStatus.pending.rawValue : Chat.ChatStatus.approved.rawValue
                    chat.type = Chat.ChatType.publicGroup.rawValue
                    chat.managedObjectContext?.saveContext()
                }
            }
        }
    }
    
    func lookupAndRestoreTribe(
        pubkey: String,
        host: String,
        context: NSManagedObjectContext? = nil,
        completion: @escaping (Chat?) -> ()
    ){
        let tribeInfo = GroupsManager.TribeInfo(ownerPubkey: pubkey, host: host, uuid: pubkey)
        
        GroupsManager.sharedInstance.fetchTribeInfo(
            host: tribeInfo.host,
            uuid: tribeInfo.uuid,
            useSSL: false,
            completion: { groupInfo in
                if groupInfo["deleted"].boolValue == true {
                    completion(nil)
                    return
                }
                
                let chatDict : [String: Any] = [
                    "id": SphinxOnionManager.sharedInstance.generateCryptographicallySecureRandomInt(upperBound: Int(1e5)) as Any,
                    "owner_pubkey": groupInfo["pubkey"],
                    "name" : groupInfo["name"],
                    "private": groupInfo["private"],
                    "photo_url": groupInfo["img"],
                    "unlisted": groupInfo["unlisted"],
                    "price_per_message": groupInfo["price_per_message"],
                    "escrow_amount": max(groupInfo["escrow_amount"].int ?? 3, 3)
                ]
                
                let chatJSON = JSON(chatDict)
                let resultantChat = Chat.insertChat(chat: chatJSON, context: context)
                resultantChat?.status = (chatDict["private"] as? Bool ?? false) ? Chat.ChatStatus.pending.rawValue : Chat.ChatStatus.approved.rawValue
                resultantChat?.type = Chat.ChatType.publicGroup.rawValue
                completion(resultantChat)
            }, errorCallback: {
                completion(nil)
            }
        )
    }
    
    func fetchTribeInfoAsync(
        pubkey: String,
        host: String,
        context: NSManagedObjectContext? = nil
    ) async -> JSON? {
        let tribeInfo = GroupsManager.TribeInfo(ownerPubkey: pubkey, host: host, uuid: pubkey)
        
        return await withCheckedContinuation { continuation in
            var hasResumed = false  // ✅ Keep this safeguard
            
            GroupsManager.sharedInstance.fetchTribeInfo(
                host: tribeInfo.host,
                uuid: tribeInfo.uuid,
                useSSL: false,
                completion: { groupInfo in
                    guard !hasResumed else {
                        return
                    }
                    hasResumed = true
                    
                    if groupInfo["deleted"].boolValue == true {
                        continuation.resume(returning: nil)
                        return
                    }
                    
                    let chatDict: [String: Any] = [
                        "id": SphinxOnionManager.sharedInstance.generateCryptographicallySecureRandomInt(upperBound: Int(1e5)) as Any,
                        "owner_pubkey": groupInfo["pubkey"],
                        "name": groupInfo["name"],
                        "private": groupInfo["private"],
                        "photo_url": groupInfo["img"],
                        "unlisted": groupInfo["unlisted"],
                        "price_per_message": groupInfo["price_per_message"],
                        "escrow_amount": max(groupInfo["escrow_amount"].int ?? 3, 3)
                    ]
                    
                    continuation.resume(returning: JSON(chatDict))
                },
                errorCallback: {
                    guard !hasResumed else {
                        return
                    }
                    hasResumed = true
                    
                    continuation.resume(returning: nil)
                }
            )
        }
    }
}
