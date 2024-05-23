//
//  Library
//
//  Created by Tomas Timinskas on 18/03/2019.
//  Copyright © 2019 Sphinx. All rights reserved.
//

import Foundation
import SwiftyJSON

final class ChatListViewModel {
    
    init() {}
    
    func authenticateWithMemesServer() {
        AttachmentsManager.sharedInstance.runAuthentication()
    }
    
    func askForNotificationPermissions() {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.registerForPushNotifications()
    }
    
    var syncMessagesTask: DispatchWorkItem? = nil
    var syncMessagesDate = Date()
    var newMessagesChatIds = [Int]()
    var syncing = false
    
    func finishRestoring() {
        SignupHelper.completeSignup()
    }
}
