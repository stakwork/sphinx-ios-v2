//
//  SphinxOnionManager.swift
//  
//
//  Created by James Carucci on 11/8/23.
//

import Foundation
import CocoaMQTT
import ObjectMapper
import SwiftyJSON
import CoreData


class SphinxOnionManager : NSObject {
    
    private static var _sharedInstance: SphinxOnionManager? = nil

    static var sharedInstance: SphinxOnionManager {
        if _sharedInstance == nil {
            _sharedInstance = SphinxOnionManager()
        }
        return _sharedInstance!
    }

    static func resetSharedInstance() {
        _sharedInstance = nil
    }
    
    let walletBalanceService = WalletBalanceService()
    
    ///Invite
    var pendingInviteLookupByTag : [String:String] = [String:String]()
    var stashedContactInfo: String? = nil
    var stashedInitialTribe: String? = nil
    var stashedInviteCode: String? = nil
    var stashedInviterAlias: String? = nil
    
    var watchdogTimer: Timer? = nil
    var reconnectionTimer: Timer? = nil
    var sendTimeoutTimers: [String: Timer] = [:]
    
    var chatsFetchParams : ChatsFetchParams? = nil
    var messageFetchParams : MessageFetchParams? = nil
    
    var deletedTribesPubKeys: [String] {
        get {
            return UserDefaults.Keys.deletedTribesPubKeys.get(defaultValue: [])
        }
        set {
            UserDefaults.Keys.deletedTribesPubKeys.set(newValue)
        }
    }
    
    var isV2InitialSetup: Bool = false
    var isV2Restore: Bool = false
    var shouldPostUpdates : Bool = false
    
    let tribeMinSats: Int = 3000
    let kRoutingOffset = 3
    
    var restoredContactInfoTracker = [String]()
    
    var vc: UIViewController! = nil
    var mqtt: CocoaMQTT! = nil
    
    var isConnected : Bool = false{
        didSet{
            NotificationCenter.default.post(name: .onConnectionStatusChanged, object: nil)
        }
    }
    
    var delayedRRObjects: [Int: RunReturn] = [:]
    var delayedRRTimers: [Int: Timer] = [:]
    var pingsMap: [String: String] = [:]
    var readyForPing = false
    
    var msgTotalCounts : MsgTotalCounts? = nil
    
    typealias RestoreProgressCallback = (Int) -> Void
    var messageRestoreCallback: RestoreProgressCallback? = nil
    var contactRestoreCallback: RestoreProgressCallback? = nil
    var hideRestoreCallback: (() -> ())? = nil
    var errorCallback: (() -> ())? = nil
    var tribeMembersCallback: (([String: AnyObject]) -> ())? = nil
    var paymentsHistoryCallback: ((String?, String?) -> ())? = nil
    var inviteCreationCallback: ((String?) -> ())? = nil
    
    ///Session Pin to decrypt mnemonic and seed
    var appSessionPin : String? = nil
    var defaultInitialSignupPin : String = "111111"
    
    public static let kContactsBatchSize = 100
    public static let kMessageBatchSize = 100

    public static let kCompleteStatus = "COMPLETE"
    public static let kFailedStatus = "FAILED"
    
    let newMessageBubbleHelper = NewMessageBubbleHelper()
    let managedContext = CoreDataManager.sharedManager.persistentContainer.viewContext
    
    var notificationsResultsController: NSFetchedResultsController<NotificationData>!
    
    let kHostedTorrentBaseURL = "https://files.bt2.bard.garden:21433"
    let kAllTorrentLookupBaseURL = "https://tome.bt2.bard.garden:21433"
    var btAuthDict : NSDictionary? = nil
    
    let kSharedGroupName = "group.com.gl.sphinx.v2"
    let kChildIndexesStorageKey = "childIndexesStorageKey"
    
    var onionState: [String: [UInt8]] = [:]
    
    var mutationKeys: [String] {
        get {
            if let onionState: String = UserDefaults.Keys.onionState.get() {
                return onionState.components(separatedBy: ",")
            }
            return []
        }
        set {
            UserDefaults.Keys.onionState.set(
                newValue.joined(separator: ",")
            )
        }
    }
    
