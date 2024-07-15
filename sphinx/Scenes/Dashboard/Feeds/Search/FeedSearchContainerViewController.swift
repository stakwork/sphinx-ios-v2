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
}


class FeedSearchContainerViewController: UIViewController {
    @IBOutlet weak var contentView: UIView!
    
    private var managedObjectContext: NSManagedObjectContext!
    private weak var resultsDelegate: FeedSearchResultsViewControllerDelegate?
    
    var feedType: FeedType? = nil
    var searchTimer: Timer? = nil
    
    internal let newMessageBubbleHelper = NewMessageBubbleHelper()
    internal let feedsManager = FeedsManager.sharedInstance
    
    lazy var fetchedResultsController: NSFetchedResultsController = Self
        .makeFetchedResultsController(
            using: managedObjectContext,
            and: ContentFeed.FetchRequests.followedFeeds()
        )
    
    
    internal lazy var searchResultsViewController: FeedSearchResultsCollectionViewController = {
        FeedSearchResultsCollectionViewController
            .instantiate(
                onSubscribedFeedCellSelected: handleFeedCellSelection,
                onFeedSearchResultCellSelected: handleSearchResultCellSelection
            )
    }()
    
    
    internal lazy var emptyStateViewController: FeedSearchEmptyStateViewController = {
        FeedSearchEmptyStateViewController.instantiate()
    }()
    
    internal lazy var bitTorrentSearchViewController: BitTorrentSearchViewController = {
        let vc = BitTorrentSearchViewController.instantiate()
        return vc
    }()
    
    private var isShowingStartingEmptyStateVC: Bool = true
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
    }
}


// MARK: - Public Methods
extension FeedSearchContainerViewController {
    
    func updateSearchQuery(
        with searchQuery: String,
        and type: FeedType?
    ) {
        if searchQuery.isEmpty {
            presentInitialStateView()
        } else {
            fetchResults(for: searchQuery, and: type)
        }
    }
    
    
    private func presentResultsListView() {
        isShowingStartingEmptyStateVC = false
        removeChildVC(child: bitTorrentSearchViewController)
        removeChildVC(child: emptyStateViewController)
        
        addChildVC(
            child: searchResultsViewController,
            container: contentView
        )
    }
    
    
    func presentInitialStateView() {
        isShowingStartingEmptyStateVC = true
        
        removeChildVC(child: searchResultsViewController)
        removeChildVC(child: bitTorrentSearchViewController)
        
        bitTorrentSearchViewController.clearResults()  // Clear BitTorrent search results
        
        emptyStateViewController.feedType = feedType
        
        addChildVC(
            child: emptyStateViewController,
            container: contentView
        )
    }
}


// MARK: -  Private Helpers
extension FeedSearchContainerViewController {
    
    private func fetchResults(
        for searchQuery: String,
        and type: FeedType?
    ) {
        if type == nil {
            // "All" tab is selected, show BitTorrent search
            presentBitTorrentSearchView()
            performBitTorrentSearch(searchQuery: searchQuery)
        } else {
            // Existing logic for other feed types
            presentResultsListView()  // Make sure to show the regular search results view
            
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
            
            searchResultsViewController.updateWithNew(searchResults: [])
            
            searchTimer?.invalidate()
            searchTimer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(fetchRemoteResults(timer:)), userInfo: ["search_query": searchQuery, "feed_type" : type], repeats: false)
        }
        
        ActionsManager.sharedInstance.trackFeedSearch(searchTerm: searchQuery.lowerClean)
    }
    
    private func presentBitTorrentSearchView() {
        removeChildVC(child: searchResultsViewController)
        removeChildVC(child: emptyStateViewController)
        
        addChildVC(
            child: bitTorrentSearchViewController,
            container: contentView
        )
    }

    private func performBitTorrentSearch(searchQuery: String) {
        bitTorrentSearchViewController.bitTorrentSearchTableViewDataSource?.searchBitTorrent(keyword: searchQuery)
    }
    
    @objc func fetchRemoteResults(timer: Timer) {
        if let userInfo = timer.userInfo as? [String: Any] {
            if let searchQuery = userInfo["search_query"] as? String, 
                let type = userInfo["feed_type"] as? FeedType {
                API.sharedInstance.searchBTFeed(
                    matching: searchQuery,
                    type: type
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
        }
    }
    
    
    private func configureStartingEmptyStateView() {
        emptyStateViewController.feedType = feedType
        
        addChildVC(
            child: emptyStateViewController,
            container: contentView
        )
    }
    
    
    private func handleFeedCellSelection(_ feedSearchResult: FeedSearchResult) {
        resultsDelegate?.viewController(
            self,
            didSelectFeedSearchResult: feedSearchResult.feedId
        )
    }
    
    private func handleSearchResultCellSelection(
        _ searchResult: FeedSearchResult
    ) {
        if let vc = self.resultsDelegate as? DashboardRootViewController{
            vc.presentBitTorrentPlayer(for: searchResult)
        }
        
//        let existingFeedsFetchRequest: NSFetchRequest<ContentFeed> = ContentFeed
//            .FetchRequests
//            .matching(feedID: searchResult.feedId)
//
//        var fetchRequestResult: [ContentFeed] = []
//
//        managedObjectContext.performAndWait {
//            fetchRequestResult = try! managedObjectContext.fetch(existingFeedsFetchRequest)
//        }
//
//        if let existingFeed = fetchRequestResult.first {
//            resultsDelegate?.viewController(
//                self,
//                didSelectFeedSearchResult: existingFeed.feedID
//            )
//        } else {
//            self.newMessageBubbleHelper.showLoadingWheel()
//
//            ContentFeed.fetchContentFeed(
//                at: searchResult.feedURLPath,
//                chat: nil,
//                searchResultDescription: searchResult.feedDescription,
//                searchResultImageUrl: searchResult.imageUrl,
//                persistingIn: managedObjectContext,
//                then: { result in
//
//                    if case .success(_) = result {
//                        self.managedObjectContext.saveContext()
//
//                        self.feedsManager.loadCurrentEpisodeDurationFor(feedId: searchResult.feedId, completion: {
//                            self.newMessageBubbleHelper.hideLoadingWheel()
//
//                            self.resultsDelegate?.viewController(
//                                self,
//                                didSelectFeedSearchResult: searchResult.feedId
//                            )
//                        })
//                    } else {
//                        self.newMessageBubbleHelper.hideLoadingWheel()
//
//                        AlertHelper.showAlert(title: "generic.error.title".localized, message: "generic.error.message".localized)
//                    }
//            })
//        }
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
