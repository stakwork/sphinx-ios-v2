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

///tribes related1
extension SphinxOnionManager {
    
    func getTribePubkey() -> String? {
        let tribePubkey = try? getDefaultTribeServer(state: loadOnionStateAsData())
        return tribePubkey
    }
    
    func createTribe(
        params: [String: Any],
        callback: @escaping (String) -> ()
    ) {
        guard let seed = getAccountSeed(),
              let tribeServerPubkey = getTribePubkey() else
        {
            return
        }
        
        guard let tribeData = try? JSONSerialization.data(withJSONObject: params),
              let tribeJSONString = String(data: tribeData, encoding: .utf8) else
        {
            return
        }
        
        self.createTribeCallback = callback
        
        do {
            let rr = try sphinx.createTribe(
                seed: seed,
                uniqueTime: getTimeWithEntropy(),
                state: loadOnionStateAsData(),
                tribeServerPubkey: tribeServerPubkey,
                tribeJson: tribeJSONString
            )
            let _ = handleRunReturn(rr: rr)
        } catch {
            self.createTribeCallback = nil
            print("Error creating tribe")
        }
    }
    
    func joinTribe(
        tribePubkey: String,
        routeHint: String,
        joinAmountMsats: Int = 1000,
        alias: String? = nil,
        isPrivate: Bool = false
    ){
        guard let seed = getAccountSeed() else{
            return
        }
        do {
            
            let rr = try sphinx.joinTribe(
                seed: seed,
                uniqueTime: getTimeWithEntropy(),
                state: loadOnionStateAsData(),
                tribePubkey: tribePubkey,
                tribeRouteHint: routeHint,
                alias: alias ?? "test",
                amtMsat: UInt64(joinAmountMsats),
                isPrivate: isPrivate
            )
            
            removeDeletedTribePubKey(tribeOwnerPubKey: tribePubkey)
            
            DelayPerformedHelper.performAfterDelay(seconds: 1.0, completion: {
                let _ = self.handleRunReturn(rr: rr)
            })
            
        } catch {}
    }
    
