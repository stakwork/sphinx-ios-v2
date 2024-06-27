//
//  SphinOnionManager+InvoicesExtension.swift
//  
//
//  Created by James Carucci on 3/5/24.
//


import Foundation
import SwiftyJSON

extension SphinxOnionManager {
    ///invoices related
    
    func updateGeneralRoutingInfo(){
        API.sharedInstance.fetchRoutingInfo(callback: { resultString, resultJSON in
            guard let resultString = resultString,
            let resultJSON = resultJSON else{
                return
            }
            do{
                let rr = try sphinx.addNode(node: resultString)
                self.handleRunReturn(rr: rr)
                
                if let routerPubkey = resultJSON["pubkey"].string {
                    UserDefaults.Keys.routerPubkey.set(routerPubkey)
                }
            }
            catch(let error){
                print(error)
                //could not update router info. Throw alert?
            }
        })
    }
    
    func prepareRoutingInfoForPayment(
            amtMsat: Int,
            pubkey: String,
            completion: @escaping (Bool) -> ()
        ) {
            if let routerPubkey = self.routerPubkey{
                API.sharedInstance.fetchSpecificPaymentRoutingInfo(
                    amtMsat: amtMsat,
                    pubkey: pubkey,
                    callback: { results in
                        if let results = results{
                            do{
                                try concatRoute(
                                    state: self.loadOnionStateAsData(),
                                    endHops: results,
                                    routerPubkey: routerPubkey,
                                    amtMsat: UInt64(amtMsat)
                                )
                                completion(true)
                            }
                            catch{
                                completion(false)
                            }
                        }
                        else{
                            completion(false)
                        }
                })
            }
        }
    
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
        //TODO:
        //1. get pubkey from invoice
        
        //2. Check if it needs manual routing and do so if necessary
        
        //3. Perform payment
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
