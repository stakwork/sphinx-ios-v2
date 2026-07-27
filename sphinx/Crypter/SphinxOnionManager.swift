//
//  SphinxOnionManager.swift
//  
//
//  Created by James Carucci on 11/8/23.
//

import Foundation
import UIKit
import Network
import CocoaMQTT
import ObjectMapper
import SwiftyJSON
import CoreData


class SphinxOnionManager : NSObject, @unchecked Sendable {
    
    nonisolated(unsafe) private static var _sharedInstance: SphinxOnionManager? = nil

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
    
    var reconnectionTimer: Timer? = nil
    var watchdogTimer: Timer? = nil
    var lastInboundTime: Date? = nil
    var reconnectAttemptCount: Int = 0
    var sendTimeoutTimers: [String: Timer] = [:]
    var paymentTimeoutTimers: [String: Timer] = [:]
    
    var chatsFetchParams : ChatsFetchParams? = nil
    var messageFetchParams : MessageFetchParams? = nil
    var messagePerContactFetchParams : MessagePerContactFetchParams? = nil
    
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
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .onConnectionStatusChanged, object: nil)
            }
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
    var hideRestoreCallback: ((Bool) -> ())? = nil
    var errorCallback: (() -> ())? = nil
    var backgroundDisconnectCompletion: (() -> ())?
    private var connectionInProgress: Bool = false
    private let connectionLock = NSLock()
    private var connectionTimeoutTimer: Timer?
    var tribeMembersCallback: (([String: AnyObject]) -> ())? = nil
    var paymentsHistoryCallback: ((String?, String?) -> ())? = nil
    var inviteCreationCallback: ((String?) -> ())? = nil
    var invoiceGeneratedCallback: ((String?) -> Void)? = nil
    var invoiceGeneratedTimeoutTimer: Timer? = nil
    
    ///Session Pin to decrypt mnemonic and seed
    var appSessionPin : String? = nil
    var defaultInitialSignupPin : String = "111111"
    
    public static let kContactsBatchSize = 100
    public static let kMessageBatchSize = 100
    static let kMqttKeepAlive: UInt16 = 15
    static let kConnectionTimeoutInterval: TimeInterval = 15.0

    public static let kCompleteStatus = "COMPLETE"
    public static let kFailedStatus = "FAILED"
    
    let newMessageBubbleHelper = NewMessageBubbleHelper()
    let managedContext = CoreDataManager.sharedManager.persistentContainer.viewContext
    var backgroundContext = CoreDataManager.sharedManager.getBackgroundContext()
    
    var notificationsResultsController: NSFetchedResultsController<NotificationData>!

    var pendingSentStatusWorkItem: DispatchWorkItem?
    var pendingStatusCheckTags: Set<String> = []
    
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
    
    // MARK: Background Fetch
    private let backgroundFetchQueue = DispatchQueue(label: "com.sphinx.backgroundFetch")
    private let fetchLock = NSLock()
    private(set) var backgroundFetchInProgress = false
    var backgroundFetchCompletionHandler: ((UIBackgroundFetchResult) -> Void)?
    var activeFetchBackgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    private var bgFetchTimeoutTimer: Timer?

    //MARK: Callback
    ///Restore
    var totalMsgsCountCallback: (() -> ())? = nil
    var firstSCIDMsgsCallback: (([Msg]) -> ())? = nil
    var onMessageRestoredCallback: (([Msg]) -> ())? = nil
    
    var restoringMsgsForPublicKey: String? = nil
    var onMessagePerPublicKeyRestoredCallback: ((Int) -> ())? = nil
    
    var maxMessageIndex: Int? {
        get {
            if let maxMessageIndex: Int = UserDefaults.Keys.maxMessageIndex.get() {
                return maxMessageIndex
            }
            return TransactionMessage.getMaxIndex()
        }
        set {
            UserDefaults.Keys.maxMessageIndex.set(newValue)
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
                entropy: {
                    var bytes = [UInt8](repeating: 0, count: 16)
                    SecRandomCopyBytes(kSecRandomDefault, 16, &bytes)
                    return Data(bytes).hexString
                }()
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
    
    func getOrCreateMqttSessionId() -> String {
        if let existing: String = UserDefaults.Keys.mqttSessionId.get(), !existing.isEmpty {
            return existing
        }
        let newId = UUID().uuidString
        UserDefaults.Keys.mqttSessionId.set(newId)
        return newId
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

            if let existing = self.mqtt {
                print("[MQTT] Force-closing existing connection (state: \(existing.connState)) before opening new one")
                existing.didDisconnect = {(_, _) in }
                existing.disconnect()
                self.mqtt = nil
            }

            mqtt = CocoaMQTT(
                clientID: xpub,
                host: serverIP,
                port: serverPORT
            )

            mqtt.username = now
            mqtt.password = sig
            mqtt.keepAlive = SphinxOnionManager.kMqttKeepAlive
            mqtt.backgroundOnSocket = false

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
        // Cancel reconnection timer and watchdog to prevent background reconnection attempts
        endReconnectionTimer()
        stopWatchdog()
        connectionTimeoutTimer?.invalidate()
        connectionTimeoutTimer = nil

        delayedRRTimers.values.forEach { $0.invalidate() }
        delayedRRTimers.removeAll()

        paymentTimeoutTimers.values.forEach { $0.invalidate() }
        paymentTimeoutTimers.removeAll()

        if let mqtt = self.mqtt, mqtt.connState == .connected || mqtt.connState == .connecting {
            if mqtt.connState == .connecting {
                print("[MQTT] Disconnecting mid-handshake connection (state: .connecting)")
            }
            backgroundDisconnectCompletion = callback.map { cb in { cb(0.0) } }
            mqtt.disconnect()
        } else {
            callback?(0.0)
        }
    }
    
    func isFetchingContent() -> Bool {
        fetchLock.lock()
        defer { fetchLock.unlock() }
        return backgroundFetchInProgress || onMessageRestoredCallback != nil || firstSCIDMsgsCallback != nil || totalMsgsCountCallback != nil
    }

    func beginBackgroundFetch(completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        if (UIApplication.shared.delegate as? AppDelegate)?.isActive == true {
            print("[BGFetch] App already active — skipping background fetch")
            completionHandler(.noData)
            return
        }

        fetchLock.lock()
        guard !backgroundFetchInProgress else {
            fetchLock.unlock()
            print("[BGFetch] Fetch already in progress — skipping duplicate")
            backgroundFetchCompletionHandler = completionHandler
            return
        }
        backgroundFetchInProgress = true
        backgroundFetchCompletionHandler = completionHandler
        fetchLock.unlock()

        activeFetchBackgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "MessageFetch") { [weak self] in
            self?.expireBackgroundFetch()
        }
        print("[BGFetch] UIBackgroundTask started: \(activeFetchBackgroundTaskID)")

        // One-shot network check before attempting MQTT reconnect. NWPathMonitor fires
        // its first update immediately, so this adds no meaningful latency on a good
        // connection but prevents hanging indefinitely when the network is not ready.
        let netCheck = NWPathMonitor()
        netCheck.pathUpdateHandler = { [weak self] path in
            netCheck.cancel()
            guard path.status == .satisfied else {
                print("[BGFetch] No network available — aborting fetch")
                self?.endBackgroundFetch(result: .noData)
                return
            }
            print("[BGFetch] Network available — starting reconnect")
            self?.reconnectToServer(
                hideRestoreViewCallback: { _ in
                    print("[BGFetch] reconnect hideRestoreViewCallback fired")
                },
                errorCallback: { [weak self] in
                    print("[BGFetch] reconnect errorCallback — ending fetch")
                    self?.endBackgroundFetch(result: .noData)
                }
            )
            // Hard cap: end the fetch after 25s regardless. Prevents the background task
            // from staying open for minutes/hours waiting on a slow server MQTT response.
            DispatchQueue.main.async { [weak self] in
                self?.bgFetchTimeoutTimer?.invalidate()
                self?.bgFetchTimeoutTimer = Timer.scheduledTimer(withTimeInterval: 25.0, repeats: false) { [weak self] _ in
                    print("[BGFetch] Hard timeout fired after 25s — ending background fetch")
                    self?.endBackgroundFetch(result: .noData)
                }
            }
        }
        netCheck.start(queue: DispatchQueue(label: "com.sphinx.bgfetch.netcheck"))
    }

    func endBackgroundFetch(result: UIBackgroundFetchResult = .newData) {
        fetchLock.lock()
        guard backgroundFetchInProgress else {
            fetchLock.unlock()
            return
        }
        backgroundFetchInProgress = false
        let handler = backgroundFetchCompletionHandler
        backgroundFetchCompletionHandler = nil
        let taskID = activeFetchBackgroundTaskID
        activeFetchBackgroundTaskID = .invalid
        fetchLock.unlock()
        DispatchQueue.main.async { [weak self] in
            self?.bgFetchTimeoutTimer?.invalidate()
            self?.bgFetchTimeoutTimer = nil
        }

        endReconnectionTimer() // Disarm any timer armed during fetch before signalling the system
        print("[BGFetch] completionHandler firing with result: \(result)")
        handler?(result)

        if taskID != .invalid {
            UIApplication.shared.endBackgroundTask(taskID)
            print("[BGFetch] UIBackgroundTask ended: \(taskID)")
        }
    }

    private func expireBackgroundFetch() {
        // End the task and fire the completion handler synchronously. The background
        // task expiration handler must return quickly — waiting for an async MQTT
        // disconnect callback that may never arrive (flaky network) leaves
        // endBackgroundTask uncalled and the watchdog kills the process (0x8BADF00D).
        print("[BGFetch] expire triggered — ending task immediately")
        endBackgroundFetch(result: .noData)
        disconnectMqtt()
    }
    
    func prepareForForeground(disconnectCallback: @escaping (() -> ())) {
        print("[Lifecycle] prepareForForeground")
        // Called from applicationWillEnterForeground before reconnectToServer.
        // Tears down any in-flight BGFetch connection so the foreground reconnect
        // isn't blocked by connectionInProgress or a stale .connecting MQTT state.
        endBackgroundFetch(result: .noData)
        stopWatchdog()
        reconnectAttemptCount = 0
        connectionInProgress = false
        isConnected = false
        if let existing = self.mqtt {
            self.mqtt = nil
            existing.didDisconnect = { _, _ in }
            existing.didConnectAck = { _, _ in }
            existing.disconnect() // fire-and-forget
            disconnectCallback()  // don't wait — call immediately
        } else {
            disconnectCallback()
        }
    }

    func reconnectToServer(
        connectingCallback: (() -> ())? = nil,
        contactRestoreCallback: RestoreProgressCallback? = nil,
        messageRestoreCallback: RestoreProgressCallback? = nil,
        hideRestoreViewCallback: ((Bool)->())? = nil,
        errorCallback: (()->())? = nil
    ) {
        if let mqtt = self.mqtt {
            if mqtt.connState == .connecting {
                return
            }
            if mqtt.connState == .connected && isConnected {
                ///If already fetching content, then process is already running
//                if !isFetchingContent() {
//                    hideRestoreCallback = hideRestoreViewCallback
//                    startNewMsgsSync()
//                    listAndUpdateContacts()
//                } else {
                    errorCallback?()
//                }
                return
            }
        }
        connectToServer(
            connectingCallback: connectingCallback,
            contactRestoreCallback: contactRestoreCallback,
            messageRestoreCallback: messageRestoreCallback,
            hideRestoreViewCallback: hideRestoreViewCallback,
            errorCallback: errorCallback
        )
    }
    
    func startNewMsgsSync() {
        self.syncNewMessages()
//        self.getReads()
//        self.getMuteLevels()
//        // Run these operations in parallel for faster sync
//        let syncGroup = DispatchGroup()
//        let syncQueue = DispatchQueue(label: "com.sphinx.newMsgsSync", attributes: .concurrent)
//
//        syncGroup.enter()
//        syncQueue.async {
//            self.getReads()
//            syncGroup.leave()
//        }
//
//        syncGroup.enter()
//        syncQueue.async {
//            self.getMuteLevels()
//            syncGroup.leave()
//        }
//
//        syncGroup.enter()
//        syncQueue.async {
//            self.syncNewMessages()
//            syncGroup.leave()
//        }
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
        hideRestoreViewCallback: ((Bool)->())? = nil,
        errorCallback: (()->())? = nil
    ){
        connectingCallback?()

        guard let seed = getAccountSeed(),
              let myPubkey = getAccountOnlyKeysendPubkey(seed: seed),
              let my_xpub = getAccountXpub(seed: seed) else
        {
            errorCallback?()
            return
        }
        
        self.hideRestoreCallback = hideRestoreViewCallback
        self.contactRestoreCallback = contactRestoreCallback
        self.messageRestoreCallback = messageRestoreCallback
        self.errorCallback = errorCallback

        // Show 2% immediately after storing callbacks so the progress view appears
        // even if an early-return guard fires below (e.g. already connecting from
        // a parallel reconnectToServer call triggered by applicationWillEnterForeground).
        if isV2Restore && !UserDefaults.Keys.isRestoreCompleted.get(defaultValue: false) {
            self.contactRestoreCallback?(2)
        }

        if let mqtt = self.mqtt {
            if mqtt.connState == .connecting {
                print("[MQTT] connectToServer skipped — already connecting")
                return
            }
            if mqtt.connState == .connected && isConnected {
                print("[MQTT] connectToServer skipped — already connected")
                if isV2Restore && !UserDefaults.Keys.isRestoreCompleted.get(defaultValue: false) {
                    syncContactsAndMessages()
                } else {
                    isV2Restore = false
                    startNewMsgsSync()
                }
                return
            }
        }

        connectionLock.lock()
        let alreadyConnecting = connectionInProgress
        if !alreadyConnecting { connectionInProgress = true }
        connectionLock.unlock()

        guard !alreadyConnecting else {
            print("[MQTT] connectToServer skipped — connection already in progress")
            return
        }

        if !isV2Restore || UserDefaults.Keys.isRestoreCompleted.get(defaultValue: false) {
            isV2Restore = false
        }

        let success = connectToBroker(seed: seed, xpub: my_xpub)

        if (success == false) {
            connectionInProgress = false
            hideRestoreViewCallback?(false)
            let appIsActive = (UIApplication.shared.delegate as? AppDelegate)?.isActive ?? false
            if appIsActive {
                startReconnectionTimer()
            }
            return
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.connectionTimeoutTimer?.invalidate()
            self.connectionTimeoutTimer = Timer.scheduledTimer(withTimeInterval: SphinxOnionManager.kConnectionTimeoutInterval, repeats: false) { [weak self] _ in
                guard let self = self, self.connectionInProgress else { return }
                print("[MQTT] Connection timed out after 30s — force-closing and retrying")
                self.connectionInProgress = false
                let dead = self.mqtt
                self.mqtt = nil
                dead?.didDisconnect = { _, _ in }
                dead?.didConnectAck = { _, _ in }
                dead?.disconnect()
                let appIsActive = (UIApplication.shared.delegate as? AppDelegate)?.isActive ?? false
                if appIsActive {
                    self.startReconnectionTimer()
                }
            }
        }
        
        mqtt.didConnectAck = { [weak self] _, _ in
            guard let self = self else {
                return
            }
            self.connectionTimeoutTimer?.invalidate()
            self.connectionTimeoutTimer = nil
            self.isConnected = true
            self.connectionInProgress = false
            self.endReconnectionTimer()
            self.reconnectAttemptCount = 0
            self.startWatchdog()
            
            self.subscribeAndPublishMyTopics(pubkey: myPubkey, idx: 0)
            
            if self.isV2InitialSetup {
                self.isV2InitialSetup = false
                self.doInitialInviteSetup()
            }
             
            if self.isV2Restore && !UserDefaults.Keys.isRestoreCompleted.get(defaultValue: false) {
                self.hideRestoreCallback = { [weak self] _ in
                    self?.isV2Restore = false
                    UserDefaults.Keys.isRestoreCompleted.set(true)
                    hideRestoreViewCallback?(true)
                }
                self.syncContactsAndMessages()
            } else {
                self.isV2Restore = false
                self.contactRestoreCallback = nil
                self.messageRestoreCallback = nil
                
                self.startNewMsgsSync()
            }
        }
        
        mqtt.didReceiveTrust = { _, _, completionHandler in
            completionHandler(true)
        }
        
        mqtt.didDisconnect = { [weak self] _, _ in
            self?.connectionTimeoutTimer?.invalidate()
            self?.connectionTimeoutTimer = nil
            self?.connectionInProgress = false
            self?.isConnected = false
            self?.mqtt = nil
            self?.backgroundDisconnectCompletion?()
            self?.backgroundDisconnectCompletion = nil
            // Guard before any dispatch — if backgrounded, do not schedule reconnection
            let appIsActive = (UIApplication.shared.delegate as? AppDelegate)?.isActive ?? false
            if !appIsActive {
                if self?.backgroundFetchInProgress == true {
                    print("[BGFetch] MQTT dropped mid-fetch — ending background task")
                    self?.endBackgroundFetch(result: .noData)
                }
                return
            }
            self?.stopWatchdog()
            self?.startReconnectionTimer()
        }
    }
    
    func endReconnectionTimer() {
        reconnectionTimer?.invalidate()
        reconnectionTimer = nil
    }
    
    func startReconnectionTimer() {
        let factor = pow(2.0, Double(reconnectAttemptCount))
        let jitter = Double.random(in: 0.75...1.25)
        let delay = min(1.0 * factor * jitter, 60.0)
        reconnectAttemptCount += 1

        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                if (UIApplication.shared.delegate as? AppDelegate)?.isActive == false {
                    return
                }

                self.reconnectionTimer?.invalidate()

                self.reconnectionTimer = Timer.scheduledTimer(
                    timeInterval: delay,
                    target: self,
                    selector: #selector(self.reconnectionTimerFired),
                    userInfo: nil,
                    repeats: false
                )
            }
        }
    }
    
    // MARK: - Watchdog Helpers

    func startWatchdog() {
        stopWatchdog()
        lastInboundTime = Date()
        let interval = Double(SphinxOnionManager.kMqttKeepAlive) * 2  // 30s
        DispatchQueue.main.async {
            self.watchdogTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                guard let self = self, self.isConnected else { return }
                guard let last = self.lastInboundTime else { return }
                if Date().timeIntervalSince(last) >= 30.0 {
                    print("[MQTT] Watchdog: silent for 30s — forcing reconnect")
                    self.stopWatchdog()
                    let dead = self.mqtt
                    self.mqtt = nil
                    dead?.didDisconnect = { _, _ in }
                    dead?.didConnectAck = { _, _ in }
                    dead?.disconnect()
                    self.isConnected = false
                    self.connectionInProgress = false
                    self.startReconnectionTimer()
                }
            }
        }
    }

    func stopWatchdog() {
        watchdogTimer?.invalidate()
        watchdogTimer = nil
    }

    @objc func reconnectionTimerFired() {
        let isActive = MainActor.assumeIsolated {
            (UIApplication.shared.delegate as? AppDelegate)?.isActive
        }
        if isActive == false {
            return
        }

        if !NetworkMonitor.shared.isConnected {
            return
        }

        reconnectToServer(
            connectingCallback: nil,
            contactRestoreCallback: self.contactRestoreCallback,
            messageRestoreCallback: self.messageRestoreCallback,
            hideRestoreViewCallback: self.hideRestoreCallback,
            errorCallback: self.errorCallback
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
            
            mqtt.didReceiveMessage = { [weak self] mqtt, receivedMessage, id in
                self?.isConnected = true
                self?.lastInboundTime = Date()
                self?.processMqttMessages(message: receivedMessage)
            }
            
            let ret3 = try sphinx.initialSetup(
                seed: seed,
                uniqueTime: getTimeWithEntropy(),
                state: loadOnionStateAsData(),
                device: getOrCreateMqttSessionId(),
                inviteCode: inviteCode
            )
            
            let _ = handleRunReturn(rr: ret3)
            
            let tribeMgmtTopic = try sphinx.getTribeManagementTopic(
                seed: seed,
                uniqueTime: getTimeWithEntropy(),
                state: loadOnionStateAsData()
            )
            
            self.mqtt.subscribe([
                (tribeMgmtTopic, CocoaMQTTQoS.qos0)
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
        } catch {}
        
        listAndUpdateContacts()
    }
    
    func listAndUpdateContacts() {
        do {
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
            mqtt.didReceiveMessage = { [weak self] mqtt, receivedMessage, id in
                self?.isConnected = true
                self?.lastInboundTime = Date()
                self?.processMqttMessages(message: receivedMessage)
            }
            
            mqtt.didDisconnect = { [weak self] _, _ in
                self?.isConnected = false
                self?.mqtt = nil
                self?.backgroundDisconnectCompletion?()
                self?.backgroundDisconnectCompletion = nil
                // Guard before any dispatch — if backgrounded, do not schedule reconnection
                let appIsActive = (UIApplication.shared.delegate as? AppDelegate)?.isActive ?? false
                guard appIsActive else { return }
                self?.stopWatchdog()
                self?.startReconnectionTimer()
            }
            
            mqtt.didReceiveTrust = { _, _, completionHandler in
                completionHandler(true)
            }
            
            //subscribe to relevant topics
            mqtt.didConnectAck = { [weak self] _, _ in
                self?.isConnected = true
                
                self?.subscribeAndPublishMyTopics(
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
    
    @MainActor func showSuccessWithMessage(_ message: String) {
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
        completion: @escaping @MainActor (Bool)->()
    ){
        let generateSeedCallback: (() -> ()) = {
            guard let mnemonic = self.generateMnemonic(), let _ = self.vc as? NewUserSignupFormViewController else {
                Task { @MainActor in
                    completion(false)
                }
                return
            }
            
            self.showMnemonicToUser(mnemonic: mnemonic, callback: {
                Task { @MainActor in
                    completion(true)
                }
            })
        }
        
        generateSeedCallback()
    }
    
    func importSeedPhrase(){
        if let vc = self.vc as? ImportSeedViewDelegate {
            Task { @MainActor in
                vc.showImportSeedView()
            }
        }
    }
    
    func showMnemonicToUser(mnemonic: String, callback: @escaping @MainActor () -> ()) {
        guard let _ = vc else {
            Task { @MainActor in
                callback()
            }
            return
        }
        
        DispatchQueue.main.async {
            AlertHelper.showAlert(
                title: "profile.store-mnemonic".localized,
                message: mnemonic,
                on: self.vc,
                confirmLabel: "Copy",
                completion: {
                    Task { @MainActor in
                        ClipboardHelper.copyToClipboard(text: mnemonic, message: "profile.mnemonic-copied".localized)
                        callback()
                    }
                }
            )
        }
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

    func getHiveLinkFrom(
        notification: [String: AnyObject]?
    ) -> String? {
        guard
            let notification = notification,
            let aps = notification["aps"] as? [String: AnyObject],
            let customData = aps["custom_data"] as? [String: AnyObject],
            let hiveLink = customData["child"] as? String
        else { return nil }
        return hiveLink
    }
    
    func getPersonalKeys() -> Keys? {
        if let mnemonic = UserData.sharedInstance.getMnemonic() {
            if let seed = try? sphinx.mnemonicToSeed(mnemonic: mnemonic) {
                if let keys = try? sphinx.nodeKeys(net: "bitcoin", seed: seed) {
                    return keys
                }
            }
        }
        return nil
    }
}

