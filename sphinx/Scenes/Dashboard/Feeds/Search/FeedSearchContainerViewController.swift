// FeedSearchContainerViewController.swift
//
// Created by CypherPoet.
// ✌️
//


import UIKit
import CoreData


protocol FeedSearchResultsViewControllerDelegate: AnyObject {
    
    func viewController(
        _ viewController: UIViewController,
        didSelectFeedSearchResult feedId: String
    )
    
    func didChangeFilterChipVisibility(isVisible:Bool?)
    func getFeedSource()->FeedSource
    func updateIsSearchingTorrents(isSearching:Bool)
}


class FeedSearchContainerViewController: UIViewController, FeedSearchResultsCollectionViewControllerDelegate {
    @IBOutlet weak var contentView: UIView!
    
    private var managedObjectContext: NSManagedObjectContext!
    private weak var resultsDelegate: FeedSearchResultsViewControllerDelegate?
    
    var feedType: FeedType? = nil
    var searchTimer: Timer? = nil
    var didPressEnter : Bool = false
    var prePopulateDebounce : Bool = false
    var stashedDetailsResponse:MagnetDetailsResponse? = nil
    var stashedMagnetLink:String?=nil
    
    internal let newMessageBubbleHelper = NewMessageBubbleHelper()
    internal let feedsManager = FeedsManager.sharedInstance
        
    func getFeedSource()->FeedSource{
        return self.resultsDelegate?.getFeedSource() ?? .RSS
    }
    
    lazy var fetchedResultsController: NSFetchedResultsController = Self
        .makeFetchedResultsController(
            using: managedObjectContext,
            and: ContentFeed.FetchRequests.followedFeeds()
        )
    
    
    internal lazy var searchResultsViewController: FeedSearchResultsCollectionViewController = {
            .instantiate(
                onSubscribedFeedCellSelected: handleFeedCellSelection,
                onFeedSearchResultCellSelected: handleSearchResultCellSelection,
                delegate: self
            )
    }()
    
    
    internal lazy var emptyStateViewController: FeedSearchEmptyStateViewController = {
        FeedSearchEmptyStateViewController.instantiate()
    }()
    
    
    private var isShowingStartingEmptyStateVC: Bool = true
    
    func prePopulateSearch(feedSource:FeedSource){
        searchResultsViewController.updateWithNew(searchResults: [])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
            if(self.feedType != .SearchTorrent && self.prePopulateDebounce == false){
                self.fetchResults(for: "", and: self.feedType ?? .BrowseTorrent, feedSource: self.getFeedSource())
                self.prePopulateDebounce = true
                DelayPerformedHelper.performAfterDelay(seconds: 2.0, completion: {self.prePopulateDebounce = false})
            }
        })
        resultsDelegate?.updateIsSearchingTorrents(isSearching: false)
    }
}



// MARK: -  Static Properties
extension FeedSearchContainerViewController {
    
    static func instantiate(
        managedObjectContext: NSManagedObjectContext = CoreDataManager.sharedManager.persistentContainer.viewContext,
        resultsDelegate: FeedSearchResultsViewControllerDelegate
    ) -> FeedSearchContainerViewController {
        let viewController = StoryboardScene
            .Dashboard
            .FeedSearchContainerViewController
            .instantiate()
        
        viewController.managedObjectContext = managedObjectContext
        viewController.resultsDelegate = resultsDelegate
        viewController.fetchedResultsController.delegate = viewController
        
        return viewController
    }
    
    static func makeFetchedResultsController(
        using managedObjectContext: NSManagedObjectContext,
        and fetchRequest: NSFetchRequest<ContentFeed>
    ) -> NSFetchedResultsController<ContentFeed> {
        NSFetchedResultsController(
            fetchRequest: fetchRequest,
            managedObjectContext: managedObjectContext,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
    }
}


// MARK: -  Lifecycle
extension FeedSearchContainerViewController {
    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        
        configureStartingEmptyStateView()
        
        resultsDelegate?.didChangeFilterChipVisibility(isVisible: true)
    }
}


// MARK: - Public Methods
extension FeedSearchContainerViewController {
    
