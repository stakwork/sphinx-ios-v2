//
//  ChatListCommonObject.swift
//  sphinx
//
//  Created by Tomas Timinskas on 15/01/2020.
//  Copyright © 2020 Sphinx. All rights reserved.
//

import UIKit

public protocol ChatListCommonObject: class {
    
    func isPending() -> Bool
    func isConfirmed() -> Bool
    
    func isConversation() -> Bool
    func isPublicGroup() -> Bool
    
    func getContactStatus() -> Int?
    func getInviteStatus() -> Int?
    
    func getObjectId() -> String
    func getOrderDate() -> Date?
    func getName() -> String
    func getChatContacts() -> [UserContact]
    func getPhotoUrl() -> String?
    func getColor() -> UIColor
    func shouldShowSingleImage() -> Bool
    
    func getImage() -> UIImage?
    func setImage(image: UIImage) 
    
    func isEncrypted() -> Bool
    func subscribedToContact() -> Bool
    func isMuted() -> Bool
    func isSeen(ownerId: Int) -> Bool
    
    func getChat() -> Chat?
    func getContact() -> UserContact?
    func getInvite() -> UserInvite?
    func getUnseenMessagesCount(ownerId: Int) -> Int
    
    var lastMessage : TransactionMessage? { get set }
}
