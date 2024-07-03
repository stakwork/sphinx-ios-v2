//
//  NewUserSignupFormViewController+FormSubmissionUtils.swift
//  sphinx
//
//  Copyright © 2021 sphinx. All rights reserved.
//

import UIKit
import CoreData


extension NewUserSignupFormViewController {
    
    @IBAction func submitButtonTapped(_ sender: UIButton) {
        handleSubmit()
    }
    
    @IBAction func qrCodeButtonTapped() {
        let viewController = NewQRScannerViewController.instantiate(
            currentMode: NewQRScannerViewController.Mode.ScanAndDismiss
        )
        viewController.delegate = self
        
        present(viewController, animated: true)
    }
}
    

extension NewUserSignupFormViewController {

    func handleSubmit() {
        guard
            let code = codeTextField.text,
            code.isEmpty == false
        else { return }

        guard validateCode(code) else { return }

        view.endEditing(true)
        
        continueWith(code: code)
    }
    
    func continueWith(code: String) {
        if (code.isInviteCode) {
            som.vc = self
            som.chooseImportOrGenerateSeed(completion: { [weak self] success in
                guard let self = self else {
                    return
                }
                
                if (success), let code = self.codeTextField.text {
                    self.handleInviteCode(code: code)
                } else {
                    self.showInviteError()
                }
                self.som.vc = nil
            })
        }
    }
    
    func handleInviteCode(code: String) {
        guard let mnemonic = UserData.sharedInstance.getMnemonic() else {
            showInviteError()
            return
        }
        
        let inviteCode = som.redeemInvite(inviteCode: code)
        
        guard let inviteCode = inviteCode else {
            showInviteError()
            return
        }
        
        if som.createMyAccount(
            mnemonic: mnemonic,
            inviteCode: inviteCode
        ) {
            setupWatchdogTimer()
            listenForSelfContactRegistration()
            getConfigData()
        }
    }
    
    func getConfigData(){
        if UserDefaults.Keys.isProductionEnv.get(defaultValue: false) == false {
            presentConnectingLoadingScreenVC()
            return
        }
        
        API.sharedInstance.getServerConfig() { success in
            if success {
                self.presentConnectingLoadingScreenVC()
            } else {
                self.navigationController?.popViewController(animated: true)
                AlertHelper.showAlert(title: "Error", message: "Unable to get config from Sphinx V2 Server")
            }
        }
    }
    
    func showInviteError() {
        AlertHelper.showAlert(
            title: "Error redeeming invite",
            message: "Please try again or ask for another invite."
        )
    }
    
    func isCodeValid(_ code: String) -> Bool {
        return code.isInviteCode
    }
    
    func validateCode(_ code: String) -> Bool {
        if isCodeValid(code) {
            return true
        } else {
            newMessageBubbleHelper.showGenericMessageView(
                text: "invalid.code".localized,
                delay: 6,
                textColor: UIColor.white,
                backColor: UIColor.Sphinx.BadgeRed,
                backAlpha: 1.0
            )
            
            return false
        }
    }
    
    func handleSignupConnectionError(message: String) {
        // Pop the "Connecting" VC
        navigationController?.popViewController(animated: true)

        SignupHelper.resetInviteInfo()

        codeTextField.text = ""
        newMessageBubbleHelper.showGenericMessageView(text: message)
    }
}


extension NewUserSignupFormViewController: QRCodeScannerDelegate {
    
    func didScanQRCode(string: String) {
        codeTextField.text = string
        
        textFieldDidEndEditing(codeTextField)
        
        handleSubmit()
    }
}


extension NewUserSignupFormViewController : NSFetchedResultsControllerDelegate{
    
    private func listenForSelfContactRegistration() {
        let managedContext = CoreDataManager.sharedManager.persistentContainer.viewContext

        let fetchRequest: NSFetchRequest<UserContact> = UserContact.fetchRequest()
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
