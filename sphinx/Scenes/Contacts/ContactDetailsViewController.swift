//
//  ContactDetailsViewController.swift
//  sphinx
//
//  Created by Tomas Timinskas on 20/12/2024.
//  Copyright © 2024 sphinx. All rights reserved.
//

import UIKit

class ContactDetailsViewController: UIViewController {
    
    @IBOutlet weak var contactAvatarView: ChatAvatarView!
    @IBOutlet weak var contactName: UILabel!
    @IBOutlet weak var contactDate: UILabel!
    @IBOutlet weak var publicKeyLabel: UILabel!
    @IBOutlet weak var routeHintLabel: UILabel!
    @IBOutlet weak var removeContactButtonBack: UIView!
    @IBOutlet weak var timezoneSharingView: TimezoneSharingView!
    
    var contact: UserContact! = nil
    
    static func instantiate(
        contactId: Int
    ) -> ContactDetailsViewController {
        
        let viewController = StoryboardScene.Contacts.contactDetailsViewController.instantiate()
        viewController.contact = UserContact.getContactWith(id: contactId)

        return viewController
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupView()
        setupContactInfo()
    }
    
    func setupView() {
        removeContactButtonBack.backgroundColor = UIColor.Sphinx.PrimaryRed.withAlphaComponent(0.1)
        removeContactButtonBack.layer.cornerRadius = 6
    }
    
    func setupContactInfo() {
        guard let contact = contact else {
            return
        }
        contactAvatarView.setInitialLabelSize(size: 25)
        contactAvatarView.configureForUserWith(
            color: contact.getColor(),
            alias: contact.getName(),
            picture: contact.getPhotoUrl()
        )
        
        contactName.text = contact.getName()
        contactDate.text = String.init(format: "contact.connected.since".localized, contact.createdAt.getStringDate(format: "MMMM dd, YYYY"))
        publicKeyLabel.text = contact.publicKey ?? ""
        routeHintLabel.text = contact.routeHint ?? ""
    }
    
    @IBAction func contactAvatarButtonTapped() {
        if let urlString = contact.getPhotoUrl(),
            let url = URL(string: urlString),
            let attachmentFullScreenVC = AttachmentFullScreenViewController.instantiate(animated: false, imageUrl: url)
        {
            self.navigationController?.present(attachmentFullScreenVC, animated: false)
        }
    }
    
    @IBAction func backButtonTapped() {
        self.navigationController?.popViewController(animated: true)
    }
    
    @IBAction func publicKeyButtonTapped() {
        if let contact = contact {
            guard let qrCodeString = contact.getAddress() else { return }
            
            let qrCodeDetailViewModel = QRCodeDetailViewModel(
                qrCodeString: qrCodeString,
                amount: 0,
                viewTitle: "public.key".localized
            )
            let viewController = QRCodeDetailViewController.instantiate(with: qrCodeDetailViewModel)
            self.present(viewController, animated: true, completion: nil)
        }
    }
    
    @IBAction func removeContactButtonTapped(_ sender: Any) {
        guard let contact = contact else {
            AlertHelper.showAlert(
                title: "generic.error.title".localized,
                message: "generic.error.message".localized
            )
            
            return
        }
        
        let confirmDeletionCallback: (() -> ()) = {
            self.shouldDeleteContact(contact: contact)
        }
            
        AlertHelper.showTwoOptionsAlert(
            title: "warning".localized,
            message: (contact.isInvite() ? "delete.invite.warning" : "delete.contact.warning").localized,
            confirm: confirmDeletionCallback
        )
    }
    
    func shouldDeleteContact(contact: UserContact) {
        let som = SphinxOnionManager.sharedInstance
        
        if let inviteCode = contact.invite?.inviteString, contact.isInvite() {
            if !som.cancelInvite(inviteCode: inviteCode) {
                AlertHelper.showAlert(
                    title: "generic.error.title".localized,
                    message: "generic.error.message".localized
                )
                return
            }
        }
        
        if let publicKey = contact.publicKey, publicKey.isNotEmpty {
            if som.deleteContactOrChatMsgsFor(contact: contact) {
                som.deleteContactFromState(pubkey: publicKey)
            }
        }
                
        CoreDataManager.sharedManager.deleteContactObjectsFor(contact)
        
        self.navigationController?.popToRootViewController(animated: true)
    }
}
