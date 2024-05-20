//
//  SphinxOnionManager+TribesExtension.swift
//  sphinx
//
//  Created by James Carucci on 1/22/24.
//  Copyright © 2024 sphinx. All rights reserved.
//

import Foundation
import Foundation
import CocoaMQTT
import ObjectMapper
import SwiftyJSON

extension SphinxOnionManager{//tribes related1
    
    func getTribePubkey()->String?{
        let tribePubkey = try? getDefaultTribeServer(state: loadOnionStateAsData())
        return tribePubkey
    }
    
    func mapChatJSON(rawTribeJSON:[String:Any])->JSON?{
        guard let name = rawTribeJSON["name"] as? String,
              let ownerPubkey = rawTribeJSON["pubkey"] as? String,
              ownerPubkey.isPubKey else{
            return nil
          }
        var chatDict = rawTribeJSON
        
        let mappedFields : [String:Any] = [
            "id":CrypterManager.sharedInstance.generateCryptographicallySecureRandomInt(upperBound: Int(1e5)) as Any,
            "owner_pubkey": ownerPubkey,
            "name" : name,
            "is_tribe_i_created":true,
            "type":Chat.ChatType.publicGroup.rawValue
            //"created_at":createdAt
        ]
        
        for key in mappedFields.keys{
            chatDict[key] = mappedFields[key]
        }
        
        let chatJSON = JSON(chatDict)
        return chatJSON
    }
    
    func getChatJSON(tribeInfo:GroupsManager.TribeInfo)->JSON?{
        var chatDict : [String:Any] = [
            "id":CrypterManager.sharedInstance.generateCryptographicallySecureRandomInt(upperBound: Int(1e5)) as Any,
            "owner_pubkey": tribeInfo.ownerPubkey as Any,
            "name" : tribeInfo.name ?? "Unknown Name",
            "private": tribeInfo.privateTribe ,
            "photo_url": tribeInfo.img ?? "",
            "unlisted": tribeInfo.unlisted,
            "price_per_message": tribeInfo.pricePerMessage ?? 0,
            "escrow_amount": max(tribeInfo.amountToStake ?? 3, 3)
        ]
        let chatJSON = JSON(chatDict)
        return chatJSON
    }
    
    func createTribe(params:[String:Any]){
        guard let seed = getAccountSeed(),
        let tribeServerPubkey = getTribePubkey() else{
            return
        }
        
        guard let tribeData = try? JSONSerialization.data(withJSONObject: params),
              let tribeJSONString = String(data: tribeData, encoding: .utf8)
               else{
            return
        }
        do{
            let rr = try sphinx.createTribe(seed: seed, uniqueTime: getTimeWithEntropy(), state: loadOnionStateAsData(), tribeServerPubkey: tribeServerPubkey, tribeJson: tribeJSONString)
            let _ = handleRunReturn(rr: rr)
        }
        catch{
            print("Handled an expected error: \(error)")
            // Crash in debug mode if the error is not expected
            #if DEBUG
            assertionFailure("Unexpected error: \(error)")
            #endif
        }
    }
    
    func joinTribe(
        tribePubkey:String,
        routeHint:String,
        joinAmountMsats:Int=1000,
        alias:String?=nil,
        isPrivate:Bool=false
    ){
        guard let seed = getAccountSeed() else{
            return
        }
        do{
            
            let rr = try sphinx.joinTribe(seed: seed, uniqueTime: getTimeWithEntropy(), state: loadOnionStateAsData(), tribePubkey: tribePubkey, tribeRouteHint: routeHint, alias: alias ?? "test", amtMsat: UInt64(joinAmountMsats), isPrivate: isPrivate)
            if(isInRemovedTribeList(ownerPubkey: tribePubkey)){
                removeFromRemovedTribesList(ownerPubkey: tribePubkey)
            }
            
            DelayPerformedHelper.performAfterDelay(seconds: 1.0, completion: {
                let _ = self.handleRunReturn(rr: rr)
            })
            
        }
        catch{
            print("Handled an expected error: \(error)")
            // Crash in debug mode if the error is not expected
            #if DEBUG
            assertionFailure("Unexpected error: \(error)")
            #endif
        }
    }
    
    func shouldAddToRemovedTribesList(chat:Chat?)->Bool{
        guard let chat = chat,
              chat.isPublicGroup() else{
            return false
        }
        return Chat.hasRemovalIndicators(chat: chat)
    }
    
    func addToRemovedTribesList(chat:Chat?){
        guard let chat = chat,
              let ownerPubkey = chat.ownerPubkey,
              chat.isPublicGroup() else{
            return
        }
        
        if var pubkeys: [String] = UserDefaults.Keys.removedTribeOwnerPubkeys.get(),
           pubkeys.filter({$0 == ownerPubkey}).count == 0{ // only add once
            pubkeys.append(ownerPubkey)
            UserDefaults.Keys.removedTribeOwnerPubkeys.set(pubkeys)
        }
        else{
            UserDefaults.Keys.removedTribeOwnerPubkeys.set([ownerPubkey])
        }
    }
    