    func updateSearchQuery(
        with searchQuery: String,
        and type: FeedType?,
        feedSource: FeedSource
    ) {
        if searchQuery.isEmpty {
            presentInitialStateView()
        } else {
            switch type {
            case .Video, .BrowseTorrent, .Podcast, .Newsletter, .SearchTorrent:
                fetchFeedTypeSpecificContent(for: searchQuery,type: type, feedSource: feedSource)
            default:
                // Handle other cases
                presentResultsListView()
                fetchResults(for: searchQuery, and: type,feedSource:feedSource)
                break
            }
        }
    }
    
    private func fetchFeedTypeSpecificContent(for searchQuery: String,type:FeedType?,feedSource:FeedSource) {
        presentResultsListView()
        fetchResults(for: searchQuery, and: type, feedSource: feedSource)
    }

    func presentInitialStateView() {
        isShowingStartingEmptyStateVC = true
        
        removeChildVC(child: searchResultsViewController)
        emptyStateViewController.feedType = feedType
        
        addChildVC(
            child: emptyStateViewController,
            container: contentView
        )
        
        resultsDelegate?.didChangeFilterChipVisibility(isVisible: nil)
    }
    
    
    private func presentResultsListView() {
        isShowingStartingEmptyStateVC = false
        removeChildVC(child: emptyStateViewController)
        
        addChildVC(
            child: searchResultsViewController,
            container: contentView
        )
    }
    
}


// MARK: -  Private Helpers
extension FeedSearchContainerViewController {
    
    private func fetchResults(
        for searchQuery: String,
        and type: FeedType?,
        feedSource:FeedSource
    ) {
            // Existing logic for other feed types
        presentResultsListView()  // Make sure to show the regular search results view
        
        let shouldDoLocalSearch = feedSource == .RSS
        if(shouldDoLocalSearch){
            var newFetchRequest: NSFetchRequest<ContentFeed> = ContentFeed.FetchRequests.matching(searchQuery: searchQuery)
            
            switch(type) {
            case .Podcast:
                newFetchRequest = PodcastFeed.FetchRequests.matching(searchQuery: searchQuery)
            case .Video:
                newFetchRequest = VideoFeed.FetchRequests.matching(searchQuery: searchQuery)
            default:
                break
            }
            
            fetchedResultsController.fetchRequest.sortDescriptors = newFetchRequest.sortDescriptors
            fetchedResultsController.fetchRequest.predicate = newFetchRequest.predicate
            
            do {
                try fetchedResultsController.performFetch()
            } catch {
                AlertHelper.showAlert(
                    title: "Data Loading Error",
                    message: "\(error)"
                )
            }
        }
        
        searchResultsViewController.updateWithNew(searchResults: [])
        let finalType :FeedType = type ?? .Video
        searchTimer?.invalidate()
        searchTimer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(fetchRemoteResults(timer:)), userInfo: ["search_query": searchQuery, "feed_type" : finalType, "feed_source": feedSource], repeats: false)
        
