//
//  InviteActionsHelper.swift
//  sphinx
//
//  Created by Tomas Timinskas on 11/11/2020.
//  Copyright © 2020 Sphinx. All rights reserved.
//

import Foundation
import SwiftyJSON

class InviteActionsHelper {
    
    func handleInviteActions(completion: @escaping () -> ()) {
        //TODO: @Jim need to rethink for v2!
//        if let inviteAction: String = UserDefaults.Keys.inviteAction.get(), !inviteAction.isEmpty {
//            if inviteAction.starts(with: "create_podcast") {
//                let podcastId = inviteAction.podcastId
//                if podcastId > 0 {
//                    getPodcastInfo(podcastId: podcastId, completion: completion)
//                    return
//                }
//            } else if inviteAction.starts(with: "join_tribe") {
//                let (uuid, host) = inviteAction.tribeUUIDAndHost
//                if let uuid = uuid, !uuid.isEmpty {
//                    getTribeInfo(uuid: uuid, host: host ?? "tribes.sphinx.chat", completion: completion)
//                    return
//                }
//            }
//        }
        completion()
    }
    
    func getPodcastInfo(podcastId: Int, completion: @escaping () -> ()) {
        API.sharedInstance.getPodcastInfo(podcastId: podcastId, callback: { podcastJSON in
            self.createTribe(podcastJson: podcastJSON, completion: completion)
        }, errorCallback: {
            completion()
        })
    }
    
    func createTribe(podcastJson: JSON, completion: @escaping () -> ()) {
        var parameters = [String : AnyObject]()
        
        parameters["name"] = podcastJson["title"].stringValue as AnyObject
        parameters["img"] = podcastJson["image"].stringValue as AnyObject
        parameters["description"] = podcastJson["description"].stringValue as AnyObject
        parameters["feed_url"] = podcastJson["url"].stringValue as AnyObject
        parameters["is_tribe"] = true as AnyObject
        parameters["unlisted"] = false as AnyObject
        parameters["private"] = false as AnyObject
        parameters["tags"] = ["Podcast"] as AnyObject
        
        guard let _ = parameters["name"] as? String,
            let _ = parameters["description"] as? String else{
            //Send Alert?
            //self.showErrorAlert()
            return
        }
        
        SphinxOnionManager.sharedInstance.createTribe(params: parameters, callback: handleNewTribeNotification,errorCallback: { error in
            AlertHelper.showAlert(title: error?.localizedDescription ?? "", message: "")
        })
    }
    
    func handleNewTribeNotification(tribeJSONString: String) {
        if let tribeJSON = try? tribeJSONString.toDictionary(),
           let chatJSON = SphinxOnionManager.sharedInstance.mapChatJSON(rawTribeJSON: tribeJSON),
           let chat = Chat.insertChat(chat: chatJSON)
        {
            chat.managedObjectContext?.saveContext()
            return
        }
    }
    
    func getTribeInfo(uuid: String, host: String, completion: @escaping () -> ()) {
        let grouspManager = GroupsManager.sharedInstance
        let planetTribeQuery = "sphinx.chat://?action=tribe&uuid=\(uuid)&host=\(host)"
        var tribeInfo = grouspManager.getGroupInfo(query: planetTribeQuery)
        
        if tribeInfo != nil {
            API.sharedInstance.getTribeInfo(host: tribeInfo?.host ?? "", uuid: tribeInfo?.uuid ?? "", callback: { groupInfo in
                grouspManager.update(tribeInfo: &tribeInfo!, from: groupInfo)
                self.joinTribe(tribeInfo: tribeInfo!, completion: completion)
            }, errorCallback: {
                completion()
            })
        } else {
            completion()
        }
    }
    
    func joinTribe(
        tribeInfo: GroupsManager.TribeInfo,
        completion: @escaping () -> ()
    ) {
        if let pubkey = tribeInfo.ownerPubkey,
           let chatJSON = GroupsManager.getChatJSON(tribeInfo: tribeInfo),
           let routeHint = tribeInfo.ownerRouteHint,
           let chat = Chat.insertChat(chat: chatJSON)
        {
            let isPrivate = tribeInfo.privateTribe
            
            SphinxOnionManager.sharedInstance.joinTribe(
                tribePubkey: pubkey,
                routeHint: routeHint,
                alias: UserContact.getOwner()?.nickname,
                isPrivate: isPrivate, 
                errorCallback: { error in
                    AlertHelper.showAlert(title: error.localizedDescription ?? "", message: "")
                }
            )
            
            chat.status = (isPrivate) ? Chat.ChatStatus.pending.rawValue : Chat.ChatStatus.approved.rawValue
            chat.type = Chat.ChatType.publicGroup.rawValue
            chat.managedObjectContext?.saveContext()
        }
    }
}
