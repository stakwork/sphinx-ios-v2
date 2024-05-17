//
//  SphinxOnionManager+HandleStateExtension.swift
//  sphinx
//
//  Created by James Carucci on 12/19/23.
//  Copyright © 2023 sphinx. All rights reserved.
//

import Foundation
import MessagePack
import CocoaMQTT
import ObjectMapper
import SwiftyJSON
import Foundation


extension SphinxOnionManager {
    func handleRunReturn(
        rr: RunReturn,
        publishDelay:Double=0.5,
        completion: (([String:AnyObject]) ->())? = nil,
        isMessageSend:Bool=false
    )-> String? {
        var messageTagID : String? = nil
        print("handleRR rr:\(rr)")
        if let sm = rr.stateMp{
            //update state map
            let _ = storeOnionState(inc: sm.bytes)
        }
        
        if let newTribe = rr.newTribe{
            print(newTribe)
            NotificationCenter.default.post(name: .newTribeCreationComplete, object: nil, userInfo: ["tribeJSON" : newTribe])
        }
        
        DelayPerformedHelper.performAfterDelay(seconds: publishDelay, completion: {
            for i in 0..<rr.topics.count{
                self.pushRRTopic(topic: rr.topics[i], payloadData: rr.payloads[i])
            }
        })
        
        
        if let mci = rr.myContactInfo{
            let components = mci.split(separator: "_").map({String($0)})
            if let components = parseContactInfoString(fullContactInfo: mci),
               UserContact.getContactWithDisregardStatus(pubkey: components.0) == nil{//only add this if we don't already have a "self" contact
                createSelfContact(scid: components.2, serverPubkey: components.1,myOkKey: components.0)                
            }
        }
        
        if let balance = rr.newBalance{
            UserData.sharedInstance.save(balance: balance)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01, execute: {
                NotificationCenter.default.post(Notification(name: .onBalanceDidChange, object: nil, userInfo: ["balance" : balance]))
            })
        }
        
        processKeyExchangeMessages(rr: rr)
        
        processGenericMessages(rr: rr)
                
        
        
        // Assuming 'rr.tribeMembers' is a JSON string similar to the 'po map.JSON' output you've shown
        if let tribeMembersString = rr.tribeMembers,
           let jsonData = tribeMembersString.data(using: .utf8),
           let jsonDict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
            
            var confirmedMembers: [TribeMembersRRObject] = []
            var pendingMembers: [TribeMembersRRObject] = []
            
            // Parse confirmed members
            if let confirmedArray = jsonDict?["confirmed"] as? [[String: Any]] {
                confirmedMembers = confirmedArray.compactMap { Mapper<TribeMembersRRObject>().map(JSONObject: $0) }
            }
            
            // Parse pending members (assuming a similar structure for actual pending members)
            if let pendingArray = jsonDict?["pending"] as? [[String: Any]] {
                pendingMembers = pendingArray.compactMap { Mapper<TribeMembersRRObject>().map(JSONObject: $0) }
            }
            
