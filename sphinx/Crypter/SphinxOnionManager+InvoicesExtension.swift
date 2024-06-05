//
//  SphinOnionManager+InvoicesExtension.swift
//  
//
//  Created by James Carucci on 3/5/24.
//


import Foundation

extension SphinxOnionManager {
    ///invoices related
    
    func createInvoice(
        amountMsat: Int,
        description: String? = nil
    ) -> String? {
            
        guard let seed = getAccountSeed(), let selfContact = UserContact.getOwner(), let _ = selfContact.nickname else {
            return nil
        }
            
        do {
            let rr = try sphinx.makeInvoice(
                seed: seed,
                uniqueTime: getTimeWithEntropy(),
                state: loadOnionStateAsData(),
                amtMsat: UInt64(amountMsat),
                description: description ?? ""
            )
            
            let _ = handleRunReturn(rr: rr)
                
            return rr.invoice
        } catch {
            return nil
        }
    }
    
    func payInvoice(invoice: String) {
        guard let seed = getAccountSeed() else{
            return
        }
        do {
            let rr = try sphinx.payInvoice(
                seed: seed,
                uniqueTime: getTimeWithEntropy(),
                state: loadOnionStateAsData(),
                bolt11: invoice,
                overpayMsat: nil
            )
            let _ = handleRunReturn(rr: rr)
        } catch {
            return
        }
    }
    
    func sendPaymentOfInvoiceMessage(message: TransactionMessage) {
        guard message.type == TransactionMessage.TransactionMessageType.payment.rawValue,
              let invoice = message.invoice,
              let seed = getAccountSeed(),
              let selfContact = UserContact.getOwner(),
              let chat = message.chat,
              let nickname = selfContact.nickname ?? chat.name else
        {
            return
        }
        
        do {
            let rr = try sphinx.payContactInvoice(
                seed: seed,
                uniqueTime: getTimeWithEntropy(),
                state: loadOnionStateAsData(),
                bolt11: invoice,
                myAlias: nickname,
                myImg: selfContact.avatarUrl ?? "",
                isTribe: false
            )
            let _ = handleRunReturn(rr: rr)
        } catch {
            return
        }
    }
    
    
    func sendInvoiceMessage(
        contact: UserContact,
        chat: Chat,
        invoiceString: String,
        memo: String = ""
    ) {
        let _ = sendMessage(
            to: contact,
            content: memo,
            chat: chat,
            provisionalMessage: nil,
            msgType: UInt8(TransactionMessage.TransactionMessageType.invoice.rawValue),
            threadUUID: nil,
            replyUUID: nil,
            invoiceString: invoiceString
        )
    }
    
    func getTransactionHistory(
        handlePaymentHistoryCompletion: @escaping ((String?) -> ()),
        itemsPerPage:UInt32,
        sinceTimestamp:UInt64
    ) {
        let rr = try! fetchPayments(seed: getAccountSeed()!, uniqueTime: getTimeWithEntropy(), state: loadOnionStateAsData(), since: sinceTimestamp * 1000, limit: itemsPerPage, scid: nil, remoteOnly: false, minMsat: 0, reverse: true)
        SphinxOnionManager.sharedInstance.paymentHistoryCallback = handlePaymentHistoryCompletion
        let _ = handleRunReturn(rr: rr)                
    }
    
    
    
    func keysend(){
        guard let seed = getAccountSeed() else{
            return
        }
        do {
            //02d3e18a29f372c4fb34c5ecf56f2bc5da962eeb9503f5345d273569a21623fe07_02adccd7f574d17d627541b447f47493916e78e33c1583ba9936607b35ca99c392_529771090643058694
            let rr = try! sphinx.keysend(seed: seed, uniqueTime: getTimeWithEntropy(), to: "02d3e18a29f372c4fb34c5ecf56f2bc5da962eeb9503f5345d273569a21623fe07", state: loadOnionStateAsData(), amtMsat: 21000, data: nil)
            let _ = handleRunReturn(rr: rr)
        } catch {
            return
        }
    }

}
