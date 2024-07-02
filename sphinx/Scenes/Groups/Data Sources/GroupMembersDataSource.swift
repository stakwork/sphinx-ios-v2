//
//  GroupMembersDataSource.swift
//  sphinx
//
//  Created by Tomas Timinskas on 17/01/2020.
//  Copyright © 2020 Sphinx. All rights reserved.
//

import UIKit
import SwiftyJSON

class GroupMembersDataSource: GroupAllContactsDataSource {
    
    var chat: Chat!
    
    weak var addMemberDelegate: AddFriendRowButtonDelegate?
    weak var groupDetailsDelegate: GroupDetailsDelegate?
    
    var messageBubbleHelper = NewMessageBubbleHelper()
    
    public static let kItemsPerPage: Int = 25
    
    let kAddMemberCellHeight: CGFloat = 100.0
    
    let som = SphinxOnionManager.sharedInstance
    
    init(tableView: UITableView, title: String) {
        super.init(tableView: tableView, delegate: nil, title: title)
        self.tableView = tableView
    }
    
    func reloadContacts(chat: Chat) {
        self.chat = chat
        
        loadTribeContacts()
    }
    
    func loadTribeContacts() {
        
        som.getTribeMembers(tribeChat: self.chat, completion: { [weak self] tribeMembers in
            guard let weakSelf = self else { return }
            
            if let tribeMemberArray = tribeMembers["confirmedMembers"] as? [TribeMembersRRObject],
               let pendingMembersArray = tribeMembers["pendingMembers"] as? [TribeMembersRRObject]
            {
                self?.chat.isTribeICreated = true
                self?.chat.managedObjectContext?.saveContext()
                
                let contactsMap = tribeMemberArray.map({
                    var contact = JSON($0.toJSON())
                    contact["pending"] = false
                    return contact
                }).sorted { $0["alias"].stringValue < $1["alias"].stringValue }
                
                let pendingContactsMap = pendingMembersArray.map({
                    var contact = JSON($0.toJSON())
                    contact["pending"] = true
                    return contact
                }).sorted { $0["alias"].stringValue < $1["alias"].stringValue }
                
                weakSelf.groupContacts = weakSelf.getGroupContactsFrom(contacts: contactsMap)
                weakSelf.groupPendingContacts = weakSelf.getGroupContactsFrom(contacts: pendingContactsMap)
                
                weakSelf.tableView.reloadData()
            }
        })
    }
    
    func getGroupContactsFrom(contacts: [JSON]) -> [GroupContact] {
        var groupContacts = [GroupContact]()
        
        var lastLetter = ""
        
        for contact in  contacts {
            let id = contact.getJSONId() ?? CrypterManager.sharedInstance.generateCryptographicallySecureRandomInt(upperBound: 100_000)
            let nickname = contact["alias"].stringValue
            let avatarUrl = contact["photo_url"].stringValue
            let pubkey = contact["pubkey"].stringValue
            let isOwner = pubkey == (UserContact.getOwner()?.publicKey ?? "-1")
            
            if let initial = nickname.first {
                let initialString = String(initial)
            
                var groupContact = GroupContact()
                groupContact.id = id
                groupContact.nickname = nickname
                groupContact.avatarUrl = avatarUrl
                groupContact.isOwner = isOwner
                groupContact.pubkey = pubkey
                groupContact.selected = false
                groupContact.firstOnLetter = (initialString != lastLetter)
                
                lastLetter = initialString
                
                groupContacts.append(groupContact)
            }
        }
        
        return groupContacts
    }
}