        ActionsManager.sharedInstance.trackFeedSearch(searchTerm: searchQuery.lowerClean)
    }
    
    @objc func fetchRemoteResults(timer: Timer) {
        if let userInfo = timer.userInfo as? [String: Any] {
            if let searchQuery = userInfo["search_query"] as? String, 
                let type = userInfo["feed_type"] as? FeedType,
                let feedSource = userInfo["feed_source"] as? FeedSource{
                if(feedSource == .RSS){
                    API.sharedInstance.searchForFeeds(
                        with: type,
                        matching: searchQuery
                    ) { [weak self] result in
                        guard let self = self else { return }
                        
                        DispatchQueue.main.async {
                            switch result {
                            case .success(let results):
                                
                                self.searchResultsViewController.updateWithNew(
                                    searchResults: results
                                )
                                
                            case .failure(_):
                                break
                            }
                        }
                    }
                }
                else if (feedSource == .BitTorrent){
                    API.sharedInstance.searchManagedBTInstance(
                        matching: searchQuery,
                        type: type
                    ) { [weak self] result in
                        guard let self = self else { return }
                        
                        DispatchQueue.main.async {
                            switch result {
                            case .success(let results):
                                
                                self.searchResultsViewController.updateWithNew(
                                    subscribedFeeds: results
                                )
                                
                            case .failure(_):
                                break
                            }
                        }
                    }
                    if(searchQuery != ""){
                        resultsDelegate?.updateIsSearchingTorrents(isSearching: true)
                        API.sharedInstance.searchAllTorrentsForContent(
                            keyword: searchQuery,
                            completionHandler: {[weak self] results in
                                self?.resultsDelegate?.updateIsSearchingTorrents(isSearching: false)
                                guard let self = self else { return }
                                DispatchQueue.main.async {
                                    self.searchResultsViewController.updateWithNew(searchResults: results)
                                }
                            })
                    }
                    
                }
            }
        }
    }
    
    
    private func configureStartingEmptyStateView() {
        emptyStateViewController.feedType = feedType
        emptyStateViewController.feedSource = self.resultsDelegate?.getFeedSource() ?? .RSS
        
        addChildVC(
            child: emptyStateViewController,
            container: contentView
        )
    }
    
    
    private func handleFeedCellSelection(_ feedSearchResult: FeedSearchResult) {
        if let feedSource = resultsDelegate?.getFeedSource(),
           feedSource == .BitTorrent,
           let vc = self.resultsDelegate as? DashboardRootViewController{
            vc.presentBitTorrentPlayer(for: feedSearchResult)
        }
        else{
            resultsDelegate?.viewController(
                self,
                didSelectFeedSearchResult: feedSearchResult.feedId
            )
        }
    }
    
    private func handleSearchResultCellSelection(
        _ searchResult: FeedSearchResult
    ) {
        guard let feedSource = resultsDelegate?.getFeedSource() else{
            return
        }
        if(feedSource == .RSS){
            let existingFeedsFetchRequest: NSFetchRequest<ContentFeed> = ContentFeed
                .FetchRequests
                .matching(feedID: searchResult.feedId)

            var fetchRequestResult: [ContentFeed] = []

            managedObjectContext.performAndWait {
                fetchRequestResult = try! managedObjectContext.fetch(existingFeedsFetchRequest)
            }

            if let existingFeed = fetchRequestResult.first {
                resultsDelegate?.viewController(
                    self,
                    didSelectFeedSearchResult: existingFeed.feedID
                )
            } else {
                self.newMessageBubbleHelper.showLoadingWheel()

                ContentFeed.fetchContentFeed(
                    at: searchResult.feedURLPath,
                    chat: nil,
                    searchResultDescription: searchResult.feedDescription,
                    searchResultImageUrl: searchResult.imageUrl,
                    persistingIn: managedObjectContext,
                    then: { result in

                        if case .success(_) = result {
                            self.managedObjectContext.saveContext()

                            self.feedsManager.loadCurrentEpisodeDurationFor(feedId: searchResult.feedId, completion: {
                                self.newMessageBubbleHelper.hideLoadingWheel()

                                self.resultsDelegate?.viewController(
                                    self,
                                    didSelectFeedSearchResult: searchResult.feedId
                                )
                            })
                        } else {
                            self.newMessageBubbleHelper.hideLoadingWheel()

                            AlertHelper.showAlert(title: "generic.error.title".localized, message: "generic.error.message".localized)
                        }
                })
            }
        }
        else if feedSource == .BitTorrent,
                let vc = self.resultsDelegate as? DashboardRootViewController,
                searchResult.feedURLPath.contains("magnet:"){
            vc.fetchMagnetDetails(magnet_link: searchResult.feedURLPath)
        }
        else{
            AlertHelper.showAlert(title: "generic.error.title".localized, message: "generic.error.message".localized)
        }
        
    }
    
    func clearResults(){
        searchResultsViewController.clearResults()
    }
}


extension FeedSearchContainerViewController: NSFetchedResultsControllerDelegate {
    
    /// Called when the contents of the fetched results controller change.
    ///
    /// If this method is implemented, no other delegate methods will be invoked.
    func controller(
        _ controller: NSFetchedResultsController<NSFetchRequestResult>,
        didChangeContentWith snapshot: NSDiffableDataSourceSnapshotReference
    ) {
        guard
            let resultController = controller as? NSFetchedResultsController<NSManagedObject>,
            let firstSection = resultController.sections?.first,
            let foundFeeds = firstSection.objects as? [ContentFeed]
        else {
            return
        }
        
        let subscribedFeeds: [FeedSearchResult] = foundFeeds
            .compactMap {
                return FeedSearchResult.convertFrom(contentFeed: $0)
            }.sorted {
                $0.title < $1.title
            }
        
        DispatchQueue.main.async { [weak self] in
            self?.searchResultsViewController.updateWithNew(
                subscribedFeeds: subscribedFeeds
            )
        }
    }
}
