//
//  NewUserSignupOptionsViewController.swift
//  sphinx
//
//  Copyright © 2021 sphinx. All rights reserved.
//

import UIKit
import StoreKit


class NewUserSignupOptionsViewController: UIViewController, ConnectionCodeSignupHandling {
    
    @IBOutlet weak var backButton: UIButton!
    @IBOutlet weak var screenHeadlineLabel: UILabel!
    @IBOutlet weak var connectionCodeButtonContainer: UIView!
    @IBOutlet weak var connectionCodeButton: UIButton!
    @IBOutlet weak var purchaseLiteNodeButtonContainer: UIView!
    @IBOutlet weak var purchaseLiteNodeButton: UIButton!
    @IBOutlet weak var purchaseLoadingSpinner: UIActivityIndicatorView!

    
    
    internal var hubNodeInvoice: API.HUBNodeInvoice?

    let newMessageBubbleHelper = NewMessageBubbleHelper()
    let storeKitService = StoreKitService.shared

    var generateTokenRetries = 0
    var hasAdminRetries = 0
    var generateTokenSuccess: Bool = false
    
    
    var isPurchaseProcessing: Bool = false {
        didSet {
            LoadingWheelHelper.toggleLoadingWheel(loading: isPurchaseProcessing, loadingWheel: purchaseLoadingSpinner, loadingWheelColor: UIColor.Sphinx.Text, view: view)
        }
    }

    
    var liteNodePurchaseProduct: SKProduct?
    
    
    static func instantiate() -> NewUserSignupOptionsViewController {
        let viewController = StoryboardScene.NewUserSignup.newUserSignupOptionsViewController.instantiate()
        return viewController
    }

    
    override func viewDidLoad() {
        super.viewDidLoad()

        setupButton(
            connectionCodeButton,
            withTitle: "signup.signup-options.connection-code-button".localized,
            withAccessibilityString: "signup.signup-options.connection-code-button"
        )
        
        setupButton(
            purchaseLiteNodeButton,
            withTitle: "signup.signup-options.lite-node-button".localized,
            withAccessibilityString: "signup.signup-options.lite-node-button"
        )
        
    }
    
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        storeKitService.requestDelegate = nil
    }
}
 

// MARK: - Action Handling
extension NewUserSignupOptionsViewController {
    
    @IBAction func backButtonTapped(_ sender: UIButton) {
        SignupHelper.step = SignupHelper.SignupStep.Start.rawValue
        
        navigationController?.popToRootViewController(animated: true)
    }
    
    
    @IBAction func connectionCodeButtonTapped(_ sender: UIButton) {
        let nextVC = NewUserSignupDescriptionViewController.instantiate()
        navigationController?.pushViewController(nextVC, animated: true)
    }

}


// MARK: - Private Helpers
extension NewUserSignupOptionsViewController {
 
    private func setupButton(
        _ button: UIButton,
        withTitle title: String,
        withAccessibilityString string: String
    ) {
        
        button.setTitle(title, for: .normal)
        button.layer.cornerRadius = button.frame.size.height / 2
        button.clipsToBounds = true
        
        button.addShadow(location: .bottom, opacity: 0.2, radius: 2.0)
        
        button.accessibilityIdentifier = string
    }
    
    
}





// MARK: - ConnectionCodeSignupHandling
extension NewUserSignupOptionsViewController {
    
    func handleSignupConnectionError(message: String) {
        // Pop the "Connecting" VC
        navigationController?.popViewController(animated: true)
        
        SignupHelper.resetInviteInfo()

        newMessageBubbleHelper.showGenericMessageView(text: message)
    }
}