            // Assuming 'stashedCallback' expects a dictionary with confirmed and pending members
            if let completion = stashedCallback {
                completion(["confirmedMembers": confirmedMembers as AnyObject, "pendingMembers": pendingMembers as AnyObject])
                stashedCallback = nil
            }
        }
        
        
        if let sentStatus = rr.sentStatus {
            print(sentStatus)
            // Assuming sentStatus is a JSON string, convert it to a dictionary
            if let data = sentStatus.data(using: .utf8) {
                do {
                    // Decode the JSON string into a dictionary
                    if let dictionary = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any?] {
                        // Check if payment_hash exists and is not nil
                        if let paymentHash = dictionary["payment_hash"] as? String, !paymentHash.isEmpty,
                           let preimage = dictionary["preimage"] as? String,
                            !preimage.isEmpty{
                            // Post to the notification center
                            NotificationCenter.default.post(name: .invoiceIPaidSettled, object: nil, userInfo: dictionary)
                        }
                    }
                } catch {
                    print("Error decoding JSON: \(error)")
                }
            }
        }
        
        if let settledStatus = rr.settledStatus{
            print("settledStatus:\(rr.settledStatus)")
        }
        
        if let error = rr.error {
            
        }
        
        if let msgsTotalsJSON = rr.msgsCounts,
           let msgTotals = MsgTotalCounts(JSONString: msgsTotalsJSON) {
            print(msgTotals) // Now you have your model populated with the JSON data
            self.msgTotalCounts = msgTotals
            NotificationCenter.default.post(name: .totalMessageCountReceived, object: nil)
        }
        
        if let newInvite = rr.newInvite,
           rr.msgs.count > 0,
           let tag = rr.msgs[0].tag{
            self.pendingInviteLookupByTag[tag] = newInvite // if it's a new invite stash it
        }
        else if let sentStatusJSON = rr.sentStatus,
                let sentStatus = SentStatus(JSONString: sentStatusJSON){
            processInvitePurchaseAcks(sentStatus: sentStatus) //if it's not a new invite, allow us to process the tags to find invite acks
        }
        
        handleIncomingTags(rr: rr)
        
        processReadStatus(rr: rr)
        
        processMuteLevels(rr: rr)
        
        if isMessageSend,
           rr.msgs.count > 0,
           let tag = rr.msgs[0].tag{
            messageTagID = tag
        }

        purgeObsoleteState(keys: rr.stateToDelete)
        
        return messageTagID
    }
    
    func processReadStatus(rr:RunReturn){
        if let lastRead = rr.lastRead{
            print(lastRead)
            let lastReadIds = extractLastReadIds(jsonString: lastRead)
            print(lastReadIds)
            var chatListUnreadDict = [Int:Int]()
            for lastReadId in lastReadIds{
                if let message = TransactionMessage.getMessageWith(id: lastReadId),
                   let chat = message.chat{
                    if let existingLastReadForChat = chatListUnreadDict[chat.id], lastReadId > existingLastReadForChat {
                        // Update the last read message ID if the new ID is greater than the existing one
                        chatListUnreadDict[chat.id] = lastReadId
                    } else if !chatListUnreadDict.keys.contains(chat.id) {
                        // Add the chat ID to the dictionary if it's not already there
                        chatListUnreadDict[chat.id] = lastReadId
                    }
                }
            }
            
            updateChatReadStatus(chatListUnreadDict: chatListUnreadDict)
        }
    }
    
    func processMuteLevels(rr:RunReturn){
        if let muteLevels = rr.muteLevels{
            let muteDict = extractMuteIds(jsonString: muteLevels)
            updateMuteLevels(pubkeyToMuteLevelDict: muteDict)
        }
    }
    
    func updateChatReadStatus(chatListUnreadDict: [Int: Int]) {
        for (chatId, lastReadId) in chatListUnreadDict {
            Chat.updateMessageReadStatus(chatId: chatId, lastReadId: lastReadId)
        }
    }
    
    func updateMuteLevels(pubkeyToMuteLevelDict: [String:Any]){
        for (pubkey, muteLevel) in pubkeyToMuteLevelDict{
            let chat = UserContact.getContactWith(pubkey: pubkey)?.getChat() ?? Chat.getTribeChatWithOwnerPubkey(ownerPubkey: pubkey)
            if let level = muteLevel as? Int,
               (chat?.notify ?? -1) != level{
                chat?.notify = level
                chat?.managedObjectContext?.saveContext()
            }
        }
    }

    
    func extractLastReadIds(jsonString:String)->[Int]{
        if let jsonData = jsonString.data(using: .utf8) {
            do {
                // Parse the JSON data into a dictionary
                if let jsonDict = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
                    // Collect all values
                    let values = jsonDict.values.compactMap({ $0 as? Int })
                    return values
                }
            } catch {
                print("Error parsing JSON: \(error)")
            }
        } else {
            print("Error creating Data from jsonString")
        }
        
        return []
    }
    
    func extractMuteIds(jsonString:String)->[String:Any]{
        if let jsonData = jsonString.data(using: .utf8) {
            do {
                // Parse the JSON data into a dictionary
                if let jsonDict = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
                    // Collect all values
                    let values = jsonDict
                    return values
                }
            } catch {
                print("Error parsing JSON: \(error)")
            }
        } else {
            print("Error creating Data from jsonString")
        }
        
        return [:]
    }
    
    func handleIncomingTags(rr:RunReturn){
        if let sentStatusJSON = rr.sentStatus,
           let sentStatus = SentStatus(JSONString: sentStatusJSON),
            let tag = sentStatus.tag,
           var cachedMessage = TransactionMessage.getMessageWith(tag: tag){
            print("SENT STATUS FOUND:\(sentStatus)")
            if(sentStatus.status == "COMPLETE") && cachedMessage.status != TransactionMessage.TransactionMessageStatus.deleted.rawValue{
                 cachedMessage.status = TransactionMessage.TransactionMessageStatus.received.rawValue
            }
            else if(sentStatus.status == "FAILED"){
                cachedMessage.status = TransactionMessage.TransactionMessageStatus.failed.rawValue
            }
        }
    }
    
    func processInvitePurchaseAcks(sentStatus:SentStatus){
        guard let tag = sentStatus.tag else{
            return
        }
        if pendingInviteLookupByTag.keys.contains(tag){
            let inviteCode = sentStatus.status != "COMPLETE" ? (nil) : (pendingInviteLookupByTag[tag])
            NotificationCenter.default.post(name: .inviteCodeAckReceived,object:nil, userInfo: ["inviteCode": inviteCode])
            pendingInviteLookupByTag.removeValue(forKey: tag)
        }
        
    }

    func pushRRTopic(topic:String,payloadData:Data?){
        let byteArray: [UInt8] = payloadData != nil ? [UInt8](payloadData!) : [UInt8]()
        print("pushRRTopic | topic:\(topic) | payload:\(byteArray)")
        self.mqtt.publish(
            CocoaMQTTMessage(
                topic: topic,
                payload: byteArray
            )
        )
    }
    
    func timestampToDate(timestamp:UInt64)->Date?{
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000)
        return date
    }
    
    func timestampToInt(timestamp: UInt64) -> Int? {
        let dateInSeconds = Double(timestamp) / 1000.0
        return Int(dateInSeconds)
    }


    func isGroupAction(type:UInt8)->Bool{
        let throwAwayMessage = TransactionMessage(context: managedContext)
        throwAwayMessage.type = Int(type)
        return throwAwayMessage.isGroupActionMessage()
    }
        

    func isMyMessageNeedingIndexUpdate(msg:Msg)->Bool{
        if let _ = msg.uuid,
           let _ = msg.index{
            return true
        }
        return false
    }

    var mutationKeys: [String] {
        get {
            if let onionState: String = UserDefaults.Keys.onionState.get() {
                return onionState.components(separatedBy: ",")
            }
            return []
        }
        set {
            UserDefaults.Keys.onionState.set(
                newValue.joined(separator: ",")
            )
        }
    }
    
    func loadOnionStateAsData() -> Data {
        let state = loadOnionState()
        
        var mpDic = [MessagePackValue:MessagePackValue]()

        for (key, value) in state {
            mpDic[MessagePackValue(key)] = MessagePackValue(Data(value))
        }
        
        let stateBytes = pack(
            MessagePackValue(mpDic)
        ).bytes
        
        return Data(stateBytes)
    }

    private func loadOnionState() -> [String: [UInt8]] {
        var state:[String: [UInt8]] = [:]
        
        for key in mutationKeys {
            if let value = UserDefaults.standard.object(forKey: key) as? [UInt8] {
                state[key] = value
            }
        }
        return state
    }
    
    func deleteContactFromState(pubkey: String) {
        // This is the key where contact information is stored. Ensure it matches how keys are stored in your UserDefaults.
        let contactDictKey = "c/" + pubkey

        // Load the current onion state from UserDefaults
        var state = loadOnionState()

        // Check if the contact's data exists
        if state[contactDictKey] != nil {
            print("Removing contact with pubkey:", pubkey)
            
            // Remove the contact data
            state.removeValue(forKey: contactDictKey)
            
            // Save the updated state back to UserDefaults
            saveUpdatedOnionState(state: state)
        } else {
            print("No contact found with the specified pubkey:", pubkey)
        }
    }

    private func saveUpdatedOnionState(state: [String: [UInt8]]) {
        for key in state.keys {
            if let value = state[key] {
                // Save each key-value pair to UserDefaults
                UserDefaults.standard.set(value, forKey: key)
            } else {
                // If the value is nil, remove the key from UserDefaults
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        UserDefaults.standard.synchronize() // Ensure UserDefaults is synchronized
        
        // Update the local cache of keys
        updateMutationKeys(with: state.keys.sorted())
    }

    private func updateMutationKeys(with keys: [String]) {
        // Store the new keys in UserDefaults to keep track of what's stored
        mutationKeys = keys
    }
    

    func storeOnionState(inc: [UInt8]) -> [NSNumber] {
        let muts = try? unpack(Data(inc))
        
        guard let mutsDictionary = (muts?.value as? MessagePackValue)?.dictionaryValue else {
            return []
        }
        
        persist_muts(muts: mutsDictionary)

        return []
    }

    private func persist_muts(muts: [MessagePackValue: MessagePackValue]) {
        var keys: [String] = []
        
        for  mut in muts {
            if let key = mut.key.stringValue, let value = mut.value.dataValue?.bytes {
                keys.append(key)
                UserDefaults.standard.removeObject(forKey: key)
                UserDefaults.standard.synchronize()
                UserDefaults.standard.set(value, forKey: key)
                UserDefaults.standard.synchronize()
            }
        }
        
        keys.append(contentsOf: mutationKeys)
        mutationKeys = keys
    }
    
    func purgeObsoleteState(keys:[String]){
        for key in keys{
            UserDefaults.standard.removeObject(forKey: key)
            UserDefaults.standard.synchronize()
        }
    }
    

}


struct ContactServerResponse: Mappable {
    var pubkey: String?
    var alias: String?
    var host:String?
    var photoUrl: String?
    var person: String?
    var code: String?
    var role: Int?
    var fullContactInfo:String?
    var recipientAlias:String?

    init?(map: Map) {}

    mutating func mapping(map: Map) {
        pubkey    <- map["pubkey"]
        alias     <- map["alias"]
        photoUrl  <- map["photo_url"]
        person    <- map["person"]
        code <- map["code"]
        host <- map["host"]
        role <- map["role"]
        fullContactInfo <- map["fullContactInfo"]
        recipientAlias <- map["recipientAlias"]
    }
    
}



struct MessageInnerContent: Mappable {
    var content:String?
    var replyUuid:String?=nil
    var threadUuid:String?=nil
    var mediaKey:String?=nil
    var mediaToken:String?=nil
    var mediaType:String?=nil
    var muid:String?=nil
    var originalUuid:String?=nil
    var date:Int?=nil
    var invoice:String?=nil
    var paymentHash:String?=nil
    var amount:Int?=nil
    var fullContactInfo:String?=nil
    var recipientAlias:String?=nil

    init?(map: Map) {}
    
    mutating func mapping(map: Map) {
        content    <- map["content"]
        replyUuid <- map["replyUuid"]
        threadUuid <- map["threadUuid"]
        mediaToken <- map["mediaToken"]
        mediaType <- map["mediaType"]
        mediaKey <- map["mediaKey"]
        muid <- map["muid"]
        date <- map["date"]
        originalUuid <- map["originalUuid"]
        invoice <- map["invoice"]
        paymentHash <- map["paymentHash"]
        amount <- map["amount"]
        fullContactInfo <- map["fullContactInfo"]
        recipientAlias <- map["recipientAlias"]
    }
    
}


struct GenericIncomingMessage: Mappable {
    var content:String?
    var amount:Int?
    var senderPubkey:String?=nil
    var uuid:String?=nil
    var originalUuid:String?=nil
    var index:String?=nil
    var replyUuid:String?=nil
    var threadUuid:String?=nil
    var mediaKey:String?=nil
    var mediaToken:String?=nil
    var mediaType:String?=nil
    var muid:String?=nil
    var timestamp:Int?=nil
    var invoice:String?=nil
    var paymentHash:String?=nil
    var alias:String?=nil
    var fullContactInfo:String?=nil
    var photoUrl:String?=nil

    init?(map: Map) {}
    
    init(msg:Msg){
        
        if let fromMe = msg.fromMe, fromMe == true, let sentTo = msg.sentTo{
            self.senderPubkey = sentTo
        }
        else if let sender = msg.sender,
           let csr = ContactServerResponse(JSONString: sender){
            self.senderPubkey = csr.pubkey
            self.photoUrl = csr.photoUrl
            self.alias = csr.alias
        }
        
        
        var innerContentAmount : UInt64? = nil
        if let message = msg.message,
           let innerContent = MessageInnerContent(JSONString: message){
            self.content = innerContent.content
            self.replyUuid = innerContent.replyUuid
            self.threadUuid = innerContent.threadUuid
            self.mediaKey = innerContent.mediaKey
            self.mediaToken = innerContent.mediaToken
            self.mediaType = innerContent.mediaType
            self.muid = innerContent.muid
            self.originalUuid = innerContent.originalUuid
//            self.date = innerContent.date
            self.invoice = innerContent.invoice
            self.paymentHash = innerContent.paymentHash
            innerContentAmount = UInt64(innerContent.amount ?? 0)
            if msg.type == 33{
                self.alias = innerContent.recipientAlias
                self.fullContactInfo = innerContent.fullContactInfo
            }
            
            let (isTribe, _) = SphinxOnionManager.sharedInstance.isMessageTribeMessage(senderPubkey: self.senderPubkey ?? "")
            
            if let timestamp = msg.timestamp,
                isTribe == false{
                self.timestamp = Int(timestamp)
            }
            else{
                self.timestamp = innerContent.date
            }
        }
        if let invoice = self.invoice{
            print(msg)
            let prd = PaymentRequestDecoder()
            prd.decodePaymentRequest(paymentRequest: invoice)
            let amount = prd.getAmount() ?? 0
            self.amount = amount * 1000 // convert to msat
        }
        else{
            self.amount = (msg.fromMe == true) ? Int((innerContentAmount) ?? 0) : Int((msg.msat ?? innerContentAmount) ?? 0)
        }
        
        self.uuid = msg.uuid
        self.index = msg.index
    }

    mutating func mapping(map: Map) {
        content    <- map["content"]
        amount     <- map["amount"]
        replyUuid <- map["replyUuid"]
        threadUuid <- map["threadUuid"]
        mediaToken <- map["mediaToken"]
        mediaType <- map["mediaType"]
        mediaKey <- map["mediaKey"]
        muid <- map["muid"]
        
    }
    
}

struct TribeMembersRRObject: Mappable {
    var pubkey:String? = nil
    var routeHint:String? = nil
    var alias:String? = nil
    var contactKey:String? = nil
    var is_owner: Bool = false
    var status:String? = nil

    init?(map: Map) {}

    mutating func mapping(map: Map) {
        pubkey    <- map["pubkey"]
        alias    <- map["alias"]
        routeHint    <- map["route_hint"]
        contactKey    <- map["contact_key"]
    }
    
}


class SentStatus: Mappable {
    var tag: String?
    var status: String?
    var preimage: String?
    var paymentHash: String?

    required init?(map: Map) {
    }

    func mapping(map: Map) {
        tag         <- map["tag"]
        status      <- map["status"]
        preimage    <- map["preimage"]
        paymentHash <- map["payment_hash"]
    }
}