    func extractHostAndTribeIdentifier(from urlString: String) -> (String, String)? {
        guard let url = URL(string: urlString) else {
            print("Invalid URL")
            return nil
        }
        
        guard let host = url.host else {
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
        
        if let port = url.port {
            return ("\(host):\(port)", tribeIdentifier)
        } else {
            return ("\(host)", tribeIdentifier)
        }
    }
    
    func joinInitialTribe() {
        guard let tribeURL = self.stashedInitialTribe,
              let (host, pubkey) = extractHostAndTribeIdentifier(from: tribeURL) else
        {
            return
        }
        
        GroupsManager.sharedInstance.fetchTribeInfo(
            host: host,
            uuid: pubkey,
            useSSL: false,
            completion: { groupInfo in
                if groupInfo["deleted"].boolValue == true {
                    return
                }
                
                let qrString = "action=tribeV2&pubkey=\(pubkey)&host=\(host)"
                var tribeInfo = GroupsManager.TribeInfo(ownerPubkey: pubkey, host: host, uuid: pubkey)
                self.stashedInitialTribe = nil
                
                GroupsManager.sharedInstance.update(tribeInfo: &tribeInfo, from: groupInfo)
                GroupsManager.sharedInstance.finalizeTribeJoin(tribeInfo: tribeInfo, qrString: qrString)
                
            },
            errorCallback: {}
        )
    }
    
    func exitTribe(tribeChat: Chat) {
        let _ = self.sendMessage(
            to: nil,
            content: "",
            chat: tribeChat,
            provisionalMessage: nil,
            msgType: UInt8(TransactionMessage.TransactionMessageType.groupLeave.rawValue),
            threadUUID: nil,
            replyUUID: nil
        )
        
        if let ownerPubKey = tribeChat.ownerPubkey {
            addDeletedTribePubKey(tribeOwnerPubKey: ownerPubKey)
        }
    }
    
    func getTribeMembers(
        tribeChat: Chat,
        completion: (([String:AnyObject]) ->())?
    ){
        guard let seed = getAccountSeed(),
              let tribeServerPubkey = getTribePubkey() else
        {
            return
        }
        do {
            let rr = try sphinx.listTribeMembers(
                seed: seed,
                uniqueTime: getTimeWithEntropy(),
                state: loadOnionStateAsData(),
                tribeServerPubkey: tribeServerPubkey,
                tribePubkey: tribeChat.ownerPubkey ?? ""
            )
            tribeMembersCallback = completion
            let _ = handleRunReturn(rr: rr)
        } catch {}
    }
    
    func kickTribeMember(pubkey:String, chat:Chat){
        let _ = sendMessage(
            to: nil,
            content: "",
            chat: chat,
            provisionalMessage: nil,
            msgType: UInt8(TransactionMessage.TransactionMessageType.groupKick.rawValue),
            threadUUID: nil,
            replyUUID: nil,
            tribeKickMember: pubkey
        )
    }
    
    func approveOrRejectTribeJoinRequest(
        requestUuid: String,
        chat: Chat,
        type: TransactionMessage.TransactionMessageType
    ){
        if (
            type.rawValue != TransactionMessage.TransactionMessageType.memberApprove.rawValue &&
            type.rawValue != TransactionMessage.TransactionMessageType.memberReject.rawValue
        ) {
            return
        }
        
        let _ = sendMessage(
            to: nil,
            content: "",
            chat: chat,
            provisionalMessage: nil,
            msgType: UInt8(type.rawValue),
            threadUUID: nil,
            replyUUID: requestUuid
        )
    }
    
    func updateTribe(
        params: [String: AnyObject],
        pubkey: String
    ) -> Bool {
        var finalParams = params
        finalParams["pubkey"] = pubkey as AnyObject

        guard let seed = getAccountSeed(),
              let tribeServerPubkey = getTribePubkey(),
              let tribeData = try? JSONSerialization.data(withJSONObject: finalParams),
              let tribeJSONString = String(data: tribeData, encoding: .utf8) else 
        {
            return false
        }

        do {
            let rr = try sphinx.updateTribe(
                seed: seed,
                uniqueTime: getTimeWithEntropy(),
                state: loadOnionStateAsData(),
                tribeServerPubkey: tribeServerPubkey,
                tribeJson: tribeJSONString
            )
            
            let _ = handleRunReturn(rr: rr)
            return true
        } catch {
            print("Error updating tribe")
            return false
        }
    }

    
    func deleteTribe(tribeChat: Chat) {
        let _ = sendMessage(
            to: nil,
            content: "",
            chat: tribeChat,
            provisionalMessage: nil,
            msgType: UInt8(TransactionMessage.TransactionMessageType.groupDelete.rawValue),
            threadUUID: nil,
            replyUUID: nil
        )
    }
    
    func mapChatJSON(
        rawTribeJSON: [String: Any]
    ) -> JSON? {
        guard let name = rawTribeJSON["name"] as? String,
              let ownerPubkey = rawTribeJSON["pubkey"] as? String,
              ownerPubkey.isPubKey else
        {
            return nil
        }
        var chatDict = rawTribeJSON
        
        let mappedFields : [String:Any] = [
            "id": CrypterManager.sharedInstance.generateCryptographicallySecureRandomInt(upperBound: Int(1e5)) as Any,
            "owner_pubkey": ownerPubkey,
            "name" : name,
            "is_tribe_i_created": true,
            "type": Chat.ChatType.publicGroup.rawValue
        ]
        
        for key in mappedFields.keys {
            chatDict[key] = mappedFields[key]
        }
        
        let chatJSON = JSON(chatDict)
        return chatJSON
    }
    
    func addDeletedTribePubKey(
        tribeOwnerPubKey: String
    ) {
        var existingDeletedTribePubKeys = deletedTribesPubKeys
        if !existingDeletedTribePubKeys.contains(tribeOwnerPubKey) {
            existingDeletedTribePubKeys.append(tribeOwnerPubKey)
        }
        deletedTribesPubKeys = existingDeletedTribePubKeys
    }
    
    func removeDeletedTribePubKey(
        tribeOwnerPubKey: String
    ) {
        var existingDeletedTribePubKeys = deletedTribesPubKeys
        
        if existingDeletedTribePubKeys.contains(tribeOwnerPubKey) {
            existingDeletedTribePubKeys = existingDeletedTribePubKeys.filter({ $0 != tribeOwnerPubKey })
            deletedTribesPubKeys = existingDeletedTribePubKeys
        }
    }

}
