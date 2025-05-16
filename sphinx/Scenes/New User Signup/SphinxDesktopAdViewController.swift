//
//  SphinxDesktopAdViewController.swift
//  sphinx
//
//  Copyright © 2021 sphinx. All rights reserved.
//

import UIKit


class SphinxDesktopAdViewController: UIViewController {
    @IBOutlet weak var headlineLabel: UILabel!
    @IBOutlet weak var getItNowButtonView: UIButton!
    @IBOutlet weak var skipButtonView: UIButton!
    
    static let desktopAppStoreURL = URL(string: "https://testflight.apple.com/join/p721ALD9")!
    
    var isRestoreFlow: Bool = false
    
    static func instantiate() -> SphinxDesktopAdViewController {
        let viewController = StoryboardScene.NewUserSignup.sphinxDesktopAdViewController.instantiate()
        return viewController
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupHeadlineLabel()
        setupButtons()
    }
    
    
    @IBAction func getItNowButtonTapped(_ sender: UIButton) {
        UIApplication.shared.open(Self.desktopAppStoreURL)
    }
    
    
    @IBAction func skipButtonTapped(_ sender: UIButton) {
        if (isRestoreFlow) {
            goToApp()
        } else {
            let sphinxReadyVC = SphinxReadyViewController.instantiate()
            navigationController?.pushViewController(sphinxReadyVC, animated: true)
        }
    }
    
    func resetSignupData() {
        UserDefaults.Keys.inviteString.removeValue()
        UserDefaults.Keys.inviterNickname.removeValue()
        UserDefaults.Keys.inviterPubkey.removeValue()
        UserDefaults.Keys.welcomeMessage.removeValue()
    }
    
    func goToApp() {
        UserData.sharedInstance.completeSignup()
        resetSignupData()
        UserDefaults.Keys.lastPinDate.set(Date())
        
        DelayPerformedHelper.performAfterDelay(
            seconds: 1.0,
            completion: {
                if let appDelegate = UIApplication.shared.delegate as? AppDelegate,
                   let rootVC = appDelegate.getRootViewController()
                {
                    let mainCoordinator = MainCoordinator(rootViewController: rootVC)
                    mainCoordinator.presentInitialDrawer()
                }
            }
        )
    }
}


extension SphinxDesktopAdViewController {
    
    private func setupButtons() {
        [getItNowButtonView!, skipButtonView!].forEach { button in
            button.layer.cornerRadius = button.frame.size.height / 2
            button.clipsToBounds = true
            button.addShadow(location: .bottom, opacity: 0.2, radius: 2.0)
        }

        getItNowButtonView.layer.borderWidth = 1
        getItNowButtonView.layer.borderColor = UIColor.white.cgColor
        getItNowButtonView.setTitle(
            "signup.desktop-ad.get-now".localized,
            for: .normal
        )
        
        skipButtonView.setTitle(
            "signup.desktop-ad.skip".localized,
            for: .normal
        )
        skipButtonView.accessibilityIdentifier = "skipButtonView"
    }
    
    
    private func setupHeadlineLabel() {
        let labelText = "signup.desktop-ad.headline".localized
        let boldLabels = ["signup.desktop-ad.sphinx-on-desktop".localized]
        
        let normalFont = UIFont(name: "Roboto-Light", size: 30.0)!
        let boldFont = UIFont(name: "Roboto-Bold", size: 30.0)!
        
        
        headlineLabel.attributedText =  String.getAttributedText(
            string: labelText,
            boldStrings: boldLabels,
            font: normalFont,
            boldFont: boldFont
        )
    }
}
