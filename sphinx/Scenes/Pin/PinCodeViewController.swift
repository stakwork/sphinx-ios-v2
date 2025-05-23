//
//  PinCodeViewController.swift
//  sphinx
//
//  Created by Tomas Timinskas on 17/09/2019.
//  Copyright © 2019 Sphinx. All rights reserved.
//

import UIKit
import AVFoundation
import LocalAuthentication

class PinCodeViewController: UIViewController {
    
    @IBOutlet var dotViews: [UIView]!
    @IBOutlet var keyPadButtons: [UIButton]!
    @IBOutlet weak var subtitleLabel: UILabel!
    
    @IBOutlet weak var loadingWheel: UIActivityIndicatorView!
    
    var pinArray = [Int]()
    let kDeleteButtonTag = 10
    
    var didStartTyping = false
    var subtitle = ""
    
    var loading = false {
        didSet {
            LoadingWheelHelper.toggleLoadingWheel(loading: loading, loadingWheel: loadingWheel, loadingWheelColor: UIColor.white, view: view)
        }
    }
    
    var authenticationHelper = BiometricAuthenticationHelper()
    var doneCompletion: ((String) -> ())? = nil
    var loggingCompletion: (() -> ())? = nil
    
    static func instantiate(subtitle: String = "") -> PinCodeViewController {
        let viewController = StoryboardScene.Pin.pinCodeViewController.instantiate()
        viewController.subtitle = subtitle
        return viewController
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        loading = false
        subtitleLabel.text = subtitle
        
        reloadDots()
        configureButtons()
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        self.view.endEditing(true)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
//        DelayPerformedHelper.performAfterDelay(seconds: 0.5, completion: {
//           self.biometricAction()
//        })
    }
    
    func configureButtons() {
        for button in keyPadButtons {
            button.setTitleColor(UIColor.Sphinx.HeaderBG.withAlphaComponent(0.5), for: .highlighted)
        }
    }
    
    func reloadDots() {
        for dot in dotViews {
            dot.layer.cornerRadius = dot.frame.height/2
            dot.layer.borderColor = UIColor.white.cgColor
            dot.layer.borderWidth = 1
            dot.clipsToBounds = true
            
            dot.backgroundColor = dot.tag < pinArray.count ? UIColor.white : UIColor.clear
        }
    }
    
    @IBAction func pinButtonTouched(_ sender: UIButton) {
        didStartTyping = true
        
        if sender.tag == kDeleteButtonTag {
            if pinArray.count > 0 {
                SoundsPlayer.playKeySound(soundId: SoundsPlayer.deleteSoundID)
                pinArray.removeLast()
            }
        } else {
            if pinArray.count < 6 {
                SoundsPlayer.playKeySound(soundId: SoundsPlayer.keySoundID)
                pinArray.append(sender.tag)
            }
        }
        reloadDots()
        
        if pinArray.count >= 6 {
            loading = true
            
            DelayPerformedHelper.performAfterDelay(seconds: 0.5) {
                self.doneButtonTouched()
            }
        }
    }
    
    func getPinString() -> String {
        var pin = ""
        for number in pinArray {
            pin = "\(pin)\(number)"
        }
        return pin
    }
    
    func setPinArray(pin: String) {
        pinArray = pin.compactMap{ $0.wholeNumberValue }
    }
    
    func doneButtonTouched() {
        let pin = getPinString()
        checkLaunchPIN(pin: pin)
    }
    
    func checkLaunchPIN(pin: String) {
        if let doneCompletion = doneCompletion, pin == UserData.sharedInstance.getAppPin() {
            doneCompletion(pin)
        }  else if let storedPin = UserData.sharedInstance.getStoredPin() {// if migrating from stored pin act accordingly
            if (storedPin == pin){
                guard let unencryptedMnemonic = UserData.sharedInstance.getStoredUnencryptedMnemonic(),
                      SphinxOnionManager.sharedInstance.isMnemonic(code: unencryptedMnemonic) else 
                {
                    loading = false
                    
                    AlertHelper.showAlert(
                        title: "Data Corruption Error",
                        message: "There was an issue migrating your account. Please try again with restore from your written mnemonic."
                    )
                    
                    pinArray = []
                    reloadDots()
                    return
                }
                SphinxOnionManager.sharedInstance.appSessionPin = pin
                UserData.sharedInstance.clearStoredPin()
                UserData.sharedInstance.save(walletMnemonic: unencryptedMnemonic)
                DelayPerformedHelper.performAfterDelay(seconds: 0.5, completion: {
                    self.finalizePinEntry(pin: pin)
                })
            } else {
                showInvalidPinError()
            }
        } else {
            finalizePinEntry(pin: pin)
        }
    }
    
    func finalizePinEntry(pin: String) {
        let valid = GroupsPinManager.sharedInstance.isValidPin(pin)
        if valid {
            UserDefaults.Keys.lastPinDate.set(Date())
            
            WindowsManager.sharedInstance.removeCoveringWindow()
            
            if let loggingCompletion = self.loggingCompletion {
                loggingCompletion()
            }
        } else {
            showInvalidPinError()
        }
    }
    
    func showInvalidPinError(){
        loading = false
        
        AlertHelper.showAlert(
            title: "generic.error.title".localized,
            message: "invalid.pin".localized,
            on: self
        )
        
        pinArray = []
        reloadDots()
    }
    
    func shouldUseBiometricAuthentication() -> Bool {
//        let isNodeSet = UserData.sharedInstance.getAppPin() != nil
//        
//        return authenticationHelper.canUseBiometricAuthentication() && isNodeSet && doneCompletion == nil
        return false
    }
    
    func biometricAction() {
//        if !shouldUseBiometricAuthentication() || didStartTyping || GroupsPinManager.sharedInstance.shouldAvoidFaceID {
//            return
//        }
//        
//        authenticationHelper.authenticationAction() { success in
//            if success {
//                if let pin =  UserData.sharedInstance.getAppPin() {
//                    self.setPinArray(pin: pin)
//                    self.doneButtonTouched()
//                }
//            }
//        }
    }
}
