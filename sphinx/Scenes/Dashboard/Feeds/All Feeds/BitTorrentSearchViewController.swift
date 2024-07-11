//
//  BitTorrentSearchViewController.swift
//  sphinx
//
//  Created by James Carucci on 7/11/24.
//  Copyright © 2024 sphinx. All rights reserved.
//

import Foundation
import UIKit

class BitTorrentSearchViewController : UIViewController{
    
    
    @IBOutlet weak var bitTorrentSearchTableView: UITableView!
    var bitTorrentSearchTableViewDataSource: BitTorrentSearchTableViewDataSource? = nil
    
    
    override func viewDidLoad() {
        configureTableView()
    }
    
    static func instantiate() -> BitTorrentSearchViewController {
        
        let viewController = StoryboardScene
            .Dashboard
            .bitTorrentSearchViewController
            .instantiate()

        return viewController
    }
    
    func configureTableView(){
        bitTorrentSearchTableViewDataSource = BitTorrentSearchTableViewDataSource()
        
        bitTorrentSearchTableView.register(UINib(nibName: "BTSearchResultTableViewCell", bundle: nil), forCellReuseIdentifier: "BTSearchResultTableViewCell")
        bitTorrentSearchTableView.dataSource = bitTorrentSearchTableViewDataSource
        bitTorrentSearchTableView.delegate = bitTorrentSearchTableViewDataSource
        bitTorrentSearchTableViewDataSource?.linkedTableView = bitTorrentSearchTableView
        bitTorrentSearchTableViewDataSource?.searchBitTorrent()
        bitTorrentSearchTableViewDataSource?.getMagnetDetailsCallback = showMagnetDetails(details:)
    }
    
    func showMagnetDetails(details:MagnetDetailsResponse?){
        guard let magnetDetails = details else{
            AlertHelper.showAlert(title: "Unable to get magnet details", message: "")
            return
        }
        //TODO: invoke modal UI
        print(magnetDetails)
    }
    
}
