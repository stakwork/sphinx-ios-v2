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
        
        view.endEditing(true)
        
        askForEnvironmentWith(code: code)
    }
    
    func askForEnvironmentWith(code: String) {
        AlertHelper.showOptionsPopup(
            title: "Network",
            message: "Please select the network to use",
            options: ["Bitcoin","Regtest"],
            callbacks: [
                {
                    UserDefaults.Keys.isProductionEnv.set(true)
                    self.continueWith(code: code)
                },
                {
                    UserDefaults.Keys.isProductionEnv.set(false)
                    self.continueWith(code: code)
                }
            ],
            sourceView: self.view,
            vc: self
        )
    }
    
    func continueWith(code: String) {
        UserData.sharedInstance.save(walletMnemonic: code)
        continueRestore()
    }
    
    func validateCode(_ code: String) -> Bool {
        if isCodeValid(code) {
            return true
        } else {
            return false
        }
    }
    
    func isCodeValid(_ code: String) -> Bool {
       return SphinxOnionManager.sharedInstance.isMnemonic(code: code)
    }
    
    func continueRestore() {
        guard let mnemonic = UserData.sharedInstance.getMnemonic() else {
            return
        }
        
        if SphinxOnionManager.sharedInstance.createMyAccount(mnemonic: mnemonic) {
            setupWatchdogTimer()
            listenForSelfContactRegistration()
            presentConnectingLoadingScreenVC()
        }
    }
    
    
    func presentPINVC(using encryptedKeys: String) {
        UserDefaults.Keys.defaultPIN.removeValue()
        
        let pinCodeVC = PinCodeViewController.instantiate()
        
        pinCodeVC.modalPresentationStyle = .overFullScreen
        
        present(pinCodeVC, animated: true)
        
        presentConnectingLoadingScreenVC()
    }
    
    func presentConnectingLoadingScreenVC() {
        let restoreExistingConnectingVC = RestoreUserConnectingViewController.instantiate()
        
        navigationController?.pushViewController(
            restoreExistingConnectingVC,
            animated: true
        )
    }
    
    func goToWelcomeCompleteScene() {
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
}


extension RestoreUserFormViewController : NSFetchedResultsControllerDelegate{
    
    func proceedToNewUserWelcome() {
        guard let inviter = SignupHelper.getInviter() else {
            
            let defaultInviter = SignupHelper.getSupportContact(includePubKey: false)
            SignupHelper.saveInviterInfo(invite: defaultInviter)
            
            proceedToNewUserWelcome()
            return
        }
        
        SignupHelper.step = SignupHelper.SignupStep.OwnerCreated.rawValue
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }

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
            som.isV2Restore = true
            
            proceedToNewUserWelcome()
        } else {
            navigationController?.popViewController(animated: true)
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