    //MARK: Hardcoded Values!
    var serverIP: String {
        get {
            if let storedServerIP: String = UserDefaults.Keys.serverIP.get() {
                return storedServerIP
            }
            return kTestServerIP
        }
    }
    
    var serverPORT: UInt16 {
        get {
            if let storedServerPORT: Int = UserDefaults.Keys.serverPORT.get() {
                return UInt16(storedServerPORT)
            }
            return kTestServerPort
        }
    }
    
    var storedRouteUrl: String? = nil
    var routerUrl: String {
        get {
            if let storedRouteUrl = storedRouteUrl {
                return storedRouteUrl
            }
            if let routerUrl: String = UserDefaults.Keys.routerUrl.get() {
                storedRouteUrl = routerUrl
                return routerUrl
            }
            storedRouteUrl = kTestRouterUrl
            return kTestRouterUrl
        }
        set {
            UserDefaults.Keys.routerUrl.set(newValue)
        }
    }
    
    var routerPubkey: String? {
        get {
            if let routerPubkey: String = UserDefaults.Keys.routerPubkey.get() {
                return routerPubkey
            }
            return nil
        }
    }
    
    var tribesServerIP: String {
        get {
            if let storedTribesServer: String = UserDefaults.Keys.tribesServerIP.get() {
                return storedTribesServer
            }
            return kTestV2TribesServer
        }
    }
    
    var defaultTribePubkey: String? {
        get {
            if let defaultTribePublicKey: String = UserDefaults.Keys.defaultTribePublicKey.get() {
                if defaultTribePublicKey.isEmpty {
                    return nil
                }
                return defaultTribePublicKey
            }
            return kTestDefaultTribe
        }
    }
    
    var pushKey: String? {
        get {
            if let value = KeychainManager.sharedInstance.getValueFor(
                composedKey: KeychainManager.KeychainKeys.pushKey.rawValue
            ), !value.isEmpty
            {
                return value
            }
            let newValue = Nonce(length: 32).hexString
            if KeychainManager.sharedInstance.save(
                value: newValue,
                forComposedKey: KeychainManager.KeychainKeys.pushKey.rawValue
            ) {
                return newValue
            }
            return nil
        }
    }
    
    var isProductionEnvStored: Bool? = nil
    var isProductionEnv : Bool {
        get {
            if let isProductionEnvStored = isProductionEnvStored {
                return isProductionEnvStored
            }
            let isProductionEnv = UserDefaults.Keys.isProductionEnv.get(defaultValue: false)
            self.isProductionEnvStored = isProductionEnv
            return isProductionEnv
        }
        set {
            UserDefaults.Keys.isProductionEnv.set(newValue)
        }
    }
    
    var network: String {
        get {
            return isProductionEnv ? "bitcoin" : "regtest"
        }
    }
    
    let kTestServerIP = "75.101.247.127"
    let kTestServerPort: UInt16 = 1883
    let kProdServerPort: UInt16 = 8883
    let kTestV2TribesServer = "75.101.247.127:8801"
    let kTestDefaultTribe = "0213ddd7df0077abe11d6ec9753679eeef9f444447b70f2980e44445b3f7959ad1"
    let kTestRouterUrl = "mixer.router1.sphinx.chat"
    
    //MARK: Callback
    ///Restore
    var totalMsgsCountCallback: (() -> ())? = nil
    var firstSCIDMsgsCallback: (([Msg]) -> ())? = nil
    var onMessageRestoredCallback: (([Msg]) -> ())? = nil
    
    var maxMessageIndex: Int? {
        get {
            if let maxMessageIndex: Int = UserDefaults.Keys.maxMessageIndex.get() {
                return maxMessageIndex
            }
            return TransactionMessage.getMaxIndex()
        }
    }
    
    ///Create tribe
    var createTribeCallback: ((String) -> ())? = nil
    
