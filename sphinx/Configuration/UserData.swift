//
//  Library
//
//  Created by Tomas Timinskas on 08/03/2019.
//  Copyright © 2019 Sphinx. All rights reserved.
//

import Foundation
import CoreData

class UserData {
    
    class var sharedInstance : UserData {
        struct Static {
            static let instance = UserData()
        }
        return Static.instance
    }
    
    var ownerId: Int? = nil
    var ownerPubKey: String? = nil
    var storedSignupStep: Int? = nil
    
    let keychainManager = KeychainManager.sharedInstance
    
    public static let kMinimumMemoryFootprintGB : Int = 4
    public static var kMaximumMemoryFootprintGB : Int = {
        if let max = getTotalDiskStorage(){
            return Int(Double(max)/1e9)
        }
        else{
            return 100
        }
    }()
    
    static func getTotalDiskStorage() -> UInt64? {
        do {
            let resourceURL = URL(fileURLWithPath: "/")
            let resourceValues = try resourceURL.resourceValues(forKeys: [.volumeTotalCapacityKey])
            if let totalCapacity = resourceValues.volumeTotalCapacity {
                return UInt64(totalCapacity)
            }
        } catch {
            print("Error: \(error)")
        }
        return nil
    }
    
    func getMaxMemoryGB() -> Int {
        let result = UserDefaults.Keys.maxMemory.get(defaultValue: UserData.kMaximumMemoryFootprintGB)
        return result
    }

    func setMaxMemory(GB: Int) {
        UserDefaults.Keys.maxMemory.set(GB)
    }

    public var signupStep: Int {
        get {
            if let storedSignupStep = storedSignupStep {
                return storedSignupStep
            }
            let storedSetp = UserDefaults.Keys.signupStep.get(defaultValue: 0)
            storedSignupStep = storedSetp
            return storedSetp
        }
        set {
            storedSignupStep = newValue
            UserDefaults.Keys.signupStep.set(newValue)
        }
    }
    
    func isPinSet() -> Bool {
        return signupStep >= SignupHelper.SignupStep.PINSet.rawValue
    }
    
    func isSignupCompleted() -> Bool {
        return signupStep == SignupHelper.SignupStep.SignupComplete.rawValue
    }
    
    func completeSignup() {
        signupStep = SignupHelper.SignupStep.SignupComplete.rawValue
    }
    
    func isUserLogged() -> Bool {
        if let _ = getMnemonic() {
            return isSignupCompleted()
        }
        return false
    }
    
    func getPINNeverOverride() -> Bool{
        return self.getPINHours() == Constants.kMaxPinTimeoutValue
    }
    
    func getPINHours() -> Int {
        return UserDefaults.Keys.pinHours.get(defaultValue: Constants.kMaxPinTimeoutValue)
    }
    
    func setPINHours(hours: Int) {
        UserDefaults.Keys.pinHours.set(hours)
    }
    
    func getUserId(
        context: NSManagedObjectContext? = nil
    ) -> Int {
        if let ownerId = ownerId {
            return ownerId
        }
        if let ownerId: Int = UserDefaults.Keys.ownerId.get(), ownerId >= 0 {
            self.ownerId = ownerId
            return ownerId
        }
        if let ownerId = UserContact.getOwner(context: context)?.id {
            UserDefaults.Keys.ownerId.set(ownerId)
            self.ownerId = ownerId
        }
        
        return ownerId ?? -1
    }
    
    func getUserPubKey() -> String? {
        if let ownerPubKey = ownerPubKey {
            return ownerPubKey
        }
        if let ownerPubKey = UserDefaults.Keys.ownerPubKey.get(defaultValue: ""), !ownerPubKey.isEmpty {
            self.ownerPubKey = ownerPubKey
            return ownerPubKey
        }
        let ownerPubKey = UserContact.getOwner()?.publicKey ?? nil
        UserDefaults.Keys.ownerPubKey.set(ownerPubKey)
        self.ownerPubKey = ownerPubKey

        return ownerPubKey
    }
    
