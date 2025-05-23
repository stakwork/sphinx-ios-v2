//
//  InviteWelcomeViewController.swift
//  sphinx
//
//  Created by Tomas Timinskas on 20/09/2019.
//  Copyright © 2019 Sphinx. All rights reserved.
//

import UIKit

class InviteWelcomeViewController: UIViewController {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var contactImageView: UIImageView!
    @IBOutlet weak var contactNameLabel: UILabel!
    @IBOutlet weak var welcomeMessageLabel: UILabel!
    @IBOutlet weak var nextButtonContainer: UIView!
    @IBOutlet weak var loadingWheel: UIActivityIndicatorView!
    @IBOutlet weak var nextButton: UIButton!
    
    var loading = false {
        didSet {
            LoadingWheelHelper.toggleLoadingWheel(loading: loading, loadingWheel: loadingWheel, loadingWheelColor: UIColor.white, view: view)
        }
    }
    
    var currentInviter : SignupHelper.Inviter?
    
    static func instantiate(inviter: SignupHelper.Inviter) -> InviteWelcomeViewController {
        let viewController = StoryboardScene.Invite.inviteWelcomeViewController.instantiate()
        viewController.currentInviter = inviter
        
        return viewController
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        setStatusBarColor()
        
        nextButtonContainer.layer.cornerRadius = nextButtonContainer.frame.size.height / 2
        nextButtonContainer.clipsToBounds = true
        nextButtonContainer.addShadow(location: .bottom, opacity: 0.5, radius: 2.0)
        
        contactImageView.layer.cornerRadius = contactImageView.frame.size.height / 2
        contactImageView.clipsToBounds = true
        
        if let profile = UserContact.getOwner() {
            if let imageUrl = profile.avatarUrl?.trim(), let nsUrl = URL(string: imageUrl) {
                MediaLoader.asyncLoadImage(imageView: contactImageView, nsUrl: nsUrl, placeHolderImage: UIImage(named: "profile_avatar"))
            }
        }
        
        if let alias = SphinxOnionManager.sharedInstance.stashedInviterAlias {
            contactNameLabel.text = alias
        } else if let inviter = currentInviter {
            contactNameLabel.text = inviter.nickname
            welcomeMessageLabel.text = inviter.welcomeMessage
        }
        
        setTitle()
    }
    
    func setTitle() {
        titleLabel.text = "message.from.friend".localized
        nextButton.accessibilityIdentifier = "getStartedNextButton"
    }
    
    @IBAction func nextButtonTouched() {
        loading = true
        self.continueToPinView()
    }
    
    func continueToPinView() {
        UserData.sharedInstance.signupStep = SignupHelper.SignupStep.InviterContactCreated.rawValue
        
        let setPinVC = SetPinCodeViewController.instantiate()
        self.navigationController?.pushViewController(setPinVC, animated: true)
    }
    
    func didFailCreatingContact() {
        loading = false
        AlertHelper.showAlert(title: "generic.error.title".localized, message: "generic.error.message".localized)
    }
}
