//
//  MainCoordinator.swift
//  sphinx
//
//  Created by Tomas Timinskas on 12/09/2019.
//  Copyright © 2019 Sphinx. All rights reserved.
//

import UIKit
import KYDrawerController

final class MainCoordinator: NSObject {

    var drawerController : KYDrawerController!
    var rootViewController : RootViewController!
    
    public init(rootViewController: RootViewController) {
        self.rootViewController = rootViewController
    }
    
    func presentSignUpScreen() {
//        switch(SignupHelper.step) {
//        case SignupHelper.SignupStep.Start.rawValue:
//            presentInitialWelcomeViewController()
//        case SignupHelper.SignupStep.OwnerCreated.rawValue:
//            presentInviteWelcomeViewController()
//        case SignupHelper.SignupStep.InviterContactCreated.rawValue:
//            presentSetPinViewController()
//        case SignupHelper.SignupStep.PINSet.rawValue:
//            presentNewUserGreetingViewController()
//        case SignupHelper.SignupStep.PersonalInfoSet.rawValue:
//            presentSphinxReadyViewController()
//        case SignupHelper.SignupStep.SignupComplete.rawValue:
//            presentInitialDrawer()
//        default:
//            presentInitialWelcomeViewController()
//        }
        
        UserData.sharedInstance.clearData()
        presentInitialWelcomeViewController()
    }
    
    func presentInitialWelcomeViewController() {
        let initialWelcomeVC = InitialWelcomeViewController.instantiate()
        presentSignupVC(vc: initialWelcomeVC)
    }
    
    
    func presentNewUserSignupOptionsViewController() {
        let vc = InitialWelcomeViewController.instantiate()
        presentSignupVC(vc: vc)
    }
    
    func presentInviteWelcomeViewController() {
        if let inviter = SignupHelper.getInviter() {
            let inviteWelcome = InviteWelcomeViewController.instantiate(inviter: inviter)
            presentSignupVC(vc: inviteWelcome)
        }
    }
    
    func presentSetPinViewController() {
        let setPinVC = SetPinCodeViewController.instantiate()
        presentSignupVC(vc: setPinVC)
    }
    
    func presentNewUserGreetingViewController() {
        let greetingVC = NewUserGreetingViewController.instantiate()
        presentSignupVC(vc: greetingVC)
    }
    
    func presentPersonalInfoViewController() {
        let nicknameVC = SetNickNameViewController.instantiate()
        presentSignupVC(vc: nicknameVC)
    }

    func presentSphinxReadyViewController() {
        let sphinxReadyVC = SphinxReadyViewController.instantiate()
        presentSignupVC(vc: sphinxReadyVC)
    }
    
    func presentSignupVC(vc: UIViewController) {
        let navigationController = UINavigationController(rootViewController: vc)
        navigationController.isNavigationBarHidden = true
        
        rootViewController.setInitialViewController(navigationController)
    }
    
    
    func presentInitialDrawer() {
        AttachmentsManager.sharedInstance.runAuthentication(forceAuthenticate: true)
        
        let leftViewController = LeftMenuViewController.instantiate()
        let mainViewController = DashboardRootViewController.instantiate(leftMenuDelegate: leftViewController)
        let navigationController = UINavigationController(rootViewController: mainViewController)

        drawerController = KYDrawerController(drawerDirection: .left, drawerWidth: 270.0)
        drawerController.delegate = leftViewController
        drawerController.screenEdgePanGestureEnabled = false
        drawerController.mainViewController = navigationController
        drawerController.drawerViewController = leftViewController

        drawerController.setDrawerState(.opened, animated: false)
        drawerController.setDrawerState(.closed, animated: false)
        
        rootViewController.switchToViewController(drawerController)
    }
}

extension MainCoordinator : LeftMenuDelegate {
    func shouldOpenLeftMenu() {}
}
