//
//  SphinxOnionManager+StructsAndHelpersExtension.swift
//  sphinx
//
//  Created by Tomas Timinskas on 23/05/2024.
//  Copyright © 2024 sphinx. All rights reserved.
//

import Foundation
import ObjectMapper
import SwiftyJSON

//MARK: Helper Structs & Functions:

struct SphinxOnionBrokerResponse: Mappable {
    var scid: String?
    var serverPubkey: String?
    var myPubkey: String?

    init?(map: Map) {}

    mutating func mapping(map: Map) {
        scid <- map["scid"]
        serverPubkey <- map["server_pubkey"]
    }
}

enum SphinxMsgError: Error {
    case encodingError
    case credentialsError //can't get access to my Private Keys/other data!
    case contactDataError // not enough data about contact!
}

struct ContactServerResponse: Mappable {
    var pubkey: String?
    var alias: String?
    var host:String?
    var photoUrl: String?
    var person: String?
    var code: String?
    var role: Int?
    var fullContactInfo: String?
    var recipientAlias: String?
    var confirmed: Bool?

    init?(map: Map) {}

    mutating func mapping(map: Map) {
        pubkey          <- map["pubkey"]
        alias           <- map["alias"]
        photoUrl        <- map["photo_url"]
        person          <- map["person"]
        code            <- map["code"]
        host            <- map["host"]
        role            <- map["role"]
        fullContactInfo <- map["fullContactInfo"]
        recipientAlias  <- map["recipientAlias"]
        confirmed       <- map["confirmed"]
    }
    
    func isTribeMessage() -> Bool {
        if let _ = role {
            return true
        }
        return false
    }
}

struct MessageInnerContent: Mappable {
    var content: String?
    var replyUuid: String? = nil
    var threadUuid: String? = nil
    var mediaKey: String? = nil
    var mediaToken: String? = nil
    var mediaType: String? = nil
    var muid: String? = nil
    var originalUuid: String? = nil
    var date: Int? = nil
    var invoice: String? = nil
    var paymentHash: String? = nil
    var amount: Int? = nil
    var fullContactInfo: String? = nil
    var recipientAlias: String? = nil

    init?(map: Map) {}
    
    mutating func mapping(map: Map) {
        content         <- map["content"]
        replyUuid       <- map["replyUuid"]
        threadUuid      <- map["threadUuid"]
        mediaToken      <- map["mediaToken"]
        mediaType       <- map["mediaType"]
        mediaKey        <- map["mediaKey"]
        muid            <- map["muid"]
        date            <- map["date"]
        originalUuid    <- map["originalUuid"]
        invoice         <- map["invoice"]
        paymentHash     <- map["paymentHash"]
        amount          <- map["amount"]
        fullContactInfo <- map["fullContactInfo"]
        recipientAlias  <- map["recipientAlias"]
    }
    
}


struct GenericIncomingMessage: Mappable {
    var content: String?
    var amount: Int?
    var senderPubkey: String? = nil
    var uuid: String? = nil
    var originalUuid: String? = nil
    var index: String? = nil
    var replyUuid: String? = nil
    var threadUuid: String? = nil
    var mediaKey: String? = nil
    var mediaToken: String? = nil
    var mediaType: String? = nil
    var muid: String? = nil
    var timestamp: Int? = nil
    var invoice: String? = nil
    var paymentHash: String? = nil
    var alias: String? = nil
    var fullContactInfo: String? = nil
    var photoUrl: String? = nil

    init?(map: Map) {}
    