    func getAccountSeed(
        mnemonic: String? = nil
    ) -> String? {
        do {
            if let mnemonic = mnemonic { // if we have a non-default value, use it
                let seed = try sphinx.mnemonicToSeed(mnemonic: mnemonic)
                return seed
            } else if let mnemonic = UserData.sharedInstance.getMnemonic() { //pull from memory if argument is nil
                let seed = try sphinx.mnemonicToSeed(mnemonic: mnemonic)
                return seed
            } else {
                return nil
            }
        } catch {
            print("error in getAccountSeed")
            return nil
        }
    }
    
    func generateMnemonic() -> String? {
        var result : String? = nil
        do {
            result = try sphinx.mnemonicFromEntropy(
                entropy: Data.randomBytes(length: 16).hexString
            )
            guard let result = result else {
                return nil
            }
            UserData.sharedInstance.save(walletMnemonic: result)
        } catch let error {
            print("error getting seed\(error)")
        }
        return result
    }
    
    func getAccountXpub(seed: String) -> String?  {
        do {
            let xpub = try xpubFromSeed(
                seed: seed,
                time: getTimeWithEntropy(),
                network: network
            )
            return xpub
        } catch {
            return nil
        }
    }
    
    func getAccountOnlyKeysendPubkey(
        seed: String
    ) -> String? {
        do {
            let pubkey = try pubkeyFromSeed(
                seed: seed,
                idx: 0,
                time: getTimeWithEntropy(),
                network: network
            )
            return pubkey
        } catch {
            return nil
        }
    }
    
    func getTimeWithEntropy() -> String {
        let currentTimeMilliseconds = Int(Date().timeIntervalSince1970 * 1000)
        let upperBound = 1_000
        let randomInt = generateCryptographicallySecureRandomInt(upperBound: upperBound)
        let timePlusRandom = currentTimeMilliseconds + randomInt!
        let randomString = String(describing: timePlusRandom)
        return randomString
    }
    
    func connectToBroker(
        seed: String,
        xpub: String
    ) -> Bool {
        do {
            let now = getTimeWithEntropy()
            
            let sig = try rootSignMs(
                seed: seed,
                time: now,
                network: network
            )
            
            mqtt = CocoaMQTT(
                clientID: xpub,
                host: serverIP,
                port: serverPORT
            )
            
            mqtt.username = now
            mqtt.password = sig
            
            if UserDefaults.Keys.isProductionEnv.get(defaultValue: false) {
                mqtt.enableSSL = true
                mqtt.allowUntrustCACertificate = true
                
                mqtt.sslSettings = [
                    "kCFStreamSSLPeerName": "\(serverIP)" as NSObject
                ] as [String: NSObject]
            }
            
            let success = mqtt.connect()
            print("mqtt.connect success:\(success)")
            return success
        } catch {
            return false
        }
    }
    
    func disconnectMqtt(
        callback: ((Double) -> ())? = nil
    ) {
        if let mqtt = self.mqtt, mqtt.connState == .connected {
            mqtt.disconnect()
        } else {
            callback?(0.0)
        }
    }
    
    func isFetchingContent() -> Bool {
        return onMessageRestoredCallback != nil || firstSCIDMsgsCallback != nil || totalMsgsCountCallback != nil
    }
    
    func reconnectToServer(
        connectingCallback: (() -> ())? = nil,
        hideRestoreViewCallback: (()->())? = nil,
        errorCallback: (()->())? = nil
    ) {
        if let mqtt = self.mqtt, mqtt.connState == .connected && isConnected {
            ///If already fetching content, then process is already running
            if !isFetchingContent() {
                self.hideRestoreCallback = hideRestoreViewCallback
                self.getReads()
                self.syncNewMessages()
            } else {
                errorCallback?()
            }
            return
        }
        connectToServer(
            connectingCallback: connectingCallback,
            hideRestoreViewCallback: hideRestoreViewCallback,
            errorCallback: errorCallback
        )
    }
    
    func syncNewMessages() {
        let maxIndex = maxMessageIndex
        
        startAllMsgBlockFetch(
            startIndex: (maxIndex != nil) ? maxIndex! + 1 : 0,
            itemsPerPage: SphinxOnionManager.kMessageBatchSize,
            stopIndex: 0,
            reverse: false
        )
    }

