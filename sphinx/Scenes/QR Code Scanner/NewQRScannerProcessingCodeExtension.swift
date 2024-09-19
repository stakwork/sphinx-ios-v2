//
//  NewQRScannerPayingPRExtension.swift
//  sphinx
//
//  Created by Tomas Timinskas on 27/11/2019.
//  Copyright © 2019 Sphinx. All rights reserved.
//

import UIKit

extension NewQRScannerViewController {
    
    @IBAction func payButtonTouched() {
        if let invoice = prDecoder.paymentRequestString {
            payInvoice(invoice: invoice)
        }
    }
    
    @IBAction func closePayingButtonTouched() {
        self.animatePayingContainer(show: false)
    }
    
    func resetLabels() {
        payButton.layer.cornerRadius = confirmButton.frame.height/2
        
        amountLabel.text = "-"
        expirationLabel.text = "-"
        memoLabel.text = "-"
    }
    
    func validateQRString(string: String) {        
        resetLabels()
        
        if validateSubscriptionQR(string: string) {
            return
        } else if validatePublicKey(string: string) {
            return
        }else if validateInvoice(string: string) || validateZeroAmountInvoice(string: string){
            return
        } else if validateDeepLinks(string: string) {
            return
        }
        
        AlertHelper.showAlert(title: "sorry".localized, message: "code.not.recognized".localized)
    }
    
    func validateZeroAmountInvoice(string:String) -> Bool{
        print("isZeroAmountInvoice:\(prDecoder.isZeroAmountInvoice(invoice: string))")
        if(prDecoder.isZeroAmountInvoice(invoice: string)){
            DispatchQueue.main.async {
                self.presentSendZeroAmountInvoiceVC(invoice: string)
            }
            return true
        }
        
        return false
    }
    
    func validateInvoice(string: String) -> Bool {
        
        prDecoder.decodePaymentRequest(paymentRequest: string)
        
        if prDecoder.isPaymentRequest() {
            DispatchQueue.main.async {
                self.completeAndShowPRDetails()
            }
            return true
        }
        return false
    }
    
    func validatePublicKey(string: String) -> Bool {
        if string.isPubKey || string.isVirtualPubKey {
            self.handleContactOrSend(string: string)
            return true
        }
        return false
    }
    
    func handleContactOrSend(string: String) {
        if string.isExistingContactPubkey().0 {
            self.dismiss(animated: true, completion: {
                self.presentPubkeySendVC(pubkey: string)
            })
        } else {
            let alert = CustomAlertController(title: "pub.key.options".localized, message: "select.option".localized, preferredStyle: .actionSheet)
            
            alert.addAction(UIAlertAction(title: "pub.key.options-add.contact".localized, style: .default, handler:{ (UIAlertAction) in
                self.showAddContact(pubkey: string)
            }))

            alert.addAction(UIAlertAction(title: "pub.key.options-send.payment".localized, style: .default, handler:{ (UIAlertAction) in
                self.dismiss(animated: true, completion: {
                    self.presentPubkeySendVC(pubkey: string)
                })
            }))
            
            alert.addAction(UIAlertAction(title: "cancel".localized, style: .cancel ))
            alert.popoverPresentationController?.sourceView = self.view
            alert.popoverPresentationController?.sourceRect = self.view.bounds

            self.present(alert, animated: true, completion: nil)
        }
    }
    
    func showAddContact(pubkey:String){
        if let vc = self.delegate as? DashboardRootViewController{
            self.dismiss(animated: true,completion: {
                vc.presentNewContactVC(pubkey: pubkey)
            })
        }
    }
    
    func validateSubscriptionQR(string: String) -> Bool {
        return false
    }
    
    func presentPubkeySendVC(pubkey:String?=nil){
        if let delegate = self.delegate as? DashboardRootViewController{
            delegate.sendSatsButtonTouched(pubkey: pubkey)
        }
    }
    
    func presentSendZeroAmountInvoiceVC(invoice:String?=nil){
        if let delegate = self.delegate as? DashboardRootViewController{
            self.dismiss(animated: true, completion: {
                delegate.sendSatsButtonTouched(zeroAmtInvoice: invoice)
            })
        }
    }
    
    func validateDeepLinks(string: String) -> Bool {
        if let url = URL(string: string), DeepLinksHandlerHelper.storeLinkQueryFrom(url: url) {
            dismiss(animated: true, completion: { 
                self.delegate?.didScanDeepLink?()
            })
            return true
        }
        return false
    }
    
    func completeAndShowPRDetails() {
        payButton.isHidden = false
        
        if let amount = prDecoder.getAmount() {
            amountLabel.text = "\(amount) sat"
        }
        
        if let expirationDate = prDecoder.getExpirationDate() {
            if Date().timeIntervalSince1970 > expirationDate.timeIntervalSince1970 {
                expirationDateLabel.text = "expired".localized
                payButton.isHidden = true
            }
            
            let expirationDateString = expirationDate.getStringFromDate(format:"EEE dd MMM HH:mm:ss", timeZone: TimeZone.current)
            expirationLabel.text = expirationDateString
        }
        
        if let memo = prDecoder.getMemo() {
            memoLabel.text = memo
        }
        
        animatePayingContainer(show: true)
    }
    
    func animatePayingContainer(show: Bool) {
        payingContainerBottomConstraint.constant = show ? 0.0 : -250.0
        
        UIView.animate(withDuration: 0.2, animations: {
            self.payingContainer.superview?.layoutSubviews()
        })
    }
    
    func isProcessingPR() -> Bool {
        return payingContainerBottomConstraint.constant == 0
    }
    
    private func payInvoice(invoice: String) {
        invoiceLoading = true
        
        SphinxOnionManager.sharedInstance.payInvoice(invoice: invoice) { (success, errorMsg, tag) in
            if success {
                self.paymentTag = tag
                self.addPaymentObserver()
            } else {
                self.showErrorAlertAndDismiss()
            }
        }
    }
    
    func addPaymentObserver() {
        NotificationCenter.default.removeObserver(
            self,
            name: .onKeysendStatusReceived,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onKeysendStatusReceived),
            name: .onKeysendStatusReceived,
            object: nil
        )
        
        paymentTimer = Timer.scheduledTimer(
            timeInterval: 5.0,
            target: self,
            selector: #selector(self.showErrorAlertAndDismiss),
            userInfo: nil,
            repeats: false
        )
    }
    
    @objc func onKeysendStatusReceived(n: Notification) {
        if let tag = n.userInfo?["tag"] as? String,
           let status = n.userInfo?["status"] as? String {
            
            if tag == paymentTag {
                if status == SphinxOnionManager.kCompleteStatus {
                    resetTimerAndObserver()
                    dismiss(animated: true)
                } else {
                    showErrorAlertAndDismiss()
                }
            }
        }
    }
    
    func resetTimerAndObserver() {
        paymentTag = nil
        
        paymentTimer?.invalidate()
        paymentTimer = nil
        
        NotificationCenter.default.removeObserver(
            self,
            name: .onKeysendStatusReceived,
            object: nil
        )
    }
    
    @objc func showErrorAlertAndDismiss() {
        resetTimerAndObserver()
        
        AlertHelper.showAlert(
            title: "generic.error.title".localized,
            message: "generic.error.message".localized,
            completion: {
                self.dismiss(animated: true)
            }
        )
    }
}
