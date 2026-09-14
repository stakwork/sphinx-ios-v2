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
    
    func fetchRoutingInfoFor(
        pubkey: String,
        amtMsat: Int,
        completion: @escaping (Bool) -> ()
    ) {
        if let routerPubkey = self.routerPubkey {
            API.sharedInstance.fetchRoutingInfoFor(
                pubkey: pubkey,
                amtMsat: amtMsat,
                callback: { results in
                    if let results = results {
                        var resultsArray = []
                        do {
                            resultsArray = try results.toArray()
                        } catch {}
                            
                        if resultsArray.isEmpty {
                            completion(true)
                            return
                        }
                        
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
    
    func checkAndFetchRouteTo(
        publicKey: String,
        routeHint: String? = nil,
        amtMsat: Int,
        callback: @escaping (Bool) -> ()
    ) {
        if let checkAndFetchRouteOverride {
            checkAndFetchRouteOverride(publicKey, routeHint, amtMsat, callback)
            return
        }
        if requiresManualRouting(
            publicKey: publicKey,
            routeHint: routeHint
        ) {
            do {
                let _ = try sphinx.findRoute(
                    state: self.loadOnionStateAsData(),
                    toPubkey: publicKey,
                    routeHint: routeHint,
                    amtMsat: UInt64(amtMsat)
                )
                callback(true)
            } catch {
                fetchRoutingInfoFor(
                    pubkey: publicKey,
                    amtMsat: amtMsat,
                    completion: { success in
                        callback(success)
                    }
                )
            }
        } else {
            callback(true)
        }
    }
    
    ///invoices related
    func createInvoice(
        amountMsat: Int,
        description: String? = nil,
        callback: @escaping (String?) -> Void
    ) {
        guard let seed = getAccountSeed(), let selfContact = UserContact.getOwner(), let _ = selfContact.nickname else {
            callback(nil)
            return
        }

        do {
            let rr = try sphinx.requestInvoice(
                seed: seed,
                uniqueTime: getTimeWithEntropy(),
                state: loadOnionStateAsData(),
                amtMsat: UInt64(amountMsat),
                description: description
            )

            self.invoiceGeneratedCallback = callback
            let _ = handleRunReturn(rr: rr)

            self.invoiceGeneratedTimeoutTimer = Timer.scheduledTimer(
                withTimeInterval: 30.0,
                repeats: false
            ) { [weak self] _ in
                guard let self = self else { return }
                self.invoiceGeneratedCallback?(nil)
                self.invoiceGeneratedCallback = nil
                self.invoiceGeneratedTimeoutTimer = nil
            }
        } catch {
            callback(nil)
        }
    }
    
    func getInvoiceDetails(invoice: String) -> ParseInvoiceResult? {
        if let invoiceDetailsOverride {
            return invoiceDetailsOverride(invoice)
        }
        let normalizedInvoice = invoice.components(separatedBy: .whitespacesAndNewlines).joined()
        do {
            let rawInvoiceDetails = try parseInvoice(invoiceJson: normalizedInvoice)
            let parsedInvoiceDetails = ParseInvoiceResult(JSONString: rawInvoiceDetails)
            return parsedInvoiceDetails
        } catch {
            return nil
        }
    }
    
    /// Matches only the confirmed mixer/server already-paid signal.
    /// Empty/disabled until that wording is known — do not guess unconfirmed phrases.
    /// TODO: confirm against mixer/server duplicate-payment fix
    func isInvoiceAlreadyPaidError(_ error: String?) -> Bool {
        guard let error = error, !error.isEmpty else {
            return false
        }
        return SphinxOnionManager.confirmedAlreadyPaidErrorSignals.contains(error)
    }
    
    func isInvoiceAlreadyPaidError(_ error: Error) -> Bool {
        guard let sphinxError = error as? SphinxError else {
            return false
        }
        if case let .SendFailed(r) = sphinxError {
            return isInvoiceAlreadyPaidError(r)
        }
        return false
    }
    
    static var invoiceAlreadyPaidLocalized: String {
        "invoice.already.paid".localized
    }
    
    func isPaymentHashAlreadyPaidLocally(_ paymentHash: String) -> Bool {
        if inFlightPaymentHashes.contains(paymentHash) {
            return true
        }
        if paidPaymentHashes.contains(paymentHash) {
            return true
        }
        return TransactionMessage.hasSettledPayment(forPaymentHash: paymentHash)
    }
    
    func markPaymentHashInFlight(_ paymentHash: String) {
        inFlightPaymentHashes.insert(paymentHash)
    }
    
    func clearPaymentHashInFlight(_ paymentHash: String?) {
        guard let paymentHash = paymentHash, !paymentHash.isEmpty else {
            return
        }
        inFlightPaymentHashes.remove(paymentHash)
    }
    
    func markPaymentHashPaid(_ paymentHash: String?) {
        guard let paymentHash = paymentHash, !paymentHash.isEmpty else {
            return
        }
        paidPaymentHashes.insert(paymentHash)
        inFlightPaymentHashes.remove(paymentHash)
    }
    
    func reportAlreadyPaidLocally(
        paymentHash: String,
        callback: ((Bool, String?) -> ())? = nil,
        useAlert: Bool = false
    ) {
        print("Run return object error: already paid (local) payment_hash=\(paymentHash)")
        let message = SphinxOnionManager.invoiceAlreadyPaidLocalized
        if useAlert {
            DispatchQueue.main.async {
                AlertHelper.showAlert(
                    title: "generic.error.title".localized,
                    message: message
                )
            }
        }
        callback?(false, message)
    }
    
    func reportAlreadyPaidFromNetwork(
        paymentHash: String?,
        callback: ((Bool, String?) -> ())? = nil,
        useAlert: Bool = false
    ) {
        if let paymentHash = paymentHash, !paymentHash.isEmpty {
            print("Run return object error: already paid (network) payment_hash=\(paymentHash)")
        } else {
            print("Run return object error: already paid (network)")
        }
        clearPaymentHashInFlight(paymentHash)
        let message = SphinxOnionManager.invoiceAlreadyPaidLocalized
        if useAlert {
            DispatchQueue.main.async {
                AlertHelper.showAlert(
                    title: "generic.error.title".localized,
                    message: message
                )
            }
        }
        callback?(false, message)
    }
            
    func payInvoice(
        invoice: String,
        overPayAmountMsat: UInt64? = nil,
        callback: ((Bool, String?) -> ())? = nil
    ){
        let invoice = invoice.components(separatedBy: .whitespacesAndNewlines).joined()
        guard let invoiceDict = getInvoiceDetails(invoice: invoice) else {
            callback?(false, "Pubkey not found")
            return
        }
        
        let paymentHash = invoiceDict.paymentHash
        
        // Local already-paid check runs before the pubkey/value guard so
        // zero-amount invoices still short-circuit.
        if let paymentHash = paymentHash {
            if isPaymentHashAlreadyPaidLocally(paymentHash) {
                reportAlreadyPaidLocally(paymentHash: paymentHash, callback: callback)
                return
            }
            markPaymentHashInFlight(paymentHash)
        }
        
        guard let pubkey = invoiceDict.pubkey,
              let amount = invoiceDict.value else
        {
            clearPaymentHashInFlight(paymentHash)
            callback?(false, "Pubkey not found")
            return
        }
        
        let hasRouteHint = invoiceDict.hopHints?.last != nil
        
        let wrappedCallback: ((Bool, String?) -> ()) = { [weak self] success, errorMsg in
            // Submit success is not settlement — only clear in-flight. The paid
            // set is updated when a pay actually confirms (preimage / COMPLETE).
            self?.clearPaymentHashInFlight(paymentHash)
            callback?(success, errorMsg)
        }
        
        checkAndFetchRouteTo(
            publicKey: pubkey,
            routeHint: invoiceDict.hopHints?.last,
            amtMsat: Int(overPayAmountMsat ?? UInt64(amount))
        ) { success in
            if success {
                self.finalizePayInvoice(
                    invoice: invoice,
                    hasRouteHint: hasRouteHint,
                    amount: overPayAmountMsat ?? UInt64(amount),
                    callback: wrappedCallback
                )
            } else {
                if !hasRouteHint {
                    ///Standard invoice with no route hint
                    self.payInvoiceFromLSP(
                        invoice: invoice,
                        callback: wrappedCallback
                    )
                    return
                }
                ///error getting route info
                self.clearPaymentHashInFlight(paymentHash)
                callback?(false, "Could not find a route to the target. Please try again.")
            }
        }
    }
    
    func payInvoiceFromLSP(
        invoice: String,
        callback: ((Bool, String?) -> ())? = nil
    ) {
        let invoice = invoice.components(separatedBy: .whitespacesAndNewlines).joined()
        let paymentHash = getInvoiceDetails(invoice: invoice)?.paymentHash
        
        // Do not treat in-flight as already paid here: this is the continuation
        // (or timeout retry) of the in-flight attempt.
        if let paymentHash = paymentHash,
           paidPaymentHashes.contains(paymentHash) || TransactionMessage.hasSettledPayment(forPaymentHash: paymentHash) {
            reportAlreadyPaidLocally(paymentHash: paymentHash, callback: callback)
            return
        }
        
        guard let seed = getAccountSeed() else{
            clearPaymentHashInFlight(paymentHash)
            callback?(false, "Account seed not found")
            return
        }
        
        do {
            let rr = try sphinx.pay(
                seed: seed,
                uniqueTime: getTimeWithEntropy(),
                state: loadOnionStateAsData(),
                bolt11: invoice
            )
            let _ = handleRunReturn(rr: rr)
            
            if isInvoiceAlreadyPaidError(rr.error) {
                reportAlreadyPaidFromNetwork(paymentHash: paymentHash, callback: callback)
                return
            }
            
            callback?(true, nil)
        } catch let error {
            if isInvoiceAlreadyPaidError(error) {
                reportAlreadyPaidFromNetwork(paymentHash: paymentHash, callback: callback)
                return
            }
            clearPaymentHashInFlight(paymentHash)
            callback?(false, (error as? SphinxError).debugDescription)
        }
    }
    
    func finalizePayInvoice(
        invoice: String,
        hasRouteHint: Bool,
        amount: UInt64,
        callback: ((Bool, String?) -> ())? = nil
    ) {
        let invoice = invoice.components(separatedBy: .whitespacesAndNewlines).joined()
        let paymentHash = getInvoiceDetails(invoice: invoice)?.paymentHash
        guard let seed = getAccountSeed() else{
            clearPaymentHashInFlight(paymentHash)
            callback?(false, "Account seed not found")
            return
        }
        do {
            let rr = try sphinx.payInvoice(
                seed: seed,
                uniqueTime: getTimeWithEntropy(),
                state: loadOnionStateAsData(),
                bolt11: invoice,
                overpayMsat: amount
            )
            let _ = handleRunReturn(rr: rr)
            
            if isInvoiceAlreadyPaidError(rr.error) {
                reportAlreadyPaidFromNetwork(paymentHash: paymentHash, callback: callback)
                return
            }
            
            if let tag = getMessageTag(messages: rr.msgs, isSendingMessage: true), !hasRouteHint {
                setupInvoicePaymentTimerFor(invoice: invoice, tag: tag)
            }
            callback?(true, nil)
        } catch let error {
            if isInvoiceAlreadyPaidError(error) {
                reportAlreadyPaidFromNetwork(paymentHash: paymentHash, callback: callback)
                return
            }
            clearPaymentHashInFlight(paymentHash)
            callback?(false, (error as? SphinxError).debugDescription)
        }
    }
    
    func setupInvoicePaymentTimerFor(invoice: String, tag: String) {
        let paymentTimer = Timer.scheduledTimer(
            timeInterval: 60.0,
            target: self,
            selector: #selector(self.resetInvoicePaymentTimerFor(timer:)),
            userInfo: ["invoice": invoice, "tag": tag],
            repeats: false
        )
        
        paymentTimeoutTimers[tag] = paymentTimer
    }
    
    func onPaymentStatusReceivedFor(
        tag: String,
        status: String
    ) {
        DispatchQueue.main.async {
            if let timer = self.paymentTimeoutTimers[tag] {
                if status == SphinxOnionManager.kCompleteStatus {
                    AlertHelper.showAlert(
                        title: "Success",
                        message: "Your payment has been successfully processed"
                    )
                } else if let userInfo = timer.userInfo as? [String: String], let invoice = userInfo["invoice"] {
                    self.payInvoiceFromLSP(invoice: invoice)
                }
                self.resetInvoicePaymentTimerFor(tag: tag)
            }
        }
    }
    
    @objc func resetInvoicePaymentTimerFor(timer: Timer) {
        if let userInfo = timer.userInfo as? [String: String], let tag = userInfo["tag"] {
            resetInvoicePaymentTimerFor(tag: tag)
        }
    }
    
    func resetInvoicePaymentTimerFor(tag: String) {
        let timer = paymentTimeoutTimers[tag]
        timer?.invalidate()
        paymentTimeoutTimers[tag] = nil
    }
    
    ///Paying invoice message
    func payInvoiceMessage(
        message: TransactionMessage,
        callback: ((Bool, String?) -> ())? = nil
    ) {
        guard let invoiceDict = getInvoiceDetails(invoice: message.invoice ?? "") else {
            callback?(false, "Pubkey not found")
            return
        }
        
        let paymentHash = invoiceDict.paymentHash
        
        if let paymentHash = paymentHash {
            if isPaymentHashAlreadyPaidLocally(paymentHash) {
                reportAlreadyPaidLocally(
                    paymentHash: paymentHash,
                    callback: callback,
                    useAlert: callback == nil
                )
                return
            }
            markPaymentHashInFlight(paymentHash)
        }
        
        guard let owner = UserContact.getOwner(),
              let _ = owner.nickname,
              let pubkey = invoiceDict.pubkey,
              let amount = invoiceDict.value else
        {
            clearPaymentHashInFlight(paymentHash)
            callback?(false, "Pubkey not found")
            return
        }
        
        checkAndFetchRouteTo(
            publicKey: pubkey,
            routeHint: invoiceDict.hopHints?.last,
            amtMsat: Int(UInt64(amount))
        ) { success in
            if success {
                self.finalizePayInvoiceMessage(message: message, callback: callback)
            } else {
                self.clearPaymentHashInFlight(paymentHash)
                if let callback = callback {
                    callback(false, "Could not find a route to the target. Please try again.")
                } else {
                    DispatchQueue.main.async {
                        AlertHelper.showAlert(
                            title: "Routing Error",
                            message: "Could not find a route to the target. Please try again."
                        )
                    }
                }
            }
        }
    }
    
    func finalizePayInvoiceMessage(
        message: TransactionMessage,
        callback: ((Bool, String?) -> ())? = nil
    ) {
        let paymentHash = getInvoiceDetails(invoice: message.invoice ?? "")?.paymentHash
        
        guard message.type == TransactionMessage.TransactionMessageType.invoice.rawValue,
              let rawInvoice = message.invoice,
              let seed = getAccountSeed(),
              let owner = UserContact.getOwner(),
              let nickname = owner.nickname else
        {
            clearPaymentHashInFlight(paymentHash)
            callback?(false, "Account seed not found")
            return
        }

        let invoice = rawInvoice.components(separatedBy: .whitespacesAndNewlines).joined()

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
            
            if isInvoiceAlreadyPaidError(rr.error) {
                reportAlreadyPaidFromNetwork(
                    paymentHash: paymentHash,
                    callback: callback,
                    useAlert: callback == nil
                )
                return
            }
            
            callback?(true, nil)
        } catch {
            if isInvoiceAlreadyPaidError(error) {
                reportAlreadyPaidFromNetwork(
                    paymentHash: paymentHash,
                    callback: callback,
                    useAlert: callback == nil
                )
                return
            }
            clearPaymentHashInFlight(paymentHash)
            callback?(false, (error as? SphinxError).debugDescription)
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

    func keysend(
        pubkey: String,
        routeHint: String? = nil,
        amt: Double,
        data: Data? = nil,
        completion: @escaping (Bool, String?) -> ()
    ) {
        checkAndFetchRouteTo(
            publicKey: pubkey,
            routeHint: routeHint,
            amtMsat: Int(amt * 1000)
        ) { success in
            if success {
                let (success, tag) = self.finalizeKeysend(
                    pubkey: pubkey,
                    routeHint: routeHint,
                    amt: Int(amt * 1000),
                    data: data
                )
                
                if success {
                    completion(true, tag)
                } else {
                    completion(false, nil)
                }
            } else {
                completion(false, nil)
            }
        }
    }
    
    func finalizeKeysend(
        pubkey: String,
        routeHint: String? = nil,
        amt: Int,
        data: Data? = nil
    ) -> (Bool, String?) {
        guard let seed = getAccountSeed() else{
            return (false, nil)
        }
        do {
            let rr = try sphinx.keysend(
                seed: seed,
                uniqueTime: getTimeWithEntropy(),
                to: pubkey,
                state: loadOnionStateAsData(),
                amtMsat: UInt64(amt),
                data: data,
                routeHint: routeHint
            )
            let _ = handleRunReturn(rr: rr)
            
            return (
                true,
                getMessageTag(messages: rr.msgs, isSendingMessage: true)
            )
        } catch {
            return (false, nil)
        }
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
                since: sinceTimestamp,
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
    
    func getIdFromMacaroon(macaroon: String) -> (String?, String?) {
        do {
            let identifier = try idFromMacaroon(macaroon: macaroon)
            return (identifier, nil)
        } catch let error {
            return (nil, (error as? SphinxError).debugDescription)
        }
    }

}
