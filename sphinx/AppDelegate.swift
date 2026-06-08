//
//  AppDelegate.swift
//  sphinx
//
//  Created by Tomas Timinskas on 12/09/2019.
//  Copyright © 2019 Sphinx. All rights reserved.
//

import UIKit
import UserNotifications
import StoreKit
import SDWebImage
import Alamofire
import GiphyUISDK
import BackgroundTasks
import AVFAudio
import SDWebImageSVGCoder
import PushKit
import CoreData
import Bugsnag
//import BugsnagPerformance


@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?

    var style : UIUserInterfaceStyle? = nil
    var notificationUserInfo : [String: AnyObject]? = nil
    var notificationTimestamp: Date?
    var backgroundSessionCompletionHandler: (() -> Void)?
    
    let actionsManager = ActionsManager.sharedInstance
    let feedsManager = FeedsManager.sharedInstance
    let storageManager = StorageManager.sharedManager
    let podcastPlayerController = PodcastPlayerController.sharedInstance
    
    let newMessageBubbleHelper = NewMessageBubbleHelper()
    let chatListViewModel = ChatListViewModel()
    
    let som = SphinxOnionManager.sharedInstance
    
    var isActive = false
    private var pendingFetchWorkItem: DispatchWorkItem?
    private var pendingFetchCompletion: ((UIBackgroundFetchResult) -> Void)?
    
    public enum BuildType: Int {
        case Sideload
        case Testflight
        case AppStore
    }

    static var orientationLock = UIInterfaceOrientationMask.portrait

    //Lifecycle events
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        if AppDelegate.orientationLock != .portrait {
            return AppDelegate.orientationLock
        }
        
        if UIDevice.current.isIpad {
            return .allButUpsideDown
        }

        if WindowsManager.sharedInstance.shouldRotateOrientation() {
            return .allButUpsideDown
        }

        return .portrait
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        
        AppLogger.shared.start()
        
        isActive = true
        
        if #available(iOS 15.0, *) {
            UITableView.appearance().sectionHeaderTopPadding = CGFloat(0)
        }
        
        //        registerAppRefresh()
        //        configureStoreKit()
        //        registerForVoIP()
        
        setAppConfiguration()
        configureGiphy()
        configureBugsnag()
        configureNotificationCenter()
        configureSVGRendering()
        configureSDWebImage()
        connectMQTT()
        
        StorageManager.sharedManager.deleteOldMedia()
        ColorsManager.sharedInstance.storeColorsInMemory()
        SphinxOnionManager.sharedInstance.storeOnionStateInMemory()
        