    init(msg: Msg) {
        
        if let fromMe = msg.fromMe, fromMe == true, let sentTo = msg.sentTo {
            self.senderPubkey = sentTo
        } else if let sender = msg.sender, let csr = ContactServerResponse(JSONString: sender) {
            self.senderPubkey = csr.pubkey
            self.photoUrl = csr.photoUrl
            self.alias = csr.alias
        }
        
        var innerContentAmount : UInt64? = nil
        
        if let message = msg.message,
           let innerContent = MessageInnerContent(JSONString: message)
        {
            self.content = innerContent.content
            self.replyUuid = innerContent.replyUuid
            self.threadUuid = innerContent.threadUuid
            self.mediaKey = innerContent.mediaKey
            self.mediaToken = innerContent.mediaToken
            self.mediaType = innerContent.mediaType
            self.muid = innerContent.muid
            self.originalUuid = innerContent.originalUuid
            self.invoice = innerContent.invoice
            self.paymentHash = innerContent.paymentHash
            
            innerContentAmount = UInt64(innerContent.amount ?? 0)
            
            if msg.type == UInt8(TransactionMessage.TransactionMessageType.unknown.rawValue) {
                self.alias = innerContent.recipientAlias
                self.fullContactInfo = innerContent.fullContactInfo
            }
            
            let isTribe = SphinxOnionManager.sharedInstance.isTribeMessage(senderPubkey: senderPubkey ?? "")
            
            if let timestamp = msg.timestamp, isTribe == false {
                self.timestamp = Int(timestamp)
            } else {
                self.timestamp = innerContent.date
            }
        }
        
        if let invoice = self.invoice {
            let prd = PaymentRequestDecoder()
            prd.decodePaymentRequest(paymentRequest: invoice)
            
            let amount = prd.getAmount() ?? 0
            self.amount = amount * 1000 // convert to msat
        } else {
            self.amount = (msg.fromMe == true) ? Int((innerContentAmount) ?? 0) : Int((msg.msat ?? innerContentAmount) ?? 0)
        }
        
        self.uuid = msg.uuid
        self.index = msg.index
    }

    mutating func mapping(map: Map) {
        content    <- map["content"]
        amount     <- map["amount"]
        replyUuid  <- map["replyUuid"]
        threadUuid <- map["threadUuid"]
        mediaToken <- map["mediaToken"]
        mediaType  <- map["mediaType"]
        mediaKey   <- map["mediaKey"]
        muid       <- map["muid"]
        
    }
    
}

struct TribeMembersRRObject: Mappable {
    var pubkey: String? = nil
    var routeHint: String? = nil
    var alias: String? = nil
    var contactKey: String? = nil
    var is_owner: Bool = false
    var status: String? = nil

    init?(map: Map) {}

    mutating func mapping(map: Map) {
        pubkey       <- map["pubkey"]
        alias        <- map["alias"]
        routeHint    <- map["route_hint"]
        contactKey   <- map["contact_key"]
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

extension SphinxOnionManager {
    func timestampToDate(
        timestamp: UInt64
    ) -> Date? {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000)
        return date
    }
    
    func timestampToInt(
        timestamp: UInt64
    ) -> Int? {
        let dateInSeconds = Double(timestamp) / 1000.0
        return Int(dateInSeconds)
    }


    func isGroupAction(
        type: UInt8
    ) -> Bool {
        let intType = Int(type)
        return intType == TransactionMessage.TransactionMessageType.groupJoin.rawValue ||
                intType == TransactionMessage.TransactionMessageType.groupLeave.rawValue ||
                intType == TransactionMessage.TransactionMessageType.groupKick.rawValue ||
                intType == TransactionMessage.TransactionMessageType.groupDelete.rawValue ||
                intType == TransactionMessage.TransactionMessageType.memberRequest.rawValue ||
                intType == TransactionMessage.TransactionMessageType.memberApprove.rawValue ||
                intType == TransactionMessage.TransactionMessageType.memberReject.rawValue
    }
    
    func isBoostOrPayment(
        type: UInt8
    ) -> Bool {
        let intType = Int(type)
        return intType == TransactionMessage.TransactionMessageType.boost.rawValue ||
                intType == TransactionMessage.TransactionMessageType.directPayment.rawValue ||
                intType == TransactionMessage.TransactionMessageType.payment.rawValue
    }
    
    func isMessageCallOrAttachment(
        type: UInt8
    ) -> Bool {
        let intType = Int(type)
        return intType == TransactionMessage.TransactionMessageType.message.rawValue ||
                intType == TransactionMessage.TransactionMessageType.call.rawValue ||
                intType == TransactionMessage.TransactionMessageType.attachment.rawValue
    }
    
    func isDelete(
        type: UInt8
    ) -> Bool {
        let intType = Int(type)
        return intType == TransactionMessage.TransactionMessageType.delete.rawValue
    }
    
    func isInvoice(
        type: UInt8
    ) -> Bool {
        let intType = Int(type)
        return intType == TransactionMessage.TransactionMessageType.invoice.rawValue
    }
        

    func isMyMessageNeedingIndexUpdate(msg: Msg) -> Bool {
        if let _ = msg.uuid,
           let _ = msg.index {
            return true
        }
        return false
    }
}