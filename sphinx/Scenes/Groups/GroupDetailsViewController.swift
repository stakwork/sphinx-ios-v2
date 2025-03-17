//
//  GroupDetailsViewController.swift
//  sphinx
//
//  Created by Tomas Timinskas on 17/01/2020.
//  Copyright © 2020 Sphinx. All rights reserved.
//

import UIKit

class GroupDetailsViewController: UIViewController {
    @IBOutlet weak var membersTableView: UITableView!
    @IBOutlet weak var groupImageView: UIImageView!
    @IBOutlet weak var groupNameLabel: UILabel!
    @IBOutlet weak var groupNameTop: NSLayoutConstraint!
    @IBOutlet weak var groupDateLabel: UILabel!
    @IBOutlet weak var groupPriceLabel: UILabel!
    @IBOutlet weak var loadingWheel: UIActivityIndicatorView!
    @IBOutlet weak var groupOptionsButton: UIButton!
    @IBOutlet weak var viewTitle: UILabel!
    @IBOutlet weak var tribeMemberInfoContainer: UIView!
    @IBOutlet weak var tribeMemberInfoView: TribeMemberInfoView!
    @IBOutlet weak var imageUploadContainer: UIView!
    @IBOutlet weak var imageUploadLoadingWheel: UIActivityIndicatorView!
    @IBOutlet weak var imageUploadLabel: UILabel!
    @IBOutlet weak var tribeBadgesLabel: UILabel!
    
    @IBOutlet weak var badgeManagementContainerView: UIView!
    @IBOutlet weak var badgeManagementContainerHeight : NSLayoutConstraint!
    @IBOutlet weak var adminInfoContainerView: UIView!
    
    @IBOutlet weak var adminAvatarImageView: UIImageView!
    @IBOutlet weak var adminNameLabel: UILabel!
    @IBOutlet weak var adminSubtitleLabel: UILabel!
    @IBOutlet weak var groupInfoContainerView: UIView!
    @IBOutlet weak var timezoneSharingView: TimezoneSharingView!
    
    @IBOutlet var keyboardAccessoryView: UIView!
    
    
    var imagePickerManager = ImagePickerManager.sharedInstance
    var tableDataSource : GroupMembersDataSource!
    
    let kGroupNameTop: CGFloat = 31
    let kGroupNameWithPricesTop: CGFloat = 23
    
    
    var chat: Chat!
    
    var loading = false {
        didSet {
            LoadingWheelHelper.toggleLoadingWheel(loading: loading, loadingWheel: loadingWheel, loadingWheelColor: UIColor.Sphinx.Text, view: view)
        }
    }
    
    var uploading = false {
        didSet {
            imageUploadContainer.alpha = uploading ? 1.0 : 0.0
            LoadingWheelHelper.toggleLoadingWheel(loading: uploading, loadingWheel: imageUploadLoadingWheel, loadingWheelColor: UIColor.Sphinx.Text, view: view)
        }
    }
    
    static func instantiate(chat: Chat) -> GroupDetailsViewController {
        let viewController = StoryboardScene.Groups.groupDetailsViewController.instantiate()
        viewController.chat = chat
        
        return viewController
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        timezoneSharingView.delegate = self
        
        viewTitle.text = (chat.isPublicGroup() ? "tribe.details" : "group.details").localized
        tribeBadgesLabel.text = "badges.tribe-badges".localized
        
        loadData()
        setupTimezoneSharing()
    }
    
    func loadData() {
        membersTableView.alpha = chat.isPrivateGroup() || chat.isMyPublicGroup() ? 1.0 : 0.0
        
        setGroupInfo()
        configureTableView()
    }
    
    func setGroupInfo() {
        groupImageView.layer.cornerRadius = groupImageView.frame.size.height / 2
        groupImageView.clipsToBounds = true
        
        adminAvatarImageView.layer.cornerRadius = groupImageView.frame.size.height / 2
        adminAvatarImageView.clipsToBounds = true
        
        if let urlString = chat.photoUrl, let nsUrl = URL(string: urlString) {
            MediaLoader.asyncLoadImage(imageView: groupImageView, nsUrl: nsUrl, placeHolderImage: UIImage(named: "tribePlaceholder"))
        } else {
            groupImageView.image = UIImage(named: "tribePlaceholder")
        }
        
        adminSubtitleLabel.text = "admin".localized
        
        groupNameLabel.text = chat.name ?? "unknown.group".localized
        
        let createdOn = String(format: "created.on".localized, chat.createdAt.getStringDate(format: "EEE MMM dd HH:mm"))
        groupDateLabel.text = createdOn
        
        updateTribePrices()
        configureTribeAdminView()
        configureTribeMemberView()
//        configureBadgeManagementView()
    }
    
