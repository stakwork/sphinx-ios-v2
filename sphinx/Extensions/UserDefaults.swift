//
//  UserDefaults.swift
//  sphinx
//
//  Created by Tomas Timinskas on 12/09/2019.
//  Copyright © 2019 Sphinx. All rights reserved.
//

import Foundation

extension UserDefaults {
    public enum Keys {
        public static let accountUUID = DefaultKey<String>("accountUUID")
        public static let hideBalances = DefaultKey<Bool>("hideBalances")
        public static let ownerId = DefaultKey<Int>("ownerId")
        public static let ownerPubKey = DefaultKey<Int>("ownerPubKey")
        public static let inviteString = DefaultKey<String>("inviteString")
        public static let deviceId = DefaultKey<String>("deviceId")
        public static let voipDeviceId = DefaultKey<String>("voipDeviceId")
        public static let chatId = DefaultKey<Int>("chatId")
        public static let contactId = DefaultKey<Int>("contactId")
        public static let subscriptionQuery = DefaultKey<String>("subscriptionQuery")
        public static let invoiceQuery = DefaultKey<String>("invoiceQuery")
        public static let tribeQuery = DefaultKey<String>("tribeQuery")
        public static let callLinkUrl = DefaultKey<String>("callLinkUrl")
        public static let attachmentsToken = DefaultKey<String>("attachmentsToken")
        public static let attachmentsTokenExpDate = DefaultKey<Date>("attachmentsTokenExpDate")
        public static let inviterNickname = DefaultKey<String>("inviterNickname")
        public static let inviterPubkey = DefaultKey<String>("inviterPubkey")
        public static let inviterRouteHint = DefaultKey<String>("inviterRouteHint")
        public static let inviteAction = DefaultKey<String>("inviteAction")
        public static let welcomeMessage = DefaultKey<String>("welcomeMessage")
        public static let signupStep = DefaultKey<Int>("signupStep")
        public static let paymentProcessedInvites = DefaultKey<[String]>("paymentProcessedInvites")
        public static let challengeQuery = DefaultKey<String>("challengeQuery")
        public static let redeemSatsQuery = DefaultKey<String>("redeemSatsQuery")
        public static let authQuery = DefaultKey<String>("authQuery")
        public static let personQuery = DefaultKey<String>("personQuery")
        public static let saveQuery = DefaultKey<String>("saveQuery")
        public static let shareContentQuery = DefaultKey<String>("shareContentQuery")
        public static let glyphQuery = DefaultKey<String>("glyphQuery")
        public static let inviteCode = DefaultKey<String>("inviteCode")
        public static let defaultPIN = DefaultKey<String>("currentPin")
        public static let lastPinDate = DefaultKey<Date>("lastPinDate")
        public static let pinHours = DefaultKey<Int>("pinHours")
        public static let maxMemory = DefaultKey<Int>("maxMemory")
        public static let inviteServerURL = DefaultKey<String>("inviteServerURL")
        public static let fileServerURL = DefaultKey<String>("fileServerURL")
        public static let meetingServerURL = DefaultKey<String>("meetingServerURL")
        public static let meetingPmtAmount = DefaultKey<Int>("meetingPmtAmount")
        public static let appAppearence = DefaultKey<Int>("appAppearence")
        public static let messagesSize = DefaultKey<Int>("messagesSize")
        public static let shouldTrackActions = DefaultKey<Bool>("shouldTrackActions")
        public static let shouldAutoDownloadSubscribedPods = DefaultKey<Bool>("shouldAutoDownloadSubscribedPods")
        public static let setupSigningDevice = DefaultKey<Bool>("setupSigningDevice")
        public static let setupPhoneSigner = DefaultKey<Bool>("setupPhoneSigner")
        public static let phoneSignerHost = DefaultKey<String>("phoneSignerHost")
        public static let phoneSignerNetwork = DefaultKey<String>("phoneSignerNetwork")
        public static let phoneSignerRelay = DefaultKey<String>("phoneSignerRelay")
        public static let clientID = DefaultKey<String>("clientID")
        public static let lssNonce = DefaultKey<String>("lssNonce")
        public static let signerKeys = DefaultKey<String>("signerKeys")
        public static let onionState = DefaultKey<String>("onionState")
        public static let sequence = DefaultKey<String>("sequence")
        public static let deletedTribesPubKeys = DefaultKey<[String]>("deletedTribesPubKeys")
        public static let maxMessageIndex = DefaultKey<Int>("maxMessageIndex")
        public static let isProductionEnv = DefaultKey<Bool>("isProductionEnv")
        public static let serverIP = DefaultKey<String>("serverIP")
        public static let serverPORT = DefaultKey<Int>("serverPORT")
        public static let tribesServerIP = DefaultKey<String>("tribesServerIP")
        public static let defaultTribePublicKey = DefaultKey<String>("defaultTribePublicKey")
        public static let routerUrl = DefaultKey<String>("routerUrl")
        public static let routerPubkey = DefaultKey<String>("routerPubkey")
        public static let skipAds = DefaultKey<Bool>("skipAds")
        public static let didMigrateToTZ = DefaultKey<Bool>("didMigrateToTZ")
        public static let systemTimezone = DefaultKey<String>("systemTimezone")
    }
    
    class func resetUserDefaults() {
        let defaults = UserDefaults.standard
        let dictionary = defaults.dictionaryRepresentation()
        dictionary.keys.forEach { key in
            defaults.removeObject(forKey: key)
        }
        defaults.synchronize()
    }
    
    func object<T: Codable>(_ type: T.Type, with key: String, usingDecoder decoder: JSONDecoder = JSONDecoder()) -> T? {
        guard let data = self.value(forKey: key) as? Data else { return nil }
        return try? decoder.decode(type.self, from: data)
    }

    func set<T: Codable>(object: T, forKey key: String, usingEncoder encoder: JSONEncoder = JSONEncoder()) {
        let data = try? encoder.encode(object)
        self.set(data, forKey: key)
    }
}

public class DefaultKey<S> {
    private let name: String
    
    init(_ name: String) {
        self.name = name
    }
    
    func get<T>() -> T? {
        return UserDefaults.standard.value(forKey: name) as? T
    }
    
    func getObject<T: Codable>() -> T? {
        return UserDefaults.standard.object(T.self, with: name)
    }
    
    func get<T>(defaultValue: T) -> T {
        return (UserDefaults.standard.value(forKey: name) as? T) ?? defaultValue
    }
    
    func set<T>(_ value: T?) {
        if let value = value {
            UserDefaults.standard.setValue(value, forKey: name)
            UserDefaults.standard.synchronize()
        } else {
            removeValue()
        }
    }
    
    func setObject<T: Codable>(_ object: T?) {
        if let object = object {
            UserDefaults.standard.set(object: object, forKey: name)
            UserDefaults.standard.synchronize()
        } else {
            removeValue()
        }
    }
    
    public func removeValue() {
        UserDefaults.standard.removeObject(forKey: name)
        UserDefaults.standard.synchronize()
    }
}