    func connectToServer(
        connectingCallback: (() -> ())? = nil,
        contactRestoreCallback: RestoreProgressCallback? = nil,
        messageRestoreCallback: RestoreProgressCallback? = nil,
        hideRestoreViewCallback: (()->())? = nil,
        errorCallback: (()->())? = nil
    ){
        connectingCallback?()
        
        guard let seed = getAccountSeed(),
              let myPubkey = getAccountOnlyKeysendPubkey(seed: seed),
              let my_xpub = getAccountXpub(seed: seed) else
        {
            errorCallback?()
            hideRestoreViewCallback?()
            return
        }
        
        self.hideRestoreCallback = hideRestoreViewCallback
        self.contactRestoreCallback = contactRestoreCallback
        self.messageRestoreCallback = messageRestoreCallback
        self.errorCallback = errorCallback
        
        self.startWatchdogTimer()
        
        self.disconnectMqtt() { delay in
            
            DelayPerformedHelper.performAfterDelay(seconds: delay, completion: { [weak self] in
                guard let self = self else {
                    return
                }
                
                if self.isV2Restore {
                    contactRestoreCallback?(2)
                }
                
                let success = self.connectToBroker(seed: seed, xpub: my_xpub)
                
                if (success == false) {
                    hideRestoreViewCallback?()
                    return
                }
                
                self.mqtt.didConnectAck = { [weak self] _, _ in
                    guard let self = self else {
                        return
                    }
                    
                    self.endReconnectionTimer()
                    self.isConnected = true
                    
                    self.subscribeAndPublishMyTopics(pubkey: myPubkey, idx: 0)
                    
                    if self.isV2InitialSetup {
                        self.isV2InitialSetup = false
                        self.doInitialInviteSetup()
                    }
                     
                    if self.isV2Restore {
                        self.hideRestoreCallback = {
                            self.isV2Restore = false
                            
                            hideRestoreViewCallback?()
                        }
                        self.syncContactsAndMessages()
                    } else {
                        self.contactRestoreCallback = nil
                        self.messageRestoreCallback = nil
                        
                        self.getReads()
                        self.syncNewMessages()
                    }
                }
                
                self.mqtt.didReceiveTrust = { _, _, completionHandler in
                    completionHandler(true)
                }
                
                self.mqtt.didDisconnect = { [weak self] _, _ in
                    self?.isConnected = false
                    self?.mqtt = nil
                    self?.startReconnectionTimer()
                }
                
                self.startReconnectionTimer(delay: 2.0)
            })
        }
    }
    
    func endReconnectionTimer() {
        reconnectionTimer?.invalidate()
        reconnectionTimer = nil
    }
    
    func startReconnectionTimer(
        delay: Double = 0.5
    ) {
        if (UIApplication.shared.delegate as? AppDelegate)?.isActive == false {
            return
        }
        
        reconnectionTimer?.invalidate()
        
        reconnectionTimer = Timer.scheduledTimer(
            timeInterval: delay,
            target: self,
            selector: #selector(reconnectionTimerFired),
            userInfo: nil,
            repeats: false
        )
    }
    
    @objc func reconnectionTimerFired() {
        errorCallback?()
        
        if (UIApplication.shared.delegate as? AppDelegate)?.isActive == false {
            return
        }
        
        if !NetworkMonitor.shared.isConnected {
            return
        }
        
        connectToServer(
            contactRestoreCallback: self.contactRestoreCallback,
            messageRestoreCallback: self.messageRestoreCallback,
            hideRestoreViewCallback: self.hideRestoreCallback
        )
    }
    
    func subscribeAndPublishMyTopics(
        pubkey: String,
        idx: Int,
        inviteCode: String? = nil
    ) {
        do {
            let ret = try sphinx.setNetwork(network: network)
            let _ = handleRunReturn(rr: ret)
            
            guard let seed = getAccountSeed() else{
                return
            }
            
            mqtt.didReceiveMessage = { mqtt, receivedMessage, id in
                self.isConnected = true
                self.processMqttMessages(message: receivedMessage)
            }
            
            let ret3 = try sphinx.initialSetup(
                seed: seed,
                uniqueTime: getTimeWithEntropy(),
                state: loadOnionStateAsData(),
                device: UUID().uuidString,
                inviteCode: inviteCode
            )
            
            let _ = handleRunReturn(rr: ret3)
            
            let tribeMgmtTopic = try sphinx.getTribeManagementTopic(
                seed: seed,
                uniqueTime: getTimeWithEntropy(),
                state: loadOnionStateAsData()
            )
            
            self.mqtt.subscribe([
                (tribeMgmtTopic, CocoaMQTTQoS.qos1)
            ])
        } catch {}
    }
    
