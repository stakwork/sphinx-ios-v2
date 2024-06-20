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

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?

    var style : UIUserInterfaceStyle? = nil
    var notificationUserInfo : [String: AnyObject]? = nil
    var backgroundSessionCompletionHandler: (() -> Void)?
    
    let onionConnector = SphinxOnionConnector.sharedInstance
    let actionsManager = ActionsManager.sharedInstance
    let feedsManager = FeedsManager.sharedInstance
    let storageManager = StorageManager.sharedManager
    let podcastPlayerController = PodcastPlayerController.sharedInstance
    
    let newMessageBubbleHelper = NewMessageBubbleHelper()
    let chatListViewModel = ChatListViewModel()
    
    let som = SphinxOnionManager.sharedInstance
    
    var isActive = false

    //Lifecycle events
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        
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
        
        isActive = true
        
        if #available(iOS 15.0, *) {
            UITableView.appearance().sectionHeaderTopPadding = CGFloat(0)
        }
        
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        
        setAppConfiguration()
        registerAppRefresh()
        configureGiphy()
        configureNotificationCenter()
        configureStoreKit()
        configureSVGRendering()
        connectMQTT()
        registerForVoIP()
        
        setInitialVC()
        
        NetworkMonitor.shared.startMonitoring()

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
        restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
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
                if let currentVC = currentVC as? DashboardRootViewController {
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
        isActive = false
        saveCurrentStyle()
        setBadge(application: application)
        
        podcastPlayerController.finishAndSaveContentConsumed()
        
        actionsManager.syncActionsInBackground()
        feedsManager.saveContentFeedStatus()
        storageManager.processGarbageCleanup()
        
        CoreDataManager.sharedManager.saveContext()
        
        scheduleAppRefresh()
    }

    func applicationWillEnterForeground(
        _ application: UIApplication
    ) {
        isActive = true
        notificationUserInfo = nil

        if !UserData.sharedInstance.isUserLogged() {
            return
        }
        
        presentPINIfNeeded()
        
        feedsManager.restoreContentFeedStatusInBackground()
        podcastPlayerController.finishAndSaveContentConsumed()
        
        som.reconnectToServer()
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
        guard let notificationUserInfo = notificationUserInfo else {
            return
        }
        if let encryptedChild = getEncryptedIndexFrom(notification: notificationUserInfo),
           let chat = SphinxOnionManager.sharedInstance.findChatForNotification(child: encryptedChild){
            goTo(chat: chat)
        }
    }
    
    func applicationWillTerminate(
        _ application: UIApplication
    ) {
        setBadge(application: application)

        SKPaymentQueue.default().remove(StoreKitService.shared)

        podcastPlayerController.finishAndSaveContentConsumed()
        CoreDataManager.sharedManager.saveContext()
    }
    
    ///On app launch
    func setAppConfiguration() {
        Constants.setSize()
        window?.setStyle()
        saveCurrentStyle()
    }
    
    func registerAppRefresh() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.gl.sphinx.refresh", using: nil, launchHandler: { task in
            self.handleAppRefresh(task: task)
        })
    }
    
    func configureSVGRendering(){
        let SVGCoder = SDImageSVGCoder.shared
        SDImageCodersManager.shared.addCoder(SVGCoder)
        
    }
    
    func configureGiphy() {
        if let GIPHY_API_KEY = Bundle.main.object(forInfoDictionaryKey: "GIPHY_API_KEY") as? String {
            Giphy.configure(apiKey: GIPHY_API_KEY)
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
        if let phoneSignerSetup: Bool = UserDefaults.Keys.setupPhoneSigner.get(),
            phoneSignerSetup,
           let network : String = UserDefaults.Keys.phoneSignerNetwork.get(),
           let host : String = UserDefaults.Keys.phoneSignerHost.get(),
           let relay : String = UserDefaults.Keys.phoneSignerRelay.get(){
            let _ = CrypterManager.sharedInstance.performWalletFinalization(network: network, host: host, relay: relay)
        }
    }
    
    //Initial VC
    func setInitialVC() {
        let isUserLogged = UserData.sharedInstance.isUserLogged()
        
        if isUserLogged {
            syncDeviceId()
            feedsManager.restoreContentFeedStatusInBackground()
        }

        takeUserToInitialVC(isUserLogged: SignupHelper.isLogged())
        presentPINIfNeeded()
    }

    func presentPINIfNeeded() {
        if GroupsPinManager.sharedInstance.shouldAskForPin() {
            let pinVC = PinCodeViewController.instantiate()
            pinVC.loggingCompletion = {
                if let currentVC = self.getCurrentVC() {
                    let _ = DeepLinksHandlerHelper.joinJitsiCall(vc: currentVC, forceJoin: true)
                    
                    if let currentVC = currentVC as? DashboardRootViewController {
                        currentVC.connectToServer()
                    }
                }
            }
            WindowsManager.sharedInstance.showConveringWindowWith(rootVC: pinVC)
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
        callLink:String,
        audioOnly: Bool
    ){
        VideoCallManager.sharedInstance.startVideoCall(link: callLink, audioOnly: audioOnly)
    }
    
    //Background App refresh
    func handleAppRefresh(task: BGTask) {
        scheduleAppRefresh()
        
        som.reconnectToServer()
    }
    
    func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "com.gl.sphinx.refresh")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Could not schedule app refresh \(error)")
        }
    }

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

                    takeUserToInitialVC(isUserLogged: SignupHelper.isLogged())
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

        if let rootVController = rootVC as? RootViewController, let currentVC = rootVController.getLastCenterViewController() {
            return currentVC
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

extension AppDelegate: UNUserNotificationCenterDelegate {
    
//    private func modifyNotificationText(with chatName: String?, completion: @escaping () -> Void) {
//        guard let name = chatName else { return }
//        let newText = "New message from \(name)"
//
//        // Example of showing a modified local notification
//        let content = UNMutableNotificationContent()
//        content.title = "Sphinx Chat"
//        content.body = newText
//        content.sound = .default
//
//        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
//        UNUserNotificationCenter.current().add(request) { error in
//            if let error = error {
//                print("Error showing local notification: \(error)")
//            }
//            completion()
//        }
//    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable : Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        som.reconnectToServer(hideRestoreViewCallback: {
            completionHandler(.newData)
        })
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if UIApplication.shared.applicationState == .inactive, response.actionIdentifier == UNNotificationDefaultActionIdentifier {
            notificationUserInfo = response.notification.request.content.userInfo as? [String: AnyObject]
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
    
    func getChatIdFrom(
        notification: [String: AnyObject]?
    ) -> Int? {
        if
            let notification = notification,
            let aps = notification["aps"] as? [String: AnyObject],
            let customData = aps["custom_data"] as? [String: AnyObject]
        {
            if let chatId = customData["chat_id"] as? Int {
                return chatId
            }
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

extension AppDelegate : PKPushRegistryDelegate{
    func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
        if type == PKPushType.voIP {
            let tokenData = pushCredentials.token
            let deviceToken: String = tokenData.reduce("", {$0 + String(format: "%02X", $1) })
            UserContact.updateVoipDeviceId(deviceId: deviceToken)
        }
    }
    
    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
        if let dict = payload.dictionaryPayload as? [String:Any],
           let aps = dict["aps"] as? [String:Any],
           let contents = aps["alert"] as? String,
           let pushMessage = VoIPPushMessage.voipMessage(jsonString: contents),
           let pushBody = pushMessage.body as? VoIPPushMessageBody {
           
            if #available(iOS 14.0, *) {
//                let (result, link) = EncryptionManager.sharedInstance.decryptMessage(message: pushBody.linkURL)
//                pushBody.linkURL = link
//                
//                let manager = JitsiIncomingCallManager.sharedInstance
//                manager.currentJitsiURL = (result == true) ? link : pushBody.linkURL
//                manager.hasVideo = pushBody.isVideoCall()
//                
//                self.handleIncomingCall(callerName: pushBody.callerName)
            }
            completion()
        } else {
            completion()
        }
    }
    
    func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
        print("invalidated token")
    }
}



