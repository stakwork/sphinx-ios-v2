//
//  BitTorrentSearchTableViewDataSource.swift
//  sphinx
//
//  Created by James Carucci on 7/11/24.
//  Copyright © 2024 sphinx. All rights reserved.
//

import Foundation
import UIKit


class BitTorrentSearchTableViewDataSource : NSObject, UITableViewDataSource, UITableViewDelegate {
    var btSearchResults = [BTFeedSearchDataMapper]()
    var linkedTableView : UITableView? = nil
    var getMagnetDetailsCallback: ((String, MagnetDetailsResponse?) -> Void)?
    
    override init() {
        super.init()
    }
    
    func searchBitTorrent(){
        SphinxOnionManager.sharedInstance.authorizeBT(callback: {success in
            if(success){
                SphinxOnionManager.sharedInstance.searchAllTorrents(
                keyword: "the matrix",
                callback: { [self] results in
                    self.btSearchResults = results
                    linkedTableView?.reloadData()
                })
            }
        })
    }
    
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return btSearchResults.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "BTSearchResultTableViewCell", for: indexPath) as? BTSearchResultTableViewCell else {
            fatalError("Unexpected cell type")
        }
        
        let result = btSearchResults[indexPath.row]
        cell.configure(withTitle: result.name ?? "", seeders: result.seeders ?? 0)
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let result = btSearchResults[indexPath.row]
        if let magnetLink = result.magnet_link {
            SphinxOnionManager.sharedInstance.getMagnetDetails(
                data: result,
                callback: { detailsResponse in
                    if let responseCallback = self.getMagnetDetailsCallback {
                        responseCallback(magnetLink, detailsResponse)
                    }
                })
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 80.0
    }
    
}