    func lookupAdminImage()->String?{
        if let tribeInfo = chat.tribeInfo,
           let ownerAlias = tribeInfo.ownerAlias,
           let messagesSet = chat.messages,
           let groupMessages = Array<Any>(messagesSet) as? [TransactionMessage],
           let ownerMessage = groupMessages.filter({$0.senderAlias == ownerAlias}).first{
            return ownerMessage.senderPic
        }
        return nil
    }
    
    func updateTribePrices() {
        if chat?.isPublicGroup() ?? false {
            if let prices = chat?.getTribePrices() {
                self.groupPriceLabel.text = String(format: "group.price.text".localized, "\(prices.0)", "\(prices.1)")
                self.groupNameTop.constant = self.kGroupNameWithPricesTop
            }
        }
    }
    
    func configureTribeMemberView() {
        if let chat = chat, let owner = UserContact.getOwner(), chat.isPublicGroup() {
            let alias = (chat.myAlias?.isNotEmpty == true) ? chat.myAlias : owner.nickname
            let photoUrl = (chat.myPhotoUrl?.isNotEmpty == true) ? chat.myPhotoUrl : owner.getPhotoUrl()
            
            tribeMemberInfoView.configureWith(
                vc: self,
                accessoryView: keyboardAccessoryView,
                alias: alias,
                picture: photoUrl
            )
            
            tribeMemberInfoContainer.isHidden = false
        } else {
            tribeMemberInfoContainer.isHidden = true
        }
    }
    
    func configureTribeAdminView() {
        if chat.isTribeICreated {
            adminInfoContainerView.isHidden = true
        } else {
            if let urlString = lookupAdminImage(),
               let nsUrl = URL(string: urlString) {
                MediaLoader.asyncLoadImage(imageView: adminAvatarImageView, nsUrl: nsUrl, placeHolderImage: UIImage(named: "profile_avatar"))
            } else {
                adminAvatarImageView.image = UIImage(named: "profile_avatar")
            }
            adminNameLabel.text = chat.tribeInfo?.ownerAlias ?? "unknown".localized
            
            adminInfoContainerView.isHidden = false
        }
    }
    
    func configureBadgeManagementView(){
        //TODO: @Jim reinstate when ready for v2 badges
//        if let chat = chat,
//           chat.isMyPublicGroup(){
//            badgeManagementContainerView.backgroundColor = UIColor.Sphinx.Body
//            badgeManagementContainerHeight.constant = 90
//            badgeManagementContainerView.isHidden = false
//            badgeManagementContainerView.isUserInteractionEnabled = true
//            badgeManagementContainerView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTapBadgeManagementView)))
//        }
    }
    
    @objc func didTapBadgeManagementView(){
        let badgeManagementVC = BadgeAdminManagementListVC.instantiate(chatID: chat.id)
        self.navigationController?.pushViewController(badgeManagementVC, animated: true)
    }
    
    func configureTableView() {
        membersTableView.registerCell(GroupContactTableViewCell.self)
        membersTableView.registerCell(GroupAddMemberTableViewCell.self)
        
        let title = (chat.isPublicGroup() ? "tribe.members.upper" : "group.members.upper").localized
        tableDataSource = GroupMembersDataSource(tableView: membersTableView, title: title)
        tableDataSource.addMemberDelegate = self
        membersTableView.backgroundColor = UIColor.Sphinx.Body
        membersTableView.delegate = tableDataSource
        membersTableView.dataSource = tableDataSource
        membersTableView.contentInset.bottom = getWindowInsets().bottom
        tableDataSource.reloadContacts(chat: chat)
    }
    
    func showOptions() {
        let optionsLabel = (chat.isPublicGroup() ? "tribe.options" : "group.options").localized
        let alert = UIAlertController(title: optionsLabel, message: "select.option".localized, preferredStyle: .actionSheet)
        
        let isPublicGroup = chat.isPublicGroup()
        let isMyPublicGroup = chat.isMyPublicGroup()
        
        if isPublicGroup {
            alert.addAction(UIAlertAction(title: "notifications.level".localized, style: .default, handler:{ (UIAlertAction) in
                self.goToNotificationsLevel()
            }))
            alert.addAction(UIAlertAction(title: "share.group".localized, style: .default, handler:{ (UIAlertAction) in
                self.goToShare()
            }))
            if isMyPublicGroup {
                alert.addAction(UIAlertAction(title: "edit.tribe".localized, style: .default, handler:{ (UIAlertAction) in
                    self.goToEditGroup()
                }))
                
                alert.addAction(UIAlertAction(title: "delete.tribe".localized, style: .destructive, handler:{ (UIAlertAction) in
                    self.exitAndDeleteGroup()
                }))
            } else {
                if chat.removedFromGroup() {
                    alert.addAction(UIAlertAction(title: "delete.tribe".localized, style: .destructive, handler:{ (UIAlertAction) in
                        self.exitAndDeleteGroup()
                    }))
                } else {
                    alert.addAction(UIAlertAction(title: "exit.tribe".localized, style: .destructive, handler:{ (UIAlertAction) in
                        self.exitAndDeleteGroup()
                    }))
                }
            }
        } else {
            alert.addAction(UIAlertAction(title: "exit.group".localized, style: .destructive, handler:{ (UIAlertAction) in
                self.exitAndDeleteGroup()
            }))
        }
        
        alert.addAction(UIAlertAction(title: "cancel".localized, style: .cancel ))
        alert.popoverPresentationController?.sourceView = groupOptionsButton
        alert.popoverPresentationController?.sourceRect = groupOptionsButton.bounds
        
        self.present(alert, animated: true, completion: nil)
    }
    
    func goToEditGroup() {
        let createGroupVC = NewPublicGroupViewController.instantiate(delegate: self, chat: chat)
        self.navigationController?.pushViewController(createGroupVC, animated: true)
    }
    
    func goToShare() {
        if let link = chat.getJoinChatLink() {
            let qrCodeDetailViewModel = QRCodeDetailViewModel(qrCodeString: link, amount: 0, viewTitle: "share.group.link".localized)
            let viewController = QRCodeDetailViewController.instantiate(with: qrCodeDetailViewModel)
            self.present(viewController, animated: true, completion: nil)
        }
    }
    
    func goToNotificationsLevel() {
        let notificationsVC = NotificationsLevelViewController.instantiate(chatId: chat.id, delegate: nil)
        self.present(notificationsVC, animated: true, completion: nil)
    }
    
    func exitAndDeleteGroup() {
//        if !NetworkMonitor.shared.isNetworkConnected() {
//            AlertHelper.showAlert(
//                title: "generic.error.title".localized,
//                message: SphinxOnionManagerError.SOMNetworkError.localizedDescription
//            )
//            return
//        }
        
        guard let chat = self.chat else {
            return
        }
        
        let isPublicGroup = chat.isPublicGroup()
        let isMyPublicGroup = chat.isMyPublicGroup()
        let deleteLabel = (isPublicGroup ? "delete.tribe" : "delete.group").localized
        let confirmDeleteLabel = (isMyPublicGroup ? "confirm.delete.tribe" : (isPublicGroup ? "confirm.exit.delete.tribe" : "confirm.exit.delete.group")).localized
        
        AlertHelper.showTwoOptionsAlert(title: deleteLabel, message: confirmDeleteLabel, confirm: {
            DispatchQueue.main.async {
                self.loading = true
            }
            
            let som = SphinxOnionManager.sharedInstance
            var success = false
            
            if isMyPublicGroup {
                success = som.deleteTribe(tribeChat: chat)
            } else {
                success = som.exitTribe(
                    tribeChat: chat,
                    errorCallback: { error in
                        AlertHelper.showAlert(
                            title: "generic.error.title".localized,
                            message: error.localizedDescription
                        )
                    }
                )
            }
            
            if !success {
                return
            }
            
            let _ = som.deleteContactOrChatMsgsFor(chat: chat)
            
            DispatchQueue.main.async {
                DelayPerformedHelper.performAfterDelay(seconds: 0.5) {
                    self.navigationController?.popToRootViewController(animated: true)
                    CoreDataManager.sharedManager.deleteChatObjectsFor(chat)
                }
            }
        })
    }

    
    func uploadImage(image: UIImage) {
//        let id = chat.id
//        let fixedImage = image.fixedOrientation()
//        loading = true
    }
    
