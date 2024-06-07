//
//  PaymentTransaction.swift
//  sphinx
//
//  Created by Tomas Timinskas on 30/01/2020.
//  Copyright © 2020 Sphinx. All rights reserved.
//

import Foundation
import SwiftyJSON

class PaymentTransaction {
    
    var type : Int?
    var amount : Int?
    var date : Date?
    var senderId : Int?
    var receiverId : Int?
    var chatId : Int?
    var originalMessageUUID : String?
    var paymentRequest : String?
    var paymentHash : String?
    var errorMessage : String?
    
    var expanded: Bool = false
    
    public enum TransactionDirection: Int {
        case Incoming
        case Outgoing
    }
    
    init(json: JSON) {
        let type = json["type"].int
        let amount = json["amount"].int
        let senderId = json["sender"].int
        let receiverId = json["receiver"].int
        let chatId = json["chat_id"].int
        let date = Date.getDateFromString(dateString: json["date"].stringValue) ?? Date()
        let paymentHash = json["payment_hash"].string
        let paymentRequest = json["payment_request"].string
        let originalMUUID = json["reply_uuid"].string
        let errorMessage = json["error_message"].string
        
        self.type = type
        self.amount = amount
        self.senderId = senderId
        self.receiverId = receiverId
        self.chatId = chatId
        self.date = date
        self.paymentRequest = paymentRequest
        self.paymentHash = paymentHash
        self.originalMessageUUID = originalMUUID
        self.errorMessage = errorMessage
    }
    
    init(fromTransactionMessage transactionMessage: TransactionMessage) {
        // Initialize properties using values from `TransactionMessage`
        self.type = transactionMessage.type
        self.amount = transactionMessage.amount?.intValue
        self.date = transactionMessage.date ?? Date()
        self.senderId = transactionMessage.senderId
        self.receiverId = transactionMessage.receiverId
        self.chatId = transactionMessage.chat?.id
        self.originalMessageUUID = transactionMessage.uuid
        self.paymentRequest = transactionMessage.invoice
        self.paymentHash = transactionMessage.paymentHash
        self.errorMessage = transactionMessage.errorMessage
    }
    
    func getDirection() -> TransactionDirection {
        let userId = UserData.sharedInstance.getUserId()
        if let senderId = senderId {
            if senderId == userId {
                return TransactionDirection.Outgoing
            }
        }
        return TransactionDirection.Incoming
    }
    
    func isIncoming() -> Bool {
        return getDirection() == TransactionDirection.Incoming
    }
    
    func isFailed() -> Bool {
        return !((errorMessage ?? "").isEmpty)
    }
    
    func getDate() -> Date {
        return date ?? Date()
    }
    
    func getUsers() -> String? {
        var users = ""
        var chat : Chat? = nil
        if let chatId = self.chatId,
              var foundChat = Chat.getChatWith(id: chatId){
            chat = foundChat
        }
        guard let owner = ContactsService.sharedInstance.owner else {
            return nil
        }
        
        if let senderId = senderId, let sender = UserContact.getContactWith(id: senderId), isIncoming() {
            if let nickname = sender.nickname, !nickname.isEmpty {
                return nickname
            }
            else{
                return "unknown sender"
            }
        } else if let receivedId = receiverId, let receiver = UserContact.getContactWith(id: receivedId), !isIncoming() {
            guard let chat = chat else{
                return "-"
            }
            if chat.isGroup() == false, let nickname = receiver.nickname, !nickname.isEmpty {
                return nickname
            }
            else{
                return "-"
            }
        } 
        
        if let chat = chat,
            chat.isGroup() == true,
           let message = TransactionMessage.getMessageWith(uuid: self.originalMessageUUID ?? ""){
            if(self.isIncoming() == false),
              let replyUUID = message.replyUUID,
              let replyMessage = TransactionMessage.getMessageWith(uuid: replyUUID),
              let originalAlias = replyMessage.senderAlias{
                return originalAlias
            }
            return message.senderAlias
        }
        return nil
    }
    
    func printDetails() {
        print("Transaction Details:")
        print("Type: \(type ?? 0)")  // Assuming '0' as a default 'unknown' type
        print("Amount: \(amount ?? 0)")  // Print default as '0' if nil
        print("Date: \(date?.description ?? "N/A")")  // Print 'N/A' if date is nil
        print("SenderId: \(senderId ?? 0)")  // Print '0' if nil
        print("ReceiverId: \(receiverId ?? 0)")  // Print '0' if nil
        print("ChatId: \(chatId ?? 0)")  // Print '0' if nil
        print("OriginalMessageUUID: \(originalMessageUUID ?? "N/A")")  // Print 'N/A' if nil
        print("PaymentRequest: \(paymentRequest ?? "N/A")")  // Print 'N/A' if nil
        print("PaymentHash: \(paymentHash ?? "N/A")")  // Print 'N/A' if nil
        print("ErrorMessage: \(errorMessage ?? "No error")")  // Print 'No error' if nil
        
        // Optionally, print the calculated properties or methods outputs
        let direction = getDirection() == .Incoming ? "Incoming" : "Outgoing"
        print("Transaction Direction: \(direction)")
        print("Is Incoming: \(isIncoming())")
        print("Is Failed: \(isFailed())")
        
        if let users = getUsers() {
            print("Users: \(users)")
        } else {
            print("Users: Unable to determine users involved.")
        }
    }
}