    func fetchMyAccountFromState() {
        guard let seed = getAccountSeed() else{
            return
        }
        do {
            let _ = try sphinx.pubkeyFromSeed(
                seed: seed,
                idx: 0,
                time: getTimeWithEntropy(),
                network: network
            )

            let listContactsResponse = try sphinx.listContacts(state: loadOnionStateAsData())
            saveContactsToSharedUserDefaults(contacts: listContactsResponse)
        } catch {}
    }
    
    func saveContactsToSharedUserDefaults(contacts: String) {
        var newDictionary: [String: String] = [:]
        
        if let contactsJsonArray : [[String: Any]] = getContactsJsonArray(contacts: contacts) {
            for contact in contactsJsonArray {
                let contactJson = JSON(contact)
                let index = contactJson["my_idx"].stringValue
                let publicKey = contactJson["pubkey"].stringValue
                
                if index.isNotEmpty && publicKey.isNotEmpty {
                    newDictionary[index] = publicKey
                }
            }
        }
        
        let pubkeys: [String] = Array(newDictionary.values)
        let contacts = UserContact.getContactsWith(pubkeys: pubkeys).compactMap({ ($0.publicKey, $0.nickname) })
        let tribes = Chat.getChatTribesFor(ownerPubkeys: pubkeys).compactMap({ ($0.ownerPubkey, $0.name) })
        
        var childNameDictionary: [String: String] = [:]
        
        for (key, value) in newDictionary {
            if let contact = contacts.filter({ $0.0 == value }).first {
                childNameDictionary["contact-\(key)"] = contact.1
                continue
            }
            
            if let tribe = tribes.filter({ $0.0 == value }).first {
                childNameDictionary["tribe-\(key)"] = tribe.1
                continue
            }
        }
        
        if let jsonString = convertToJsonString(dictionary: childNameDictionary), let pushKey = pushKey {
            if let encrypted = SymmetricEncryptionManager.sharedInstance.encryptString(text: jsonString, key: pushKey) {
                let sharedUserDefaults = UserDefaults(suiteName: kSharedGroupName)
                sharedUserDefaults?.setValue(encrypted, forKey: kChildIndexesStorageKey)
                sharedUserDefaults?.synchronize()
            }
        }
    }
    
    func convertToJsonString(dictionary: [String: String]) -> String? {
        let jsonData  = try? JSONSerialization.data(
            withJSONObject: dictionary,
            options: JSONSerialization.WritingOptions(rawValue: 0)
        )
        
        if let jsonData = jsonData {
            return String(data: jsonData, encoding: .utf8)
        }
        
        return nil
    }
    
    func getContactsJsonArray(contacts: String) -> [[String: Any]]? {
        if let jsonData = contacts.data(using: .utf8) {
            do {
                // Parse the JSON data into a dictionary
                if let jsonDict = try JSONSerialization.jsonObject(
                    with: jsonData,
                    options: []
                ) as? [[String: Any]] {
                    return jsonDict
                }
            } catch {
                return nil
            }
        }
        return nil
    }
    
    func deleteOwnerFromState() {
        if let publicKey = UserContact.getOwner()?.publicKey {
            SphinxOnionManager.sharedInstance.deleteContactFromState(pubkey: publicKey)
        }
    }
    
