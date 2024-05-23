//
//  ConnectionCodeSignupHandling.swift
//  sphinx
//
//  Copyright © 2021 sphinx. All rights reserved.
//

import UIKit
import Foundation


protocol ConnectionCodeSignupHandling: UIViewController {
    var userData: UserData { get }
    
    func presentConnectingLoadingScreenVC()

    func handleSignupConnectionError(message: String)

    func proceedToNewUserWelcome()
}


// MARK: - Default Properties
extension ConnectionCodeSignupHandling {
    var userData: UserData { .sharedInstance }
    var onionConnector: SphinxOnionConnector { .sharedInstance }
}


// MARK: - Default Method Implementations
extension ConnectionCodeSignupHandling {
    
    func signup(withConnectionCode connectionCode: String) {
        presentConnectingLoadingScreenVC()
        
    }
    
    func finalizeSignup(){
        let som = SphinxOnionManager.sharedInstance
        if let _ = UserContact.getOwner() {
            if let vc = self as? NewUserSignupFormViewController {
                vc.isV2 = true
            }
            som.isV2InitialSetup = true
            proceedToNewUserWelcome()
        } else {
            self.navigationController?.popViewController(animated: true)
            AlertHelper.showAlert(title: "Error", message: "Unable to connect to Sphinx V2 Test Server")
        }
    }
    
    
    func presentConnectingLoadingScreenVC() {
        let connectingVC = RestoreUserConnectingViewController.instantiate()
        
        navigationController?.pushViewController(
            connectingVC,
            animated: true
        )
    }
    
    func proceedToNewUserWelcome() {
        guard let inviter = SignupHelper.getInviter() else {
            
            let defaultInviter = SignupHelper.getSupportContact(includePubKey: false)
            SignupHelper.saveInviterInfo(invite: defaultInviter)
            
            proceedToNewUserWelcome()
            return
        }
        
        SignupHelper.step = SignupHelper.SignupStep.IPAndTokenSet.rawValue
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }

            let inviteWelcomeVC = InviteWelcomeViewController.instantiate(
                inviter: inviter
            )
            self.navigationController?.pushViewController(inviteWelcomeVC, animated: true)
        }
    }
}

