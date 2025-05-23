//
//  RestoreUserFormViewController+KeychainRestorationUtils.swift
//  sphinx
//
//  Copyright © 2021 sphinx. All rights reserved.
//

import UIKit


extension RestoreUserFormViewController {
    
    @IBAction func keychainRestoreButtonTouched() {
//        authenticationHelper.authenticationAction(policy: .deviceOwnerAuthentication) { success in
//            if success {
//                self.goToKeychainRestore()
//            }
//        }
    }
}


extension RestoreUserFormViewController {
    
    func goToApp() {
        goToWelcomeCompleteScene()
    }
    
    func willDismiss() {
        setupKeychainButtonContainer()
    }
    
    func shouldShowError() {
        newMessageBubbleHelper.showGenericMessageView(text: "error.restoring.keychain".localized)
    }
}
