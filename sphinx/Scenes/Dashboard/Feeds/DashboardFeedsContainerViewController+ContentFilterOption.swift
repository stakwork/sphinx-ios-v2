import Foundation


extension DashboardFeedsContainerViewController {
    struct ContentFilterOption {
        let id = UUID()
        
        var titleForDisplay: String
        var isActive: Bool = false
        var displayOrder: Int
        
        
        mutating func setActiveState(to newValue: Bool) {
            isActive = newValue
        }
        
        
        static var allContent: Self = .init(
            titleForDisplay: "dashboard.feeds.filters.all".localized,
            displayOrder: 1
        )
        
        static var browse: Self = .init(
            titleForDisplay: "dashboard.feeds.filters.browse".localized,
            displayOrder: 2
        )
        
        static var discover: Self = .init(
            titleForDisplay: "dashboard.feeds.filters.discover".localized,
            displayOrder: 3
        )
        
        static var listen: Self = .init(
            titleForDisplay: "dashboard.feeds.filters.listen".localized,
            displayOrder: 4
        )
        static var watch: Self = .init(
            titleForDisplay: "dashboard.feeds.filters.watch".localized,
            displayOrder: 5
        )
        static var read: Self = .init(
            titleForDisplay: "dashboard.feeds.filters.read".localized,
            displayOrder: 6
        )
        static var play: Self = .init(
            titleForDisplay: "dashboard.feeds.filters.play".localized,
            displayOrder: 7
        )
    }
}


extension DashboardFeedsContainerViewController.ContentFilterOption: CaseIterable {
    static var allCases: [Self] {
        [
            //.allContent,
            .browse,
            .discover,
            .listen,
            .watch,
            .read,
            .play
        ]
    }
}


extension DashboardFeedsContainerViewController.ContentFilterOption: Hashable {}

extension DashboardFeedsContainerViewController.ContentFilterOption: Identifiable {}
