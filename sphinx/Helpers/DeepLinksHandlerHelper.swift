//
//  DeepLinksHandlerHelper.swift
//  sphinx
//
//  Created by Tomas Timinskas on 24/06/2020.
//  Copyright © 2020 Sphinx. All rights reserved.
//

import UIKit

class DeepLinksHandlerHelper {
    
    static func didHandleLinkQuery(
        vc: UIViewController,
        delegate: PaymentInvoiceDelegate? = nil
    ) -> Bool {
        if SubscriptionManager.sharedInstance.goToSubscriptionDetails(vc: vc) {
            return true
        }
        
        if InvoiceManager.sharedInstance.goToCreateInvoiceDetails(vc: vc, delegate: delegate) {
            return true
        }
        
        if GroupsManager.sharedInstance.goToGroupDetails(vc: vc) {
            return true
        }
        
        if FeedsManager.sharedInstance.goToContentFeed(vc: vc){
            return true
        }
        
        if WindowsManager.sharedInstance.showStakworkAuthorizeWith() {
            return false
        }
        
        //TODO: @Jim reinstate if we decide to
//        if WindowsManager.sharedInstance.showRedeemSats() {
//            return false
//        }
        
        if WindowsManager.sharedInstance.showAuth() {
            return false
        }
        
        if WindowsManager.sharedInstance.showPersonModal(delegate: vc as? WindowsManagerDelegate) {
            return false
        }
        
        if WindowsManager.sharedInstance.showPeopleUpdateModal(delegate: vc as? WindowsManagerDelegate) {
            return false
        }
        
        if DeepLinksHandlerHelper.goToSignerHardwareSetup(vc: vc) {
            return true
        }
        
        if DeepLinksHandlerHelper.joinJitsiCall(vc: vc) {
            return true
        }
        
        return false
    }
    
    static func joinJitsiCall(vc: UIViewController, forceJoin: Bool = false) -> Bool {
        if let callLink = UserDefaults.Keys.callLinkUrl.get(defaultValue: ""), callLink.isNotEmpty {
            
            if !GroupsPinManager.sharedInstance.shouldAskForPin() || forceJoin {
                UserDefaults.Keys.callLinkUrl.removeValue()
                
                VideoCallManager.sharedInstance.startVideoCall(
                    link: callLink,
                    audioOnly: callLink.contains("startAudioOnly=true")
                )

                return true
            }
            
        }
        return false
    }
    
    static func goToSignerHardwareSetup(vc: UIViewController) -> Bool {
        if let glyphQuery = UserDefaults.Keys.glyphQuery.get(defaultValue: ""), glyphQuery.isNotEmpty {
            
            UserDefaults.Keys.glyphQuery.removeValue()
            
            if let hardwareLink = CrypterManager.HardwareLink.getHardwareLinkFrom(
                query: glyphQuery
            ) {
                let cryptedManager = CrypterManager.sharedInstance
                cryptedManager.setupSigningDevice(vc: vc, hardwareLink: hardwareLink, callback: {_ in }) //TODO: review with @Tom, do we need to do the same workflow where we query the relay here? If so this is where to do it
            }

        }
        return false
    }
    
    static func storeLinkQueryFrom(url: URL) -> Bool {
        var shouldSetVC = false
        
        if url.absoluteString.isJitsiCallLink || url.absoluteString.isLiveKitCallLink {
            UserDefaults.Keys.callLinkUrl.set(url.absoluteString)
            return true
        }
        
        if let query = url.query {
            if let action = url.getLinkAction() {
                switch(action) {
                case "donation":
                    UserDefaults.Keys.subscriptionQuery.set(query)
                    shouldSetVC = true
                    break
                case "invoice":
                    UserDefaults.Keys.invoiceQuery.set(query)
                    shouldSetVC = true
                    break
                case "tribeV2" :
                    UserDefaults.Keys.tribeQuery.set(query)
                    shouldSetVC = true
                    break
                case "challenge":
                    UserDefaults.Keys.challengeQuery.set(query)
                    shouldSetVC = true
                case "redeem_sats":
                    UserDefaults.Keys.redeemSatsQuery.set(query)
                    shouldSetVC = true
                case "auth":
                    UserDefaults.Keys.authQuery.set(query)
                    shouldSetVC = true
                case "person":
                    UserDefaults.Keys.personQuery.set(query)
                    shouldSetVC = true
                    break
                case "save":
                    UserDefaults.Keys.saveQuery.set(query)
                    shouldSetVC = true
                    break
                case "share_content":
                    UserDefaults.Keys.shareContentQuery.set(query)
                    shouldSetVC = true
                case "glyph":
                    UserDefaults.Keys.glyphQuery.set(query)
                    shouldSetVC = true
                    break
                case "i":
                    UserDefaults.Keys.inviteCode.set(url.absoluteString)
                    shouldSetVC = true
                    break
                default:
                    break
                }
            }
        }
        
        return shouldSetVC
    }
}
