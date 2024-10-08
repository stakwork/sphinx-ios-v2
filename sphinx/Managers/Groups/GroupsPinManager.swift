//
//  GroupsPinManager.swift
//  sphinx
//
//  Created by Tomas Timinskas on 29/12/2020.
//  Copyright © 2020 Sphinx. All rights reserved.
//

import Foundation

class GroupsPinManager {
    
    class var sharedInstance : GroupsPinManager {
        struct Static {
            static let instance = GroupsPinManager()
        }
        return Static.instance
    }
    
    var userData = UserData.sharedInstance
    
    func shouldAskForPin() -> Bool {
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
        return UserData.sharedInstance.isSignupCompleted()
    }
    
    func isValidPin(
        _ pin: String
    ) -> Bool {
        if let mnemonic = UserData.sharedInstance.getMnemonic(enteredPin: pin), SphinxOnionManager.sharedInstance.isMnemonic(code: mnemonic) {
            SphinxOnionManager.sharedInstance.appSessionPin = pin
            return true
        }
        return false
    }
}
