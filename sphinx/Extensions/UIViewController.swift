//
//  UIViewController.swift
//  sphinx
//
//  Created by Tomas Timinskas on 20/03/2020.
//  Copyright © 2020 Sphinx. All rights reserved.
//

import UIKit
private var darkeningViewKey: UInt8 = 21

extension UIViewController {
    func presentNavigationControllerWith(vc: UIViewController) {
        let navigationController = UINavigationController()
        navigationController.viewControllers = [vc]
        navigationController.isNavigationBarHidden = true
        navigationController.modalPresentationStyle = .overCurrentContext
        self.present(navigationController, animated: true)
    }
    
    func addChildVC(child: UIViewController, container: UIView) {
        addChild(child)
        child.view.frame = container.bounds
        container.addSubview(child.view)
        child.didMove(toParent: self)
    }
    
    
    func removeChildVC(child: UIViewController) {
        if let _ = child.parent {
            child.willMove(toParent: nil)
            child.removeFromParent()
            child.view.removeFromSuperview()
        }
    }
    
    func setStatusBarColor() {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
            return
        }
        guard let rootVC = appDelegate.getRootViewController() else {
            return
        }
        rootVC.setStatusBar()
    }
    
    private var darkeningView: UIView? {
        get {
            return objc_getAssociatedObject(self, &darkeningViewKey) as? UIView
        }
        set {
            objc_setAssociatedObject(self, &darkeningViewKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    func toggleDarkening(darkened: Bool, animated: Bool = true, duration: TimeInterval = 0.3, completion: (() -> Void)? = nil) {
        if darkened {
            addDarkeningView(animated: animated, duration: duration, completion: completion)
        } else {
            removeDarkeningView(animated: animated, duration: duration, completion: completion)
        }
    }
    
    private func addDarkeningView(animated: Bool, duration: TimeInterval, completion: (() -> Void)?) {
        guard darkeningView == nil else { return }
        
        let darkView = UIView()
        darkView.backgroundColor = UIColor(white: 0, alpha: 0.5)
        darkView.frame = view.bounds
        darkView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(darkView)
        darkeningView = darkView
        
        if animated {
            darkView.alpha = 0
            UIView.animate(withDuration: duration, animations: {
                darkView.alpha = 1
            }, completion: { _ in
                completion?()
            })
        } else {
            darkView.alpha = 1
            completion?()
        }
    }
    
    private func removeDarkeningView(animated: Bool, duration: TimeInterval, completion: (() -> Void)?) {
        guard let darkView = darkeningView else {
            completion?()
            return
        }
        
        let removeView = {
            darkView.removeFromSuperview()
            self.darkeningView = nil
            completion?()
        }
        
        if animated {
            UIView.animate(withDuration: duration, animations: {
                darkView.alpha = 0
            }, completion: { _ in
                removeView()
            })
        } else {
            removeView()
        }
    }
}

extension UINavigationController {
    func pushOverRootVC(vc: UIViewController, animated: Bool = true) {
        var viewControllers = self.viewControllers
        
        if viewControllers.count == 1 {
            self.pushViewController(vc, animated: animated)
            return
        }
        
        viewControllers.removeLast()
        viewControllers.append(vc)
        self.setViewControllers(viewControllers, animated: animated)
    }
}
