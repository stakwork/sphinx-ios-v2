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

var wordsListPossibilities : [WordList] = [
    .english,
    .japanese,
    .korean,
    .spanish,
    .simplifiedChinese,
    .traditionalChinese,
    .french,
    .italian
]

func localizedString(_ key: String) -> String {
    return NSLocalizedString(key, comment: "")
}

enum SeedValidationError: Error {
    case incorrectWordNumber
    case invalidWord
    
    var localizedDescription: String {
        switch self {
        case .incorrectWordNumber:
            return localizedString("profile.mnemonic-incorrect-length")
        case .invalidWord:
            return localizedString("profile.mnemonic-invalid-word")
        }
    }
}

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
    var routeHint:String?
    var fullContactInfo: String?
    var recipientAlias: String?
    var confirmed: Bool?

    init?(map: Map) {}

    mutating func mapping(map: Map) {
        pubkey          <- map["pubkey"]
        alias           <- map["alias"]
        routeHint       <- map["route_hint"]
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
    var metadata: String? = nil

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
        metadata        <- map["metadata"]
    }
    
    func getRouteHint() -> String? {
        if let contactInfo = self.fullContactInfo, let (_, recipLspPubkey, scid) = contactInfo.parseContactInfoString() {
            return "\(recipLspPubkey)_\(scid)"
        }
        return nil
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
    var tag: String? = nil
    var tz: String? = nil
    

    init?(map: Map) {}
    
    init(
        msg: Msg,
        csr: ContactServerResponse?,
        innerContent: MessageInnerContent?,
        isTribeMessage: Bool
    ) {
        if let csr = csr {
            if let fromMe = msg.fromMe, fromMe == true, let sentTo = msg.sentTo {
                self.senderPubkey = sentTo
            } else {
                self.senderPubkey = csr.pubkey
            }
            self.photoUrl = csr.photoUrl
            self.alias = csr.alias
        }
        
        var innerContentAmount : UInt64? = nil
        
        if let innerContent = innerContent {
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
            
//            let isTribe = SphinxOnionManager.sharedInstance.isTribeMessage(senderPubkey: senderPubkey ?? "")
            let isTribe = isTribeMessage
            
            if let timestamp = msg.timestamp, isTribe == false {
                self.timestamp = Int(timestamp)
            } else {
                self.timestamp = innerContent.date
            }
            
            if let metadataString = innerContent.metadata,
               let metadataData = metadataString.data(using: .utf8) {
                do {
                    if let metadataDict = try JSONSerialization.jsonObject(with: metadataData, options: []) as? [String: Any] {
                        self.tz = metadataDict["tz"] as? String
                    }
                } catch {
                    print("Error parsing metadata JSON: \(error)")
                }
            }
        }
        
        if let paymentHash = msg.paymentHash {
            self.paymentHash = paymentHash
        }
        
        if let invoice = self.invoice {
            let prd = PaymentRequestDecoder()
            prd.decodePaymentRequest(paymentRequest: invoice)
            
            if let paymentHash = try? sphinx.paymentHashFromInvoice(bolt11: invoice) {
                self.paymentHash = paymentHash
            }
            
            let amount = prd.getAmount() ?? 0
            self.amount = amount * 1000 // convert to msat
        } else {
            self.amount = (msg.fromMe == true) ? Int((innerContentAmount) ?? 0) : Int((msg.msat ?? innerContentAmount) ?? 0)
        }
        
        self.uuid = msg.uuid
        self.index = msg.index
        self.tag = msg.tag
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
        tz         <- map["tz"]
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
    
    func isMessageWithText(
        type: UInt8
    ) -> Bool {
        let intType = Int(type)
        return intType == TransactionMessage.TransactionMessageType.message.rawValue ||
                intType == TransactionMessage.TransactionMessageType.call.rawValue ||
                intType == TransactionMessage.TransactionMessageType.attachment.rawValue ||
                intType == TransactionMessage.TransactionMessageType.botResponse.rawValue
    }
    
    func isDelete(
        type: UInt8
    ) -> Bool {
        let intType = Int(type)
        return intType == TransactionMessage.TransactionMessageType.delete.rawValue
    }
    
    func isPaidMessageRelated(type: UInt8) -> Bool {
        let intType = Int(type)
        
        return (
            intType == TransactionMessage.TransactionMessageType.purchase.rawValue ||
            intType == TransactionMessage.TransactionMessageType.purchaseAccept.rawValue ||
            intType == TransactionMessage.TransactionMessageType.purchaseDeny.rawValue
        )
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


struct MessageStatusMap: Mappable {
    var ts: Int?
    var status: String?
    var tag: String?

    init?(map: Map) {}

    mutating func mapping(map: Map) {
        ts          <- map["ts"]
        status      <- map["status"]
        tag         <- map["tag"]
    }

    func isReceived() -> Bool {
        return self.status == SphinxOnionManager.kCompleteStatus
    }

    func isFailed() -> Bool {
        return self.status == SphinxOnionManager.kFailedStatus
    }
}


class ListContactRecord: Mappable {
    var version: Int?
    var myIdx: UInt64?
    var pubkey: String?
    var lsp: String?
    var scid: UInt64?
    var contactKey: String?
    var highestMsgIdx: Int?

    required init?(map: Map) {
        // Initialize the object
    }

    func mapping(map: Map) {
        version <- map["version"]
        myIdx <- map["my_idx"]
        pubkey <- map["pubkey"]
        lsp <- map["lsp"]
        scid <- map["scid"]
        contactKey <- map["contact_key"]
        highestMsgIdx <- map["highest_msg_idx"]
    }
}


struct ParseInvoiceResult: Mappable {
    var value: Int?
    var paymentHash: String?
    var pubkey: String?
    var hopHints: [String]?
    var description: String?
    var expiry: Int?
    
    init?(map: Map) {}

    mutating func mapping(map: Map) {
        value          <- map["value"]
        paymentHash    <- map["payment_hash"]
        pubkey         <- map["pubkey"]
        hopHints       <- map["hop_hints"]
        description    <- map["description"]
        expiry         <- map["expiry"]
    }
}


class BTFeedSearchDataMapper: Mappable {
    var leechers: Int?
    var name: String?
    var seeders: Int?
    var magnet_link: String?
    var size_bytes: Int?

    // Required initializer
    required convenience init(map: Map) {
        self.init()
    }

    // Static method to get the object from a JSON string
    static func getFromString(_ string: String) -> BTFeedSearchDataMapper? {
        return BTFeedSearchDataMapper(JSONString: string)
    }

    // Mapping function
    func mapping(map: Map) {
        leechers   <- map["leechers"]
        name       <- map["name"]
        seeders <- map["seeders"]
        magnet_link <- map["magnet_link"]
        size_bytes <- map["size_bytes"]
    }

    // Function to get a JSON string representation of the object
    func getJSONString() -> String? {
        return self.toJSONString()
    }
    
    func convertToFeedResult()->FeedSearchResult{
        let feedId = self.name ?? "Unknown"
        let title = self.name ?? "No Title"
        let feedDescription = "Size: \(self.size_bytes ?? 0)"
        let imageUrl = ""
        let feedURLPath = magnet_link ?? "error"//@BTRefactor: replace this with some scheme to get underlying magnet link or something
        let finalType = FeedType.Video
        
        return FeedSearchResult(feedId, title, feedDescription, imageUrl, feedURLPath, finalType)
    }
}

//Magnet details related
class MagnetFile: Mappable {
    var name: String?
    var components: [String]?
    var length: Int?
    var included: Bool?

    required init?(map: Map) { }

    func mapping(map: Map) {
        name        <- map["name"]
        components  <- map["components"]
        length      <- map["length"]
        included    <- map["included"]
    }
}

class MagnetDetails: Mappable {
    var infoHash: String?
    var name: String?
    var files: [MagnetFile]?

    required init?(map: Map) { }

    func mapping(map: Map) {
        infoHash    <- map["info_hash"]
        name        <- map["name"]
        files       <- map["files"]
    }
}

class MagnetDetailsResponse: Mappable {
    var id: String?
    var details: MagnetDetails?
    var outputFolder: String?
    var seenPeers: [String]?
    var priceMsat:Int?

    required init?(map: Map) { }

    func mapping(map: Map) {
        priceMsat   <- map["price_msat"]
        id          <- map["id"]
        details     <- map["details"]
        outputFolder <- map["output_folder"]
        seenPeers   <- map["seen_peers"]
    }
    
    func priceCeilToNearestSatoshi() -> Int {
        let satoshis = Double(self.priceMsat ?? 0) / 1000.0
        return Int(ceil(satoshis))
    }
}

enum SphinxOnionManagerError: Error {
    case SOMNetworkError
    case SOMTimeoutError
    
    var localizedDescription: String {
        switch self {
        case .SOMNetworkError:
            return "Network Error"
        case .SOMTimeoutError:
            return "Timeout Error"
        }
        
    }
}

extension SphinxOnionManager {
    func validateSeed(
        words: [String]
    ) -> (SeedValidationError?, String?) {
        if (words.count != 12 && words.count != 24) {
            return (SeedValidationError.incorrectWordNumber,nil)
        }
        if let languageList = findListForWord(words[0]){
            for i in 1..<words.count{
                if languageList.words.contains(words[i]) == false {
                    return (SeedValidationError.invalidWord, "\(i + 1) - \(words[i])")
                }
            }
        }
        else {
            return (SeedValidationError.invalidWord, "1 -\(words[0])")
        }
        
        return (nil, nil)
    }
    
    func findListForWord(_ word: String) -> WordList? {
        for language in wordsListPossibilities {
            if language.words.contains(word) {
                return language
            }
        }
        return nil
    }
    
    func generateCryptographicallySecureRandomInt(upperBound: Int) -> Int? {
        guard upperBound > 0 else {
            return nil // Ensure that the upperBound is greater than 0
        }
        
        var randomInt: UInt32 = 0
        let result = SecRandomCopyBytes(kSecRandomDefault, MemoryLayout.size(ofValue: randomInt), &randomInt)
        
        if result == errSecSuccess {
            // Use randomInt to generate a random value within the specified range
            let randomValue = Int(randomInt) % upperBound
            return randomValue
        } else {
            return nil // Return nil to indicate an error in generating a secure random value
        }
    }
}
