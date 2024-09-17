import UIKit
import CoreData


extension DashboardRootViewController: FeedSearchResultsViewControllerDelegate {
    func didChangeFilterChipVisibility(isVisible:Bool?){
        configureAddTribeBehavior(oldTab: .feed, visibilityOverride: isVisible,oldFeedSource: feedSource)
    }
    
    func getFeedSource()->FeedSource{
        return self.feedSource
    }
    
    func getBottomBarHeight() -> CGFloat{
        return self.bottomBar.frame.height
    }
    
    func getPodcastSmallPlayerHeight() -> CGFloat{
        return podcastSmallPlayer.getViewHeight()
    }
    
    func showNoResults() {
        self.feedSearchResultsContainerViewController.view.isHidden = true
        self.feedsContainerViewController.showEmptyStateViewController()
        self.feedsContainerViewController.emptyStateViewController.updateEmptyStateLabel()
    }
}
