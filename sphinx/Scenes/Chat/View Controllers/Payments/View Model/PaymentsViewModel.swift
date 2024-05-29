//
//  PaymentsViewModel.swift
//  sphinx
//
//  Created by Tomas Timinskas on 18/06/2023.
//  Copyright © 2023 sphinx. All rights reserved.
//

import Foundation
import SwiftyJSON

class PaymentsViewModel : NSObject {
    
    enum PaymentMode: Int {
        case receive
        case send
        case sendOnchain
    }
    
    struct Payment {
        public var memo: String?
        public var encryptedMemo: String?
        public var remoteEncryptedMemo: String?
        public var amount: Int?
        public var destinationKey: String?
        public var routeHint: String?
        public var BTCAddress: String?
        public var message: String?
        public var encryptedMessage: String?
        public var remoteEncryptedMessage: String?
        public var muid: String?
        public var messageUUID: String?
        public var dim: String?
    }
    
    var payment = Payment()
    
    func resetPayment() {
        self.payment = Payment()
    }
    
    func setPreloadedPubKey(
        preloadedPubkey: String? = nil
    ) {
        guard let preloadedPubkey = preloadedPubkey else {
            return
        }
        
        if preloadedPubkey.isVirtualPubKey {
            let (pk, rh) = preloadedPubkey.pubkeyComponents
            payment.destinationKey = pk
            payment.routeHint = rh
        } else {
            payment.destinationKey = preloadedPubkey
        }
    }
    
    func validateMemo(
        contact: UserContact?
    ) -> Bool {
        guard let memo = payment.memo else {
            return true
        }
        
        return memo.isValidLengthMemo()
    }
    
    func validatePayment(
        contact: UserContact?
    ) -> Bool {
        guard let _ = payment.message else {
            return true
        }
        
        guard let _ = contact else {
            return false
        }
        
        return true
    }
    
    
    
    func createLocalMessages(message: JSON?) -> (TransactionMessage?, Bool) {
        if let message = message {
            if let messageObject = TransactionMessage.insertMessage(
                m: message,
                existingMessage: TransactionMessage.getMessageWith(id: message["id"].intValue)
            ).0 {
                messageObject.setPaymentInvoiceAsPaid()
                return (messageObject, true)
            }
        }
        return (nil, false)
    }
}
