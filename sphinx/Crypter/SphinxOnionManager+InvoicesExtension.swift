//
//  SphinOnionManager+InvoicesExtension.swift
//  
//
//  Created by James Carucci on 3/5/24.
//


import Foundation
import SwiftyJSON

extension SphinxOnionManager {
    ///Routing
    func updateRoutingInfo() {
        API.sharedInstance.fetchRoutingInfo(
            callback: { result, pubkey in
                guard let result = result else {
                    return
                }
                do {
                    let rr = try sphinx.addNode(node: result)
                    let _ = self.handleRunReturn(rr: rr)
                    
                    if let pubkey = pubkey {
                        UserDefaults.Keys.routerPubkey.set(pubkey)
                    }
                } catch {}
            }
        )
    }
    
    func prepareRoutingInfoForPayment(
        amtMsat: Int,
        pubkey: String,
        completion: @escaping (Bool) -> ()
    ) {
        if let routerPubkey = self.routerPubkey {
            API.sharedInstance.fetchSpecificPaymentRoutingInfo(
                amtMsat: amtMsat,
                pubkey: pubkey,
                callback: { results in
                    if let results = results {
                        do {
                           let rr =  try concatRoute(
                                state: self.loadOnionStateAsData(),
                                endHops: results,
                                routerPubkey: routerPubkey,
                                amtMsat: UInt64(amtMsat)
                            )
                            let _ = self.handleRunReturn(rr: rr)
                            completion(true)
                        } catch {
                            completion(false)
                        }
                    } else {
                        completion(false)
                    }
                }
            )
        }
    }
    
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
    
    func payInvoice(invoice: String,overPayAmountMsat:UInt64?=nil) {
        //1. get pubkey from invoice
        var rawInvoiceResult = ""
        do {
            rawInvoiceResult = try parseInvoice(invoiceJson: invoice)
        }
        catch{
            return
        }
        
        guard let invoiceDict = ParseInvoiceResult(JSONString: rawInvoiceResult),
              let pubkey = invoiceDict.pubkey,
            let amount = invoiceDict.value else{
            return // no pubkey so we can't route!
        }
        if(contactRequiresManualRouting(contactString: pubkey)){
            prepareRoutingInfoForPayment(amtMsat: Int(overPayAmountMsat ?? UInt64(amount)), pubkey: pubkey, completion: { success in
                if(success){
                    self.finalizePayInvoice(invoice: invoice, overPayAmountMsat: overPayAmountMsat)
                }
                else{
                    //error getting route info
                    AlertHelper.showAlert(title: "Routing Error", message: "Could not find a route to the target. Please try again.")
                }
            })
        }
        else{
            //3. Perform payment
            finalizePayInvoice(invoice: invoice, overPayAmountMsat: overPayAmountMsat)
        }
        
    }
    
    func finalizePayInvoice(invoice: String,overPayAmountMsat:UInt64?=nil) {
        
        guard let seed = getAccountSeed() else{
            return
        }
        do {
            let rr = try sphinx.payInvoice(
                seed: seed,
                uniqueTime: getTimeWithEntropy(),
                state: loadOnionStateAsData(),
                bolt11: invoice,
                overpayMsat: overPayAmountMsat
            )
            let _ = handleRunReturn(rr: rr)
        } catch {
            return
        }
    }
    
    func payInvoiceMessage(message: TransactionMessage) {
        var rawInvoiceResult = ""
        do {
            rawInvoiceResult = try parseInvoice(invoiceJson: message.invoice ?? "")
        }
        catch{
            return
        }
        guard message.type == TransactionMessage.TransactionMessageType.invoice.rawValue,
              let owner = UserContact.getOwner(),
              let nickname = owner.nickname,
              let invoiceDict = ParseInvoiceResult(JSONString: rawInvoiceResult),
              let pubkey = invoiceDict.pubkey,
              let amount = invoiceDict.value else
        {
            return
        }
        if(contactRequiresManualRouting(contactString: pubkey)){
            prepareRoutingInfoForPayment(amtMsat: Int(UInt64(amount)), pubkey: pubkey, completion: { success in
                if(success){
                    self.finalizePayInvoiceMessage(message: message)
                }
                else{
                    //error getting route info
                    AlertHelper.showAlert(title: "Routing Error", message: "Could not find a route to the target. Please try again.")
                }
            })
        }
        else{
            self.finalizePayInvoiceMessage(message: message)
        }
    }
    
    func finalizePayInvoiceMessage(message:TransactionMessage){
        guard message.type == TransactionMessage.TransactionMessageType.invoice.rawValue,
              let invoice = message.invoice,
              let seed = getAccountSeed(),
              let owner = UserContact.getOwner(),
              let nickname = owner.nickname else
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
                myImg: owner.avatarUrl ?? "",
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
    
    func getTransactionsHistory(
        paymentsHistoryCallback: @escaping ((String?, String?) -> ()),
        itemsPerPage: UInt32,
        sinceTimestamp: UInt64
    ) {
        do {
            let rr = try fetchPayments(
                seed: getAccountSeed()!,
                uniqueTime: getTimeWithEntropy(),
                state: loadOnionStateAsData(),
                since: sinceTimestamp * 1000,
                limit: itemsPerPage,
                scid: nil,
                remoteOnly: false,
                minMsat: 0,
                reverse: true
            )
            
            self.paymentsHistoryCallback = paymentsHistoryCallback
            
            let _ = handleRunReturn(rr: rr)
        } catch let error {
            paymentsHistoryCallback(
                nil,
                "Error fetching transactions history: \(error.localizedDescription)"
            )
        }
    }

    func keysend(
        pubkey: String,
        amt: Int
    ) {
        ///Should be fixed and tested
        
        
//        guard let seed = getAccountSeed() else{
//            return
//        }
//        do {
//            let rr = try sphinx.keysend(
//                seed: seed,
//                uniqueTime: getTimeWithEntropy(),
//                to: pubkey,
//                state: loadOnionStateAsData(),
//                amtMsat: UInt64(amt * 1000), ///Check if sats or msats
//                data: nil
//            )
//            let _ = handleRunReturn(rr: rr)
//        } catch {
//            return
//        }
    }

}