//        deleteLogs()
        
        setInitialVC()
        
        return true
    }
    
    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey : Any] = [:]
    ) -> Bool {
        handleUrl(url)
        return true
    }
    
    func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
                let url = userActivity.webpageURL,
                let _ = URLComponents(url: url, resolvingAgainstBaseURL: true) else
        {
            return false
        }
        
        handleUrl(url)
         
        return true
    }
    
    func handleUrl(_ url: URL) {
        if DeepLinksHandlerHelper.storeLinkQueryFrom(url: url) {
            if let currentVC = getCurrentVC() {
                if let currentVC = currentVC as? InitialWelcomeViewController {
                    currentVC.handleLinkQueries()
                } else if let currentVC = currentVC as? DashboardRootViewController {
                    if let presentedVC = currentVC.navigationController?.presentedViewController {
                        presentedVC.dismiss(animated: true) {
                            currentVC.handleLinkQueries()
                        }
                    } else {
                        currentVC.handleLinkQueries()
                    }
                } else {
                    ///handleLinkQueries will be called in viewDidLoad
                    currentVC.navigationController?.popToRootViewController(animated: true)
                }
            } else {
                setInitialVC()
            }
        }
    }

    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        backgroundSessionCompletionHandler = completionHandler
    }

    func applicationDidEnterBackground(
        _ application: UIApplication
    ) {
        AppLogger.shared.flush()
        
        isActive = false
        notificationUserInfo = nil
        saveCurrentStyle()
        setBadge(application: application)

        NetworkMonitor.shared.stopMonitoring()
        getDashboardVC()?.suspendNetworkObservers()
        HivePusherManager.shared.pauseForBackground()
        NotificationCenter.default.post(name: .appDidEnterBackground, object: nil)

        // Perform synchronous cleanup before starting the background task.
        podcastPlayerController.finishAndSaveContentConsumed()
        CoreDataManager.sharedManager.saveContext()
        SDImageCache.shared.clearMemory()
        SDWebImageManager.shared.cancelAll()
        presentBiometricIfNeeded()

        // Hold a background task open until the MQTT socket is fully closed.
        // disconnectMqtt() is async — ending the task before the socket closes
        // leaves an open network connection at suspension, which causes iOS to
        // kill the process silently (no crash report, no push needed).
        var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
        let endTask = {
            if backgroundTaskID != .invalid {
                application.endBackgroundTask(backgroundTaskID)
                backgroundTaskID = .invalid
            }
        }
        backgroundTaskID = application.beginBackgroundTask(withName: "MQTTDisconnect") {
            endTask()
        }

        som.endReconnectionTimer()
        som.disconnectMqtt(callback: { _ in
            endTask()
        })
    }
    
    func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
        SDImageCache.shared.clearMemory()
        SDWebImageManager.shared.cancelAll()
    }

    func applicationWillEnterForeground(
        _ application: UIApplication
    ) {
        print("[Lifecycle] applicationWillEnterForeground")
        
        isActive = true
        pendingFetchWorkItem?.cancel()
        pendingFetchWorkItem = nil
        pendingFetchCompletion?(.noData)
        pendingFetchCompletion = nil
        getDashboardVC()?.resumeNetworkObservers()
        HivePusherManager.shared.resumeFromBackground()
        NotificationCenter.default.post(name: .appWillEnterForeground, object: nil)

        // Remove any LiveKit PiP view that became orphaned while the app was in the background
        // (e.g. call ended via network error while suspended, teardown animation never completed).
        VideoCallManager.sharedInstance.cleanUpIfStale()

        // Auth gates must run regardless of session-PIN state — if the process was
        // killed, appSessionPin is nil and isUserLogged() would return false, but
        // we still need to show the PIN / biometric screen.
        guard UserData.sharedInstance.isSignupCompleted() else {
            return
        }

        presentPINIfNeeded()
        tryBiometricAuth()

        // Always tear down any in-flight background connection before reconnecting.
        // This must run even when the user is not yet logged in (PIN timeout case)
        // so that onLoggingCompletion's reconnect starts from a clean slate.

        // Sync and other foreground work require a valid session (mnemonic accessible).
        guard UserData.sharedInstance.isUserLogged() else {
            // PIN was not available in keychain — user must enter it manually.
            // onLoggingCompletion will call reconnectToServer once the PIN is saved.
            return
        }

        Chat.processTimezoneChanges()
        feedsManager.restoreContentFeedStatusInBackground()
        podcastPlayerController.finishAndSaveContentConsumed()

        // Call reconnect directly on the SOM — don't route through the VC, which may
        // not be in the hierarchy when willEnterForeground fires (e.g. PIN screen showing).
        // For biometric users: PIN is already in keychain so we start the reconnect here
        // in parallel while Face ID is displayed, gaining time before auth completes.
        som.prepareForForeground() {
            self.getDashboardVC()?.connectToServer()
        }

        DataSyncManager.sharedInstance.syncWithServerInBackground()

        // Run garbage cleanup in foreground where we have plenty of time
        // instead of in background where iOS kills apps that take too long
        storageManager.processGarbageCleanup()
    }
    
    func applicationDidBecomeActive(
        _ application: UIApplication
    ) {
        isActive = true
        reloadAppIfStyleChanged()
        
        if !UserData.sharedInstance.isUserLogged() {
            return
        }
        
        handlePushAndFetchData()
    }

    func handlePushAndFetchData() {
        guard let notificationUserInfo else { return }

        if let hiveLink = SphinxOnionManager.sharedInstance.getHiveLinkFrom(notification: notificationUserInfo),
           let navigatableURL = buildHiveURL(from: hiveLink),
           let currentVC = getCurrentVC() {
            print("[PushNav] navigating to hive link on first attempt")
            HiveLinkNavigator.navigate(hiveLink: navigatableURL, from: currentVC)
            self.notificationUserInfo = nil
            return
        }

        if let chat = SphinxOnionManager.sharedInstance.mapNotificationToChat(notificationUserInfo: notificationUserInfo)?.0 {
            print("[PushNav] navigating to chat on first attempt")
            goTo(chat: chat)
            self.notificationUserInfo = nil
        } else {
            print("[PushNav] chat not resolved yet — holding intent for retry")
        }
    }

    /// Converts "my-workspace/feature:abc123" → "https://hive.sphinx.chat/w/my-workspace/plan/abc123"
    /// Converts "my-workspace/task:xyz789"   → "https://hive.sphinx.chat/w/my-workspace/task/xyz789"
    private func buildHiveURL(from hiveLink: String) -> String? {
        let parts = hiveLink.split(separator: "/", maxSplits: 1)
        guard parts.count == 2 else { return nil }
        let slug = String(parts[0])
        let entityPart = String(parts[1])

        if entityPart.hasPrefix("feature:") {
            let id = entityPart.replacingOccurrences(of: "feature:", with: "")
            return "https://hive.sphinx.chat/w/\(slug)/plan/\(id)"
        } else if entityPart.hasPrefix("task:") {
            let id = entityPart.replacingOccurrences(of: "task:", with: "")
            return "https://hive.sphinx.chat/w/\(slug)/task/\(id)"
        }
        return nil
    }
    
    func applicationWillTerminate(
        _ application: UIApplication
    ) {
        AppLogger.shared.flush()
        
        setBadge(application: application)

//        SKPaymentQueue.default().remove(StoreKitService.shared)

        podcastPlayerController.finishAndSaveContentConsumed()
        CoreDataManager.sharedManager.saveContext()
        
        NetworkMonitor.shared.stopMonitoring()
        som.disconnectMqtt()
    }
    
    /// Call once to wipe all persisted logs and start fresh. Remove the call after use.
    func deleteLogs() {
        AppLogger.shared.clear()
        print("[AppLogger] Logs cleared")
    }

    ///On app launch
    func setAppConfiguration() {
        Constants.setSize()
        window?.setStyle()
        saveCurrentStyle()
    }
    
