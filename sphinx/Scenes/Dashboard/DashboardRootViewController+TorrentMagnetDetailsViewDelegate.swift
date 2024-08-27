//
//  DashboardRootViewController+newdg.swift
//  sphinx
//
//  Created by James Carucci on 8/27/24.
//  Copyright © 2024 sphinx. All rights reserved.
//

import Foundation
import UIKit

private var darkeningViewKey: UInt8 = 21

extension DashboardRootViewController:TorrentMagnetDetailsViewDelegate{
    
    func darkenBackground(){
        
    }
    
    func removeDarkenedBackground(){
        
    }
    
    func handleAddMagnetError(){
        AlertHelper.showAlert(title: "generic.error.title".localized, message: "generic.error.message".localized)
        torrentMagnetDetailsView.removeFromSuperview()
    }
    
    func handleAddMagnetSuccess(){
        AlertHelper.showAlert(title: "dashboard.feeds.content.download.torrent.started.title".localized, message: "dashboard.feeds.content.download.torrent.started.message".localized)
        removeMagnetDetailsView()
    }
    
    func didTapAddMagnet(){
        torrentMagnetDetailsView.isLoading = true
        guard let stashedMagnetLink = stashedMagnetLink,
              let stashedDetailsResponse = stashedDetailsResponse else{
            handleAddMagnetError()
            return
        }
        SphinxOnionManager.sharedInstance.downloadTorrentViaMagnet(
            magnetLink: stashedMagnetLink,
            magnetDetails: stashedDetailsResponse,
            completion: { success in
                success ? self.handleAddMagnetSuccess() : self.handleAddMagnetError()
            })
    }
    
    func didTapCancelMagnet(){
        removeMagnetDetailsView()
    }
    
    func removeMagnetDetailsView(){
        stashedMagnetLink = nil
        stashedDetailsResponse = nil
        toggleDarkening(darkened: false, animated: true)
        torrentMagnetDetailsView.removeFromSuperview()
    }
    
    private func setupTorrentMagnetDetailsView() {
        // Initialize the custom view
        torrentMagnetDetailsView = TorrentMagnetDetailsView()
        torrentMagnetDetailsView.delegate = self

        // Add it to the view hierarchy
        toggleDarkening(darkened: true, animated: true)
        view.addSubview(torrentMagnetDetailsView)

        // Disable autoresizing mask translation for use with Auto Layout
        torrentMagnetDetailsView.translatesAutoresizingMaskIntoConstraints = false

        // Set up constraints
        NSLayoutConstraint.activate([
            torrentMagnetDetailsView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            torrentMagnetDetailsView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            torrentMagnetDetailsView.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -40), // 20 points padding on each side
            torrentMagnetDetailsView.heightAnchor.constraint(equalToConstant: 480) // Adjust height as needed
        ])

        // Ensure the view is on top
        view.bringSubviewToFront(torrentMagnetDetailsView)
        torrentMagnetDetailsView.layer.zPosition = CGFloat.greatestFiniteMagnitude

        torrentMagnetDetailsView.showOrHideLabels(shouldHide: true)
    }
    
    func fetchMagnetDetails(magnet_link:String?){
        setupTorrentMagnetDetailsView()
        torrentMagnetDetailsView.isLoading = true
        guard let magnet_link = magnet_link else {return}
        SphinxOnionManager.sharedInstance.getMagnetDetails(
            magnet_link: magnet_link,
            callback: { detailsResponse in
                guard let detailsResponse = detailsResponse else {return}
                self.stashedMagnetLink = magnet_link
                self.stashedDetailsResponse = detailsResponse
                self.torrentMagnetDetailsView.isLoading = false
                self.torrentMagnetDetailsView.populateLabels(magnetLink: magnet_link, detailsResponse: detailsResponse)
            }
        )
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
