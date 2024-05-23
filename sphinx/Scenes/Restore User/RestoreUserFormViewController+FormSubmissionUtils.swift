//
//  RestoreUserFormViewController+FormSubmissionUtils.swift
//  sphinx
//
//  Copyright © 2021 sphinx. All rights reserved.
//

import UIKit
import CoreData


extension RestoreUserFormViewController {
    
    func handleSubmit() {
        guard
            let code = codeTextField.text,
            code.isEmpty == false
        else {
            return
        }

        guard validateCode(code) else { return }
        
        if(SphinxOnionManager.sharedInstance.isMnemonic(code: code)){
            goMnemonicRoute()
            return
        }

        guard let encryptedKeys = encryptedKeysFromCode(code) else { return }
        
        presentPINVC(using: encryptedKeys)
    }
    
    
    func validateCode(_ code: String) -> Bool {
        if isCodeValid(code) {
            return true
        } else {
            handleInvalidCodeSubmission(code)
            
            return false
        }
    }
    
    
    func connectTorIfNeededBeforeProceeding() -> Bool {
        if onionConnector.usingTor() && !onionConnector.isReady() {
            onionConnector.startTor(delegate: self)
            return true
        }
        return false
    }
    
    
    func encryptedKeysFromCode(_ code: String) -> String? {
        code.getRestoreKeys() ??
        code.fixedRestoreCode.getRestoreKeys()
    }
    
    func isCodeValid(_ code: String) -> Bool {
       return (code.isRestoreKeysString ||
        code.fixedRestoreCode.isRestoreKeysString ||
        SphinxOnionManager.sharedInstance.isMnemonic(code: code))
    }
    
    func goMnemonicRoute(){
        if let code = codeTextField.text,
           code.isEmpty == false,
           SphinxOnionManager.sharedInstance.isMnemonic(code: code){
            UserData.sharedInstance.save(walletMnemonic: code)
            if let mnemonic = UserData.sharedInstance.getMnemonic(),
               SphinxOnionManager.sharedInstance.createMyAccount(mnemonic: mnemonic){
                setupWatchdogTimer()
                listenForSelfContactRegistration()//get callbacks ready for sign up
                presentConnectingLoadingScreenVC()
            }
        }
    }
    
    
    func presentPINVC(using encryptedKeys: String) {
        UserDefaults.Keys.defaultPIN.removeValue()
        
        let pinCodeVC = PinCodeViewController.instantiate()
        
        pinCodeVC.modalPresentationStyle = .overFullScreen
        
        present(pinCodeVC, animated: true)
        
        presentConnectingLoadingScreenVC()
    }


    func connectRestoredUser(
        encryptedKeys: String,
        pin: String
    ) {
        guard
            let keys = SymmetricEncryptionManager
                .sharedInstance
                .decryptRestoreKeys(
                    encryptedKeys: encryptedKeys.fixedRestoreCode,
                    pin: pin
                ),
            EncryptionManager.sharedInstance.insertKeys(privateKey: keys[0], publicKey: keys[1])
        else {
            errorRestoring(message: "invalid.pin".localized)
            return
        }

        userData.save(ip: keys[2], token: keys[3], pin: pin)
    }
    
    
    func presentConnectingLoadingScreenVC() {
        let restoreExistingConnectingVC = RestoreUserConnectingViewController.instantiate()
        
        navigationController?.pushViewController(
            restoreExistingConnectingVC,
            animated: true
        )
    }
    
    
    func goToWelcomeCompleteScene() {
        if connectTorIfNeededBeforeProceeding() {
            return
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            
            let welcomeCompleteVC = WelcomeCompleteViewController.instantiate()
            
            self.navigationController?.pushViewController(
                welcomeCompleteVC,
                animated: true
            )
        }
    }
    
    
    func errorRestoring(message: String) {
        navigationController?.popViewController(animated: true)
        
        newMessageBubbleHelper.showGenericMessageView(text: message)
    }
    
    
    func handleInvalidCodeSubmission(_ code: String) {
        var errorMessage: String
        
        if code.isRelayQRCode {
            errorMessage = "restore.invalid-code.relay-qr-code".localized
        } else if code.isPubKey {
            errorMessage = "invalid.code.pubkey".localized
        } else if code.isLNDInvoice {
            errorMessage = "invalid.code.invoice".localized
        } else {
            errorMessage = "invalid.code".localized
        }
        
        newMessageBubbleHelper.genericMessageY = (
            UIApplication.shared.keyWindow?.safeAreaInsets.top ?? 60
        ) + 60
        
        newMessageBubbleHelper.showGenericMessageView(
            text: errorMessage,
            delay: 6,
            textColor: UIColor.white,
            backColor: UIColor.Sphinx.BadgeRed,
            backAlpha: 1.0
        )
    }
}



extension RestoreUserFormViewController: SphinxOnionConnectorDelegate {
    func onionConnecting() {}
    
    func onionConnectionFinished() {
        goToWelcomeCompleteScene()
    }
    
    func onionConnectionFailed() {
        errorRestoring(message: "tor.connection.failed".localized)
    }
}


extension RestoreUserFormViewController : NSFetchedResultsControllerDelegate{
    
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
            
            SignupHelper.step = SignupHelper.SignupStep.InviterContactCreated.rawValue
            
            let setPinVC = SetPinCodeViewController.instantiate()
            setPinVC.isRestoreFlow = true
            self.navigationController?.pushViewController(setPinVC, animated: true)
        }
    }
    
    func finalizeSignup(){
        let som = SphinxOnionManager.sharedInstance

        if let _ = UserContact.getOwner() {
            som.isV2InitialSetup = true
            
            self.proceedToNewUserWelcome()
        } else {
            self.navigationController?.popViewController(animated: true)
            AlertHelper.showAlert(title: "Error", message: "Unable to connect to Sphinx V2 Test Server")
        }
    }
    
    
    private func listenForSelfContactRegistration() {
        let managedContext = CoreDataManager.sharedManager.persistentContainer.viewContext

        let fetchRequest: NSFetchRequest<UserContact> = UserContact.fetchRequest()
        // Assuming 'isOwner' and 'routeHint' are attributes of your UserContact entity
        fetchRequest.predicate = NSPredicate(format: "isOwner == true AND routeHint != nil")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "index", ascending: true)]
        
        selfContactFetchListener = NSFetchedResultsController(
            fetchRequest: fetchRequest,
            managedObjectContext: managedContext,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        
        selfContactFetchListener?.delegate = self

        do {
            try selfContactFetchListener?.performFetch()
        } catch _ as NSError {
            watchdogTimer?.invalidate()
            selfContactFetchListener = nil
        }
    }
    
    func controller(
        _ controller: NSFetchedResultsController<NSFetchRequestResult>,
        didChangeContentWith snapshot: NSDiffableDataSourceSnapshotReference
    ) {
        if let resultController = controller as? NSFetchedResultsController<NSManagedObject>,
           let firstSection = resultController.sections?.first {
            
            if let _ = firstSection.objects?.first {
                selfContactFetchListener = nil
                
                watchdogTimer?.invalidate()
                watchdogTimer = nil
                
                finalizeSignup()
            }
        }
    }
    
    private func setupWatchdogTimer() {
        watchdogTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            
            if self.selfContactFetchListener?.fetchedObjects?.first == nil {
                DispatchQueue.main.async {
                    self.navigationController?.popViewController(animated: true)
                }
            } else {
                self.finalizeSignup()
            }
        }
    }
}