extension GroupMembersDataSource {
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if let cell = cell as? GroupContactTableViewCell {
            let (gc, pending, lastCell) = getGroupContactFor(indexPath)
            cell.configureFor(groupContact: gc, chat: chat, delegate: self, isPending: pending, isLastCell: lastCell)
            cell.hideCheckBox()
        }
    }
    
    func getGroupContactFor(_ indexPath: IndexPath) -> (GroupContact, Bool, Bool) {
        let isPendingSection = isPendingContactsSection(indexPath.section)
        let sectionItemsCount = isPendingSection ? groupPendingContacts.count : groupContacts.count
        let isLastCell = indexPath.row == sectionItemsCount - 1
        let gc = isPendingSection ? groupPendingContacts[indexPath.row] : groupContacts[indexPath.row]
        return (gc, isPendingSection, isLastCell)
    }
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let windowWidth = WindowsManager.getWindowWidth()
        let margin: CGFloat = 16
        let headerView = UIView(frame: CGRect(x: 0, y: 0, width: windowWidth, height: kHeaderHeight))
        headerView.backgroundColor = UIColor.Sphinx.AddressBookHeader
        
        let headerLabel = UILabel(frame: CGRect(x: margin, y: 0, width: windowWidth - (margin * 2), height: kHeaderHeight))
        headerLabel.font = UIFont(name: "Roboto-Medium", size: 14.0)!
        headerLabel.textColor = UIColor.Sphinx.SecondaryText
        headerLabel.text = getSectionTitleFor(section)
        headerView.addSubview(headerLabel)
        
        let countLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 100, height: kHeaderHeight))
        countLabel.font = UIFont(name: "Roboto-Medium", size: 14.0)!
        countLabel.textColor = UIColor.Sphinx.SecondaryText
        countLabel.text = getSectionCountFor(section)
        countLabel.sizeToFit()
        countLabel.frame.size.height = kHeaderHeight
        countLabel.frame.origin.x = windowWidth - margin - countLabel.frame.width
        headerView.addSubview(countLabel)
        
        return headerView
    }
    
    func isPendingContactsSection(_ section: Int) -> Bool {
        return groupPendingContacts.count > 0 && section == 0
    }
    
    func getSectionTitleFor(_ section: Int) -> String {
        return isPendingContactsSection(section) ? "tribe.pending.members.upper".localized : tableTitle.uppercased()
    }
    
    func getSectionCountFor(_ section: Int) -> String {
        return isPendingContactsSection(section) ? "\(self.groupPendingContacts.count)" : "\(self.groupContacts.count)"
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        if groupPendingContacts.count > 0 {
            return 2
        }
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let shouldShowAddButton = !chat.isPublicGroup()
        let addButtonRowCount = shouldShowAddButton ? 1 : 0
        
        if isPendingContactsSection(section) {
            return groupPendingContacts.count
        } else {
            return groupContacts.count + addButtonRowCount
        }
    }
}

extension GroupMembersDataSource {
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.row == groupContacts.count {
            return kAddMemberCellHeight
        } else {
            return kCellHeight
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.row == groupContacts.count {
            let cell = tableView.dequeueReusableCell(withIdentifier: "GroupAddMemberTableViewCell", for: indexPath) as! GroupAddMemberTableViewCell
            cell.delegate = addMemberDelegate
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "GroupContactTableViewCell", for: indexPath) as! GroupContactTableViewCell
            return cell
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        //do nothing
    }
}

extension GroupMembersDataSource : GroupMemberCellDelegate {
    func didKickContact(contact: GroupAllContactsDataSource.GroupContact, cell: UITableViewCell) {
        if let chat = chat,
           let pubkey = contact.pubkey
        {
            messageBubbleHelper.showLoadingWheel()
            
            som.kickTribeMember(pubkey: pubkey, chat: chat)
            
            reloadContacts(chat: chat)
        } else {
            showErrorAlert()
        }
    }
    
    func shouldApproveMember(_ contact: GroupAllContactsDataSource.GroupContact, requestMessage: TransactionMessage) {
        respondToRequest(message: requestMessage, action: "approved", completion: { (chat, message) in
            self.reload(chat, and: message)
        })
    }
    
    func shouldRejectMember(_ contact: GroupAllContactsDataSource.GroupContact, requestMessage: TransactionMessage) {
        respondToRequest(message: requestMessage, action: "rejected", completion: { (chat, message) in
            self.reload(chat, and: message)
        })
    }
    
    func reload(_ chat: Chat, and message: TransactionMessage) {
        self.reloadContacts(chat: chat)
        self.groupDetailsDelegate?.shouldReloadMessage(message: message)
    }
    
    func respondToRequest(message: TransactionMessage, action: String, completion: @escaping (Chat, TransactionMessage) -> ()) {
        ///Implement approve/reject from pending members list
    }
    
    func showErrorAlert() {
        tableView.reloadData()
        messageBubbleHelper.hideLoadingWheel()
        AlertHelper.showAlert(title: "generic.error.title".localized, message: "generic.error.message".localized)
    }
}
