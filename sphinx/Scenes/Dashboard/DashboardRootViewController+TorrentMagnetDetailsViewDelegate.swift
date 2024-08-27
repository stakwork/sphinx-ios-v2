//
//  DashboardRootViewController+newdg.swift
//  sphinx
//
//  Created by James Carucci on 8/27/24.
//  Copyright © 2024 sphinx. All rights reserved.
//

import Foundation
import UIKit

extension DashboardRootViewController:TorrentMagnetDetailsViewDelegate{
    
    func handleAddMagnetError(){
        AlertHelper.showAlert(title: "generic.error.title".localized, message: "generic.error.message".localized)
        removeMagnetDetailsView()
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
            torrentMagnetDetailsView.heightAnchor.constraint(equalToConstant: 420) // Adjust height as needed
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
}