//    func registerAppRefresh() {
//        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.gl.sphinx.refresh", using: nil, launchHandler: { task in
//            self.handleAppRefresh(task: task)
//        })
//    }
    
    func configureSDWebImage() {
        SDImageCache.shared.config.maxMemoryCost = 75 * 1024 * 1024 // 75 MB
    }
    
    func configureSVGRendering(){
        let SVGCoder = SDImageSVGCoder.shared
        SDImageCodersManager.shared.addCoder(SVGCoder)
        
    }
    
    func configureGiphy() {
        Giphy.configure(apiKey: Config.giphyApiKey)
    }
    
    func configureBugsnag() {
        Bugsnag.start()
//        BugsnagPerformance.start()
        
        if let ownerName = UserContact.getOwner()?.nickname {
            Bugsnag.setUser(nil, withEmail: nil, andName: ownerName)
        }
    }
    
    func configureNotificationCenter() {
        notificationUserInfo = nil
        UNUserNotificationCenter.current().delegate = self
    }
    
    func configureStoreKit() {
        SKPaymentQueue.default().add(StoreKitService.shared)
    }
    
    fileprivate func registerForVoIP(){
        let registry = PKPushRegistry(queue: .main)
        DispatchQueue.main.async {
            registry.delegate = UIApplication.shared.delegate as! AppDelegate
        }
        registry.desiredPushTypes = [PKPushType.voIP]
    }
    
    func connectMQTT() {
//        if let phoneSignerSetup: Bool = UserDefaults.Keys.setupPhoneSigner.get(), phoneSignerSetup,
//           let network : String = UserDefaults.Keys.phoneSignerNetwork.get(),
//           let host : String = UserDefaults.Keys.phoneSignerHost.get(),
//           let relay : String = UserDefaults.Keys.phoneSignerRelay.get(){
//            let _ = CrypterManager.sharedInstance.performWalletFinalization(network: network, host: host, relay: relay)
//        }
    }
    
    //Initial VC
    func setInitialVC() {
        let isUserLogged = UserData.sharedInstance.isUserLogged()
        
        if isUserLogged {
            syncDeviceId()
            feedsManager.restoreContentFeedStatusInBackground()
            Task { @MainActor in
                AIAgentManager.sharedInstance.createAgentContactAndChatIfNeeded()
            }
        }

        takeUserToInitialVC(isUserLogged: UserData.sharedInstance.isSignupCompleted())
        presentPINIfNeeded()
    }
    
    func updateDefaultTribe() {
        if !SphinxOnionManager.sharedInstance.isProductionEnv {
            return
        }
        
        if !UserData.sharedInstance.isUserLogged() {
            return
        }
        
        API.sharedInstance.updateDefaultTribe()
    }

    func presentPINIfNeeded() {
        let biometricEnabled = UserDefaults.Keys.biometricAuthEnabled.get(defaultValue: false)
        let neverRequirePin = GroupsPinManager.sharedInstance.isPINNeverRequired()
        let pinTimeoutElapsed = GroupsPinManager.sharedInstance.hasPINTimeoutElapsed()

        guard UserData.sharedInstance.isSignupCompleted() else { return }

        // PIN timeout elapsed → always show PIN, regardless of Face ID
        if pinTimeoutElapsed {
            let pinVC = PinCodeViewController.instantiate()
            pinVC.loggingCompletion = { self.onLoggingCompletion() }
            WindowsManager.sharedInstance.showConveringWindowWith(rootVC: pinVC, passthroughWindow: false)
            return
        }
        
        let autoLoginPinSet = UserData.sharedInstance.getAutoLoginPin() != nil

        // Face ID enabled → show biometric on every app entry (covers both neverRequire and specific-timeout cases)
        if biometricEnabled && autoLoginPinSet {
            guard WindowsManager.sharedInstance.getCurrentCoveringWindowVC() is BiometricLockViewController else {
                let biometricLockVC = BiometricLockViewController()
                biometricLockVC.loggingCompletion = { self.onLoggingCompletion() }
                WindowsManager.sharedInstance.showConveringWindowWith(rootVC: biometricLockVC, passthroughWindow: false)
                return
            }
            return
        }

        // No Face ID + no timeout elapsed (or never require) → no auth needed

        // One-time migration: "Never require PIN" users who updated before autoLoginPin
        // was persisted to keychain have no keychain entry yet. Without it, getMnemonic()
        // silently fails on the next cold launch (appSessionPin is nil and keychain is empty).
        // Force a single PIN prompt to seed keychain; subsequent launches restore silently.
        if UserData.sharedInstance.getAutoLoginPin() == nil {
            let pinVC = PinCodeViewController.instantiate()
            pinVC.loggingCompletion = { self.onLoggingCompletion() }
            WindowsManager.sharedInstance.showConveringWindowWith(rootVC: pinVC, passthroughWindow: false)
        }
    }

    func presentBiometricIfNeeded() {
        if let _ = WindowsManager.sharedInstance.getCurrentCoveringWindowVC() as? BiometricLockViewController {
            return
        }

        guard UserData.sharedInstance.isUserLogged() else { return }
        guard UserDefaults.Keys.biometricAuthEnabled.get(defaultValue: false) else { return }
        guard !GroupsPinManager.sharedInstance.hasPINTimeoutElapsed() else { return } // PIN takes over when timeout has elapsed
        guard BiometricAuthenticationHelper().canUseBiometricAuthentication() else { return }

        let biometricLockVC = BiometricLockViewController()
        biometricLockVC.loggingCompletion = {
            self.onLoggingCompletion()
        }
        WindowsManager.sharedInstance.showConveringWindowWith(
            rootVC: biometricLockVC,
            passthroughWindow: false
        )
    }
    
    func tryBiometricAuth() {
        if let biometricLockVC = WindowsManager.sharedInstance.getCurrentCoveringWindowVC() as? BiometricLockViewController {
            biometricLockVC.triggerBiometric()
            return
        }
    }
    
    private func onLoggingCompletion() {
        self.updateDefaultTribe()

        if let currentVC = self.getCurrentVC() {
            let _ = DeepLinksHandlerHelper.joinJitsiCall(vc: currentVC, forceJoin: true)

            if let currentVC = currentVC as? DashboardRootViewController {
                // Only reconnect if willEnterForeground didn't already start a connection.
                // When PIN is in keychain (biometric / never-require users), willEnterForeground
                // calls reconnectToServer and mqtt is already in flight; skip here to avoid a
                // redundant sync. When PIN was required from the user (timeout case), mqtt is
                // nil because willEnterForeground returned early — connect now.
                if som.mqtt == nil {
                    currentVC.connectToServer()
                }
            }
        }
    }

    func takeUserToInitialVC(
        isUserLogged: Bool
    ) {
        let rootViewController = StoryboardScene.Root.initialScene.instantiate()
        let mainCoordinator = MainCoordinator(rootViewController: rootViewController)
        
        if let window = window {
            window.rootViewController = rootViewController
            window.makeKeyAndVisible()
        }

        if isUserLogged {
            mainCoordinator.presentInitialDrawer()
        } else {
            window?.setDarkStyle()
            mainCoordinator.presentSignUpScreen()
        }
    }
    
    //Notifications
    func syncDeviceId() {
        UserContact.syncDeviceId()
        syncHiveDeviceToken()
    }

    func syncHiveDeviceToken() {
        guard UserDefaults.Keys.hiveNotificationsEnabled.get(defaultValue: true) else { return }
        guard let apnsToken: String = UserDefaults.Keys.deviceId.get(), !apnsToken.isEmpty else { return }
        let lastSynced: String? = UserDefaults.Keys.hiveDeviceToken.get()
        guard lastSynced != apnsToken else { return }

        API.sharedInstance.registerDeviceTokenWithAuth(
            token: apnsToken,
            callback: {
                UserDefaults.Keys.hiveDeviceToken.set(apnsToken)
            },
            errorCallback: {
                print("[HIVE] Failed to register device token")
            }
        )
    }
    
    func handleIncomingCall(
        callerName:String
    ){
        if #available(iOS 14.0, *) {
            JitsiIncomingCallManager.sharedInstance.reportIncomingCall(
                uuid: UUID(),
                handle: callerName
            )
        }
    }
    
    func handleAcceptedCall(
        callLink: String,
        audioOnly: Bool
    ){
        VideoCallManager.sharedInstance.startVideoCall(link: callLink, audioOnly: audioOnly)
    }
    
