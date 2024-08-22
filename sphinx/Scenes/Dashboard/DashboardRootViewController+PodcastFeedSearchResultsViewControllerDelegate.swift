import UIKit
import CoreData


extension DashboardRootViewController: FeedSearchResultsViewControllerDelegate {
    func didChangeFilterChipVisibility(isVisible:Bool?){
        configureAddTribeBehavior(oldTab: .feed, visibilityOverride: isVisible,oldFeedSource: feedSource)
    }
}
