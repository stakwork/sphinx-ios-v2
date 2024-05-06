//
//  GroupsPinManager.swift
//  sphinx
//
//  Created by Tomas Timinskas on 29/12/2020.
//  Copyright © 2020 Sphinx. All rights reserved.
//

import Foundation

class GroupsPinManager {
    
    public enum PinPresentationContext {
        case launch
        case enterForeground
        case startingCall
    }

    class var sharedInstance : GroupsPinManager {
        struct Static {
            static let instance = GroupsPinManager()
        }
        return Static.instance
    }
    
    var userData = UserData.sharedInstance
    
    var currentPin : String {
        get {
            return userData.getCurrentSessionPin()
        }
        set {
            userData.save(currentSessionPin: newValue)
        }
    }
    
    var isStandardPIN : Bool {
        get {
            if let privacyPin = userData.getPrivacyPin() {
                return currentPin != privacyPin
            }
            return true
        }
    }
    
    func shouldAskForPin(presentationContext:PinPresentationContext) -> Bool {
        if UserData.sharedInstance.isUserLogged() {
            if userData.getPINNeverOverride() {
                return false
            }
            if let date: Date = UserDefaults.Keys.lastPinDate.get() {
                let timeSeconds = Double(UserData.sharedInstance.getPINHours() * 3600)
                if Date().timeIntervalSince(date) > timeSeconds {
                    return true
                }
            }
        }
        return true
    }
    
    var shouldAvoidFaceID : Bool {
        get {
            return currentPin.isEmpty || currentPin == userData.getPrivacyPin()
        }
    }
    
    func setCurrentPin(_ pin: String) {
        self.currentPin = pin
    }
    
    func setCurrentPinOnUpdate(changingStandard: Bool, isOnStandard: Bool, pin: String) {
        if changingStandard && isOnStandard {
            setCurrentPin(pin)
        } else if !changingStandard && !isOnStandard {
            setCurrentPin(pin)
        }
    }
    
    func isPrivacyPinSet() -> Bool {
        if let privacyPin = userData.getPrivacyPin(), !privacyPin.isEmpty {
            return true
        }
        return false
    }
    
    func didUpdatePrivacyPin(newPin: String) {
        let isOnStandardMode = GroupsPinManager.sharedInstance.isStandardPIN
        UserData.sharedInstance.save(privacyPin: newPin)
        setCurrentPinOnUpdate(changingStandard: false, isOnStandard: isOnStandardMode, pin: newPin)
        
        if let privacyPin = userData.getPrivacyPin(), !privacyPin.isEmpty {
            if !isStandardPIN {
                setCurrentPin(privacyPin)
            }
            for contact in UserContact.getPrivateContacts() {
                contact.pin = privacyPin
            }
            for chat in Chat.getPrivateChats() {
                chat.pin = privacyPin
            }
            CoreDataManager.sharedManager.saveContext()
        }
    }
    
    func didUpdateStandardPin(newPin: String) {
        let isOnStandardMode = GroupsPinManager.sharedInstance.isStandardPIN
        UserData.sharedInstance.save(pin: newPin)
        GroupsPinManager.sharedInstance.setCurrentPinOnUpdate(changingStandard: true, isOnStandard: isOnStandardMode, pin: newPin)
    }
    
    func isValidPin(_ pin: String) -> Bool {
        if let mnemonic = UserData.sharedInstance.getMnemonic(enteredPin: pin), SphinxOnionManager.sharedInstance.isMnemonic(code: mnemonic) {
            SphinxOnionManager.sharedInstance.appSessionPin = pin
            return true
        }
        return false
    }
    
    func logout() {
        setCurrentPin("")
        let pinVC = PinCodeViewController.instantiate()
        WindowsManager.sharedInstance.showConveringWindowWith(rootVC: pinVC)
    }
}