//    func handleAppRefresh(task: BGTask) {
//        scheduleAppRefresh()
//        
//        task.expirationHandler = {
//            task.setTaskCompleted(success: false)
//        }
//        
//        if isActive || !UserData.sharedInstance.isUserLogged() {
//            task.setTaskCompleted(success: false)
//            return
//        }
//        
//        var didEndFetch = false
//        
//        DispatchQueue.main.asyncAfter(deadline: .now() + 20) {
//            guard !didEndFetch else {
//                return
//            }
//            didEndFetch = true
//            task.setTaskCompleted(success: false)
//        }
//        
//        som.reconnectToServer(hideRestoreViewCallback: {
//            guard !didEndFetch else {
//                return
//            }
//            didEndFetch = true
//            task.setTaskCompleted(success: true)
//        }, errorCallback: {
//            guard !didEndFetch else {
//                return
//            }
//            didEndFetch = true
//            task.setTaskCompleted(success: false)
//        })
//    }
//    
//    func scheduleAppRefresh() {
//        let request = BGAppRefreshTaskRequest(identifier: "com.gl.sphinx.refresh")
//        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
//        do {
//            try BGTaskScheduler.shared.submit(request)
//        } catch {
//            print("Could not schedule app refresh \(error)")
//        }
//    }

    //App stylre
    func saveCurrentStyle() {
        if #available(iOS 13.0, *) {
            style = UITraitCollection.current.userInterfaceStyle
        }
    }

    func reloadAppIfStyleChanged() {
        if #available(iOS 13.0, *) {
            guard let _ = UIWindow.getSavedStyle() else {
                if style != UIScreen.main.traitCollection.userInterfaceStyle {
                    style = UIScreen.main.traitCollection.userInterfaceStyle

                    takeUserToInitialVC(isUserLogged: UserData.sharedInstance.isSignupCompleted())
                }
                return
            }
        }
    }
    
    //Utils
    func getRootViewController() -> RootViewController? {
        if let window = window, let rootVC = window.rootViewController as? RootViewController {
            return rootVC
        }
        return nil
    }

    func getCurrentVC() -> UIViewController? {
        let rootVC = window?.rootViewController

        if let rootVController = rootVC as? RootViewController {
            if let currentVC = rootVController.getLastCenterViewController() {
                return currentVC
            }
            if let currentVC = rootVController.currentViewController as? UINavigationController {
                return currentVC.viewControllers.last
            }
        }
        return nil
    }
    
    func getDashboardVC() -> DashboardRootViewController? {
        let rootVC = window?.rootViewController

        if let rootVController = rootVC as? RootViewController, let currentVC = rootVController.getDashboardViewController() {
            return currentVC
        }
        return nil
    }

    //App connection error
    func goToSupport() {
        if let roowVController = window?.rootViewController as? RootViewController, let leftMenuVC = roowVController.getLeftMenuVC() {
            leftMenuVC.goToSupport()
        }
    }

    //Notifications bagde
    func setBadge(
        application: UIApplication
    ) {
        application.applicationIconBadgeNumber = TransactionMessage.getReceivedUnseenMessagesCount()
    }
}

