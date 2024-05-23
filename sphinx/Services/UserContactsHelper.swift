//
//  UserContactService.swift
//  sphinx
//
//  Created by Tomas Timinskas on 16/06/2023.
//  Copyright © 2023 sphinx. All rights reserved.
//

import Foundation
import SwiftyJSON

class UserContactsHelper {
    
    public static func createV2Contact(
        nickname: String,
        pubKey: String,
        routeHint: String,
        photoUrl: String? = nil,
        contactKey: String? = nil,
        callback: @escaping (Bool, UserContact?) -> ()
    ){
        let contactInfo = pubKey + "_" + routeHint
        
        SphinxOnionManager.sharedInstance.makeFriendRequest(
            contactInfo: contactInfo,
            nickname: nickname
        )
        
        var maxTicks = 20
        
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            if let successfulContact = UserContact.getContactWithDisregardStatus(pubkey: pubKey) {
                callback(true, successfulContact)
                timer.invalidate()
            } else if (maxTicks >= 0) {
                maxTicks -= 1
            } else {
                callback(false, nil)
                timer.invalidate()
            }
        }
    }
}