    func save(pin: String) {
        if let existingMnemonic = self.getMnemonic() {
            SphinxOnionManager.sharedInstance.appSessionPin = pin
            
            self.save(walletMnemonic: existingMnemonic) //update mnemonic encryption
        }
    }
    
    func getAppPin() -> String? {
        if let appPin = SphinxOnionManager.sharedInstance.appSessionPin {
            return appPin
        }
        return nil
    }
    
    func getPassword() -> String {
        UserDefaults.Keys.nodePassword.get(defaultValue: "")
    }
    
    func save(
        walletMnemonic: String
    ) {
        let defaultPin : String? = !isPinSet() ? SphinxOnionManager.sharedInstance.defaultInitialSignupPin : nil
        
        if let pin = getAppPin() ?? defaultPin, // apply getAppPin if it exists, otherwise apply default signup pin
            let encryptedMnemonic = SymmetricEncryptionManager.sharedInstance.encryptString(text: walletMnemonic, key: pin),
            !encryptedMnemonic.isEmpty
        {
            let _ = keychainManager.save(value: encryptedMnemonic, forComposedKey: KeychainManager.KeychainKeys.walletMnemonic.rawValue)
        }
    }
    
    func getMnemonic(
        enteredPin: String? = nil
    ) -> String? {
        let defaultPin : String? = !isPinSet() ? SphinxOnionManager.sharedInstance.defaultInitialSignupPin : enteredPin
        
        if let pin = defaultPin ?? getAppPin(),
            let encryptedMnemonic = keychainManager.getValueFor(composedKey: KeychainManager.KeychainKeys.walletMnemonic.rawValue),
            !encryptedMnemonic.isEmpty
        {
            if let value = SymmetricEncryptionManager.sharedInstance.decryptString(text: encryptedMnemonic, key: pin){
                return value
            } else if SphinxOnionManager.sharedInstance.isMnemonic(code: encryptedMnemonic){ // on legacy, requires migration to encrypted paradigm
                save(walletMnemonic: encryptedMnemonic) // ensure we encrypt this time
                return encryptedMnemonic
            }
            
        }
        return nil
    }
    
    func save(balance: UInt64) {
        let _ = keychainManager.save(
            value: String(balance),
            forComposedKey: KeychainManager.KeychainKeys.balanceMsats.rawValue
        )
    }
    
    func getBalanceSats() -> Int? {
        if let value = keychainManager.getValueFor(
            composedKey: KeychainManager.KeychainKeys.balanceMsats.rawValue
        ), !value.isEmpty, let intValue = Int(value)
        {
            return intValue / 1000
        }
        return nil
    }
    
    func getValueFor(keychainKey: KeychainManager.KeychainKeys, userDefaultKey: DefaultKey<String>? = nil) -> String {
        if let value = userDefaultKey?.get(defaultValue: ""), !value.isEmpty {
            if keychainManager.save(value: value, forKey: keychainKey.rawValue) {
                userDefaultKey?.removeValue()
            }
            return value
        }
        
        if let value = keychainManager.getValueFor(key: keychainKey.rawValue), !value.isEmpty {
            return value
        }
        
        return ""
    }

    
    func getStoredPin() -> String?{
        let pin = getValueFor(keychainKey: KeychainManager.KeychainKeys.pin, userDefaultKey: UserDefaults.Keys.defaultPIN)
        return (!pin.isEmpty) ? pin : nil
    }
    
    func getStoredUnencryptedMnemonic() -> String?{
        if let value = keychainManager.getValueFor(composedKey: KeychainManager.KeychainKeys.walletMnemonic.rawValue), !value.isEmpty{
            return value
        }
        
        return nil
    }
    
    func clearStoredPin() {
        let _ = keychainManager.deleteValueFor(key: KeychainManager.KeychainKeys.pin.rawValue)
    }
    
    func clearData() {
        CoreDataManager.sharedManager.clearCoreDataStore()
        let _ = keychainManager.deleteValueFor(composedKey: KeychainManager.KeychainKeys.walletMnemonic.rawValue)
        UserDefaults.resetUserDefaults()
    }
}