extension AppDelegate: @preconcurrency UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable : Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        if isActive || !UserData.sharedInstance.isUserLogged() {
            completionHandler(.noData)
            return
        }
        
        // Skip reconnect if PIN is required but not available in memory
        // (process was silently relaunched in background after being killed)
        if UserData.sharedInstance.isPinSet() &&
           UserData.sharedInstance.getAppPin() == nil {
            completionHandler(.noData)
            return
        }
        
        // Cancel any pending debounced fetch, immediately satisfying its completion
        // handler so iOS doesn't warn about a handler that was never called.
        pendingFetchWorkItem?.cancel()
        pendingFetchWorkItem = nil
        pendingFetchCompletion?(.noData)
        pendingFetchCompletion = nil
        print("[BGFetch] Notification received — debouncing 1.5s")

        pendingFetchCompletion = completionHandler
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            print("[BGFetch] Debounce elapsed — starting fetch")
            self.pendingFetchCompletion = nil
            self.som.beginBackgroundFetch(completionHandler: completionHandler)
        }
        pendingFetchWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: workItem)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if UIApplication.shared.applicationState == .inactive, response.actionIdentifier == UNNotificationDefaultActionIdentifier {
            notificationUserInfo = response.notification.request.content.userInfo as? [String: AnyObject]
            notificationTimestamp = Date()
        }
        completionHandler()
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        
        UserContact.updateDeviceId(deviceId: token)
        syncHiveDeviceToken()
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("Failed to register: \(error)")
    }

    func registerForPushNotifications() {
        let notificationsCenter = UNUserNotificationCenter.current()
        notificationsCenter.getNotificationSettings { settings in
            notificationsCenter.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }
    
    func goTo(chat: Chat) {
        if let rootVC = getRootViewController() {
            if let centerVC = rootVC.getLastCenterViewController() {
                
                if let centerVC = centerVC as? NewChatViewController, centerVC.chat?.id == chat.id {
                    return
                }
                
                centerVC.view.endEditing(true)
                
                let chatVC = NewChatViewController.instantiate(
                    contactId: chat.conversationContact?.id,
                    chatId: chat.id,
                    chatListViewModel: chatListViewModel
                )
                
                let navCenterController: UINavigationController? = centerVC.navigationController
                
                if let presentedVC = navCenterController?.presentedViewController {
                    presentedVC.dismiss(animated: true) {
                        navCenterController?.pushOverRootVC(vc: chatVC)
                    }
                } else {
                    navCenterController?.pushOverRootVC(vc: chatVC)
                }
            }
        }
    }
}

