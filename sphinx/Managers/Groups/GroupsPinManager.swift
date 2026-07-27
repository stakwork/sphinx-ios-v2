//
//  GroupsPinManager.swift
//  sphinx
//
//  Created by Tomas Timinskas on 29/12/2020.
//  Copyright © 2020 Sphinx. All rights reserved.
//

import Foundation

class GroupsPinManager {
    
    nonisolated(unsafe) class var sharedInstance : GroupsPinManager {
        struct Static {
            nonisolated(unsafe) static let instance = GroupsPinManager()
        }
        return Static.instance
    }
    
    var userData = UserData.sharedInstance
    
    @MainActor func isPINNeverRequired() -> Bool {
        return userData.getPINNeverOverride()
    }

    @MainActor func hasPINTimeoutElapsed() -> Bool {
        guard UserData.sharedInstance.isSignupCompleted() else { return false }
        guard !userData.getPINNeverOverride() else { return false }
        if let date: Date = UserDefaults.Keys.lastPinDate.get() {
            let timeSeconds = Double(UserData.sharedInstance.getPINHours() * 3600)
            return Date().timeIntervalSince(date) > timeSeconds
        }
        return true
    }

    @MainActor func shouldAskForPin() -> Bool {
        return hasPINTimeoutElapsed()
    }
    
    func isValidPin(
        _ pin: String
    ) -> Bool {
        if let mnemonic = UserData.sharedInstance.getMnemonic(enteredPin: pin), SphinxOnionManager.sharedInstance.isMnemonic(code: mnemonic) {
            SphinxOnionManager.sharedInstance.appSessionPin = pin
            // Persist PIN for auto-login if the user has opted into low-friction auth
            let biometricEnabled = UserDefaults.Keys.biometricAuthEnabled.get(defaultValue: false)
            let neverRequire = UserDefaults.Keys.pinHours.get(defaultValue: Constants.kMaxPinTimeoutValue) == Constants.kMaxPinTimeoutValue
            if biometricEnabled || neverRequire {
                UserData.sharedInstance.saveAutoLoginPin(pin: pin)
                print("[AutoLogin] PIN saved to keychain (biometric: \(biometricEnabled), neverRequire: \(neverRequire))")
            }
            return true
        }
        return false
    }
}