    func imageUploaded(photoUrl: String?) {
        if let photoUrl = photoUrl {
            chat.photoUrl = photoUrl
        }
    }
    
    func shouldDismissView() {
        self.dismiss(animated: true, completion: nil)
    }
    
    func groupDeleted() {
        navigationController?.popToRootViewController(animated: true)

    }
    
    @IBAction func groupPictureButtonTouched() {
        let isPublicGroup = chat.isPublicGroup()
        if isPublicGroup { return }
        
        let imageLabel = (isPublicGroup ? "tribe.image" : "group.image").localized
        imagePickerManager.configurePicker(vc: self)
        imagePickerManager.showAlert(title: imageLabel, message: "select.option".localized, sourceView: groupImageView)
    }
    
    @IBAction func groupOptionsButtonTouched() {
        showOptions()
    }
    
    @IBAction func keyboardButtonTouched(_ sender: UIButton) {
        switch(sender.tag) {
        case 0:
            tribeMemberInfoView.shouldRevert()
        default:
            didChangeImageOrAlias()
        }
        view.endEditing(true)
    }
    
    @IBAction func backButtonTouched() {
        self.navigationController?.popViewController(animated: true)
    }
    
    func setupTimezoneSharing() {
        timezoneSharingView.delegate = self
        
        if let chat = self.chat {
            timezoneSharingView.configure(
                enabled: chat.timezoneEnabled,
                identifier: chat.timezoneIdentifier
            )
        } else {
            timezoneSharingView.configure(enabled: false, identifier: nil)
        }
    }
}

extension GroupDetailsViewController : UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let chosenImage = info[UIImagePickerController.InfoKey.originalImage] as? UIImage {
            let fixedImage = chosenImage.fixedOrientation()
            self.groupImageView.image = fixedImage
            
            picker.dismiss(animated:true, completion: {
                self.uploadImage(image: fixedImage)
            })
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
}

extension GroupDetailsViewController : AddFriendRowButtonDelegate {
    func didTouchAddFriend() {
        let groupContactVC = GroupContactsViewController.instantiate(delegate: self, chat: chat)
        self.present(groupContactVC, animated: true, completion: nil)
    }
}

extension GroupDetailsViewController : NewContactVCDelegate {
    func shouldReloadChat(chat: Chat) {
        self.chat = chat
        self.tableDataSource.chat = chat
        configureTableView()
        setGroupInfo()
    }
}

extension GroupDetailsViewController : TribeMemberInfoDelegate {
    func didUpdateUploadProgress(uploadString: String) {
        uploading = true
        imageUploadLabel.text = uploadString
    }
    
    func didChangeImageOrAlias() {
        tribeMemberInfoView.uploadImage(completion: {(alias, photoUrl) in
            self.uploading = false
            self.updateChat(alias: alias, photoUrl: photoUrl)
        })
    }
    
    func updateChat(alias: String?, photoUrl: String?) {
        guard let alias = alias, !alias.isEmpty else {
            AlertHelper.showAlert(title: "generic.error.title".localized, message: "alias.cannot.empty".localized)
            return
        }
        
        self.chat.myAlias = alias
        self.chat.myPhotoUrl = photoUrl ?? self.chat.myPhotoUrl
    }
}

extension GroupDetailsViewController : TimezoneSharingViewDelegate {
    func shouldPresentPickerViewWith(delegate: PickerViewDelegate) {
        let selectedValue = timezoneSharingView.getTimezoneIdentifier() ?? TimezoneSharingView.kDefaultValue
        var timezones = TimeZone.knownTimeZoneIdentifiers
        timezones.insert(TimezoneSharingView.kDefaultValue, at: 0)
        let pickerVC = PickerViewController.instantiate(values: timezones, selectedValue: selectedValue, delegate: delegate)
        self.present(pickerVC, animated: false, completion: nil)
    }
    
    func timezoneSharingSettingsChanged(enabled: Bool, identifier: String?) {
        guard let chat = self.chat else { return }
        
        let timezoneEnabledChanged = chat.timezoneEnabled != enabled
        let timezoneIdentifierChanged = chat.timezoneIdentifier != identifier
        
        if timezoneEnabledChanged || timezoneIdentifierChanged {
            chat.timezoneEnabled = enabled
            
            chat.timezoneIdentifier = identifier
            
            if timezoneIdentifierChanged {
                chat.timezoneUpdated = true
            }
            
            CoreDataManager.sharedManager.saveContext()
        }
    }
}
