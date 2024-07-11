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
    
    override func viewDidLoad() {
        self.view.backgroundColor = . magenta
        bitTorrentSearchTableView.dataSource = self
        bitTorrentSearchTableView.delegate = self
    }
    
    static func instantiate(
//        managedObjectContext: NSManagedObjectContext = CoreDataManager.sharedManager.persistentContainer.viewContext,
//        interSectionSpacing: CGFloat = 10.0,
//        onCellSelected: ((String) -> Void)!,
//        onDownloadedItemSelected: ((String, String) -> Void)!,
//        onRecommendationSelected: (([RecommendationResult], String) -> Void)!,
//        onNewResultsFetched: @escaping ((Int) -> Void) = { _ in },
//        onContentScrolled: ((UIScrollView) -> Void)? = nil
    ) -> BitTorrentSearchViewController {
        
        let viewController = StoryboardScene
            .Dashboard
            .bitTorrentSearchViewController
            .instantiate()

//        viewController.managedObjectContext = managedObjectContext

//        viewController.interSectionSpacing = interSectionSpacing
//        viewController.onCellSelected = onCellSelected
//        viewController.onDownloadedItemSelected = onDownloadedItemSelected
//        viewController.onRecommendationSelected = onRecommendationSelected
//        viewController.onNewResultsFetched = onNewResultsFetched
//        viewController.onContentScrolled = onContentScrolled
//        
//        viewController.fetchedResultsController = Self.makeFetchedResultsController(using: managedObjectContext)
//        viewController.fetchedResultsController.delegate = viewController
//        
        return viewController
    }
    
}


extension BitTorrentSearchViewController : UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        return 5
    }
    
//    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
//        if let cell = cell as? MemberBadgeHeaderCell {
//            if let personInfo = personInfo {
//                cell.configureHeaderView(
//                    presentingVC: vc,
//                    personInfo: personInfo,
//                    message: message,
//                    isModerator: isModerator
//                )
//            }
//        } else if let cell = cell as? BadgeDetailCell {
//            cell.configCell(
//                badge: badges[indexPath.row - badgeDetailOffset]
//            )
//        } else if let cell = cell as? MemberDetailTableViewCell {
//            cell.configureCell(
//                type: getCellTypeOrder()[indexPath.row],
//                badges: badges,
//                leaderboardData: leaderBoardData,
//                isExpanded: badgeDetailExpansionState
//            )
//        }
//    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell()
        cell.backgroundColor = .green
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        print("didSelectRowAt")
    }
}