extension AppDelegate : @preconcurrency PKPushRegistryDelegate {
    func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
        if type == PKPushType.voIP {
            let tokenData = pushCredentials.token
            let deviceToken: String = tokenData.reduce("", {$0 + String(format: "%02X", $1) })
            UserContact.updateVoipDeviceId(deviceId: deviceToken)
        }
    }
    
    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
//        if let dict = payload.dictionaryPayload as? [String:Any],
//           let aps = dict["aps"] as? [String:Any],
//           let contents = aps["alert"] as? String,
//           let pushMessage = VoIPPushMessage.voipMessage(jsonString: contents),
//           let pushBody = pushMessage.body as? VoIPPushMessageBody {
//            
//            if #available(iOS 14.0, *) {
//                //                let (result, link) = EncryptionManager.sharedInstance.decryptMessage(message: pushBody.linkURL)
//                //                pushBody.linkURL = link
//                //                
//                //                let manager = JitsiIncomingCallManager.sharedInstance
//                //                manager.currentJitsiURL = (result == true) ? link : pushBody.linkURL
//                //                manager.hasVideo = pushBody.isVideoCall()
//                //                
//                //                self.handleIncomingCall(callerName: pushBody.callerName)
//            }
//            completion()
//        } else {
//            completion()
//        }
        
        completion()
    }
    
    func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
        print("invalidated token")
    }
}