    func removeFromRemovedTribesList(ownerPubkey:String){
        if var pubkeys: [String] = UserDefaults.Keys.removedTribeOwnerPubkeys.get(){ // only add once
            let newArray = pubkeys.filter({$0 != ownerPubkey})
            UserDefaults.Keys.removedTribeOwnerPubkeys.set(newArray)
        }
    }
    
    func isInRemovedTribeList(ownerPubkey:String?)->Bool{
        guard let ownerPubkey = ownerPubkey else{
            return false
        }
        
        if let pubkeys: [String] = UserDefaults.Keys.removedTribeOwnerPubkeys.get(){
            return pubkeys.contains(ownerPubkey)
        }
        
        return false
    }
    
    func extractHostAndTribeIdentifier(from urlString: String)->(String,String)? {
        guard let url = URL(string: urlString) else {
            print("Invalid URL")
            return nil
        }
        
        guard let host = url.host,
              let port = url.port else {
            print("URL does not have a host")
            return nil
        }
        
        let pathComponents = url.pathComponents
        guard let tribeIdentifier = pathComponents.last, tribeIdentifier != "/" else {
            print("URL does not have a tribe identifier")
            return nil
        }
        
        print("Host: \(host)")
        print("Tribe Identifier: \(tribeIdentifier)")
        return ("\(host):\(port)",tribeIdentifier)
    }
    
    func joinInitialTribe(){
        guard let tribeURL = self.stashedInitialTribe,
        let (host, pubkey) = extractHostAndTribeIdentifier(from: tribeURL) else{
            return
        }
        GroupsManager.sharedInstance.fetchTribeInfo(
            host: host,
            uuid: pubkey,
            useSSL: false,
            completion: { groupInfo in
                let qrString = "action=tribeV2&pubkey=\(pubkey)&host=\(host)"
                var tribeInfo = GroupsManager.TribeInfo(ownerPubkey:pubkey, host: host,uuid: pubkey)
                self.stashedInitialTribe = nil
                GroupsManager.sharedInstance.update(tribeInfo: &tribeInfo, from: groupInfo)
                GroupsManager.sharedInstance.finalizeTribeJoin(tribeInfo: tribeInfo, qrString: qrString)
                
            },
            errorCallback: {}
        )
    }
    
    func exitTribe(tribeChat:Chat){
        let _ = self.sendMessage(
            to: nil,
            content: "",
            chat: tribeChat,
            msgType: UInt8(TransactionMessage.TransactionMessageType.groupLeave.rawValue),
            threadUUID: nil,
            replyUUID: nil
        )
        addToRemovedTribesList(chat: tribeChat)
    }
    
    func getTribeMembers(
        tribeChat:Chat,
        completion: (([String:AnyObject]) ->())?
    ){
        guard let seed = getAccountSeed(),
        let tribeServerPubkey = getTribePubkey() else{
            return
        }
        do{
            let rr = try listTribeMembers(seed: seed, uniqueTime: getTimeWithEntropy(), state: loadOnionStateAsData(), tribeServerPubkey: tribeServerPubkey, tribePubkey: tribeChat.ownerPubkey ?? "")
            stashedCallback = completion
            let _ = handleRunReturn(rr: rr)
        }
        catch{
            print("Handled an expected error: \(error)")
            // Crash in debug mode if the error is not expected
            #if DEBUG
            assertionFailure("Unexpected error: \(error)")
            #endif
        }
    }
    
    func kickTribeMember(pubkey:String, chat:Chat){
        guard let tribeServerPubkey = getTribePubkey() else{
            return
        }
        let _ = sendMessage(to: nil, content: pubkey, chat: chat, msgType: UInt8(TransactionMessage.TransactionMessageType.groupKick.rawValue), recipPubkey: tribeServerPubkey, threadUUID: nil, replyUUID: nil,tribeKickMember: pubkey)
    }
    
    func approveOrRejectTribeJoinRequest(
        requestUuid:String,
        chat: Chat,
        type: TransactionMessage.TransactionMessageType
    ){
        guard let tribeServerPubkey = getTribePubkey() else{
            return
        }
        if (type.rawValue == TransactionMessage.TransactionMessageType.memberApprove.rawValue ||
            type.rawValue == TransactionMessage.TransactionMessageType.memberReject.rawValue) == false{
            return
        }
        let _ = sendMessage(to: nil, content: "", chat: chat, msgType: UInt8(type.rawValue), recipPubkey: tribeServerPubkey, threadUUID: nil, replyUUID: requestUuid)
    }
    
    
    
    func deleteTribe(tribeChat:Chat){
        guard let tribeServerPubkey = getTribePubkey() else{
            return
        }
        let _ = sendMessage(to: nil, content: "", chat: tribeChat, msgType: UInt8(TransactionMessage.TransactionMessageType.groupDelete.rawValue), recipPubkey: tribeServerPubkey, threadUUID: nil, replyUUID: nil)
        
        addToRemovedTribesList(chat: tribeChat)
    }
    
    
}