    func createMyAccount(
        mnemonic: String,
        inviteCode: String? = nil
    ) -> Bool {
        //1. Generate Seed -> Display to screen the mnemonic for backup???
        guard let seed = getAccountSeed(mnemonic: mnemonic) else {
            //possibly send error message?
            return false
        }
        //2. Create the 0th pubkey
        guard let pubkey = getAccountOnlyKeysendPubkey(seed: seed), let my_xpub = getAccountXpub(seed: seed) else{
            return false
        }
        //3. Connect to server/broker
        let success = connectToBroker(seed: seed, xpub: my_xpub)
        
        //4. Subscribe to relevant topics based on OK key
        let idx = 0
        
        if success {
            mqtt.didReceiveMessage = { mqtt, receivedMessage, id in
                self.isConnected = true
                self.processMqttMessages(message: receivedMessage)
            }
            
            mqtt.didDisconnect = { _, _ in
                self.isConnected = false
                self.mqtt = nil
                self.startReconnectionTimer()
            }
            
            mqtt.didReceiveTrust = { _, _, completionHandler in
                completionHandler(true)
            }
            
            //subscribe to relevant topics
            mqtt.didConnectAck = { _, _ in
                self.isConnected = true
                //self.showSuccessWithMessage("MQTT connected")
                print("SphinxOnionManager: MQTT Connected")
                print("mqtt.didConnectAck")
                
                self.subscribeAndPublishMyTopics(
                    pubkey: pubkey,
                    idx: idx,
                    inviteCode: inviteCode
                )
            }
        }
        return success
    }
    
    func processMqttMessages(message: CocoaMQTTMessage) {
        guard let seed = getAccountSeed() else {
            return
        }
        if !readyForPing && message.topic.contains("ping") {
            return
        }
        do {
            let owner = UserContact.getOwner()
            let alias = owner?.nickname ?? ""
            let pic = owner?.avatarUrl ?? ""
            
            let ret4 = try handle(
                topic: message.topic,
                payload: Data(message.payload),
                seed: seed,
                uniqueTime: getTimeWithEntropy(),
                state: self.loadOnionStateAsData(),
                myAlias: alias,
                myImg: pic
            )
            
            let _ = handleRunReturn(
                rr: ret4,
                topic: message.topic
            )
        } catch let error {
            print(error)
        }
    }
    
    func showSuccessWithMessage(_ message: String) {
        self.newMessageBubbleHelper.showGenericMessageView(
            text: message,
            delay: 6,
            textColor: UIColor.white,
            backColor: UIColor.Sphinx.PrimaryGreen,
            backAlpha: 1.0
        )
    }
}

extension SphinxOnionManager {//Sign Up UI Related:
    func showMnemonicToUser(
        completion:@escaping (Bool)->()
    ){
        let generateSeedCallback: (() -> ()) = {
            guard let mneomnic = self.generateMnemonic(), let _ = self.vc as? NewUserSignupFormViewController else {
                completion(false)
                return
            }
            
            self.showMnemonicToUser(mnemonic: mneomnic, callback: {
                completion(true)
            })
        }
        
        generateSeedCallback()
    }
    
    func importSeedPhrase(){
        if let vc = self.vc as? ImportSeedViewDelegate {
            vc.showImportSeedView()
        }
    }
    
    func showMnemonicToUser(mnemonic: String, callback: @escaping () -> ()) {
        guard let _ = vc else {
            callback()
            return
        }
        
        AlertHelper.showAlert(
            title: "profile.store-mnemonic".localized,
            message: mnemonic,
            on: vc,
            confirmLabel: "Copy",
            completion: {
                ClipboardHelper.copyToClipboard(text: mnemonic, message: "profile.mnemonic-copied".localized)
                callback()
            }
        )
    }
    
    func mapNotificationToChat(notificationUserInfo : [String: AnyObject]) -> (Chat, String)? {
        if let encryptedChild = getEncryptedIndexFrom(notification: notificationUserInfo),
           let chat = findChatForNotification(child: encryptedChild)
        {
            return (chat, encryptedChild)
        }
        
        return nil
    }
    
    func getEncryptedIndexFrom(
        notification: [String: AnyObject]?
    ) -> String? {
        if
            let notification = notification,
            let aps = notification["aps"] as? [String: AnyObject],
            let customData = aps["custom_data"] as? [String: AnyObject]
        {
            if let chatId = customData["child"] as? String {
                return chatId
            }
        }
        return nil
    }
}

