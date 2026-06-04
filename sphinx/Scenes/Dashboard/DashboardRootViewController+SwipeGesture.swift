//
//  DashboardRootViewController+SwipeGesture.swift
//  sphinx
//

import UIKit

extension DashboardRootViewController {

    func setupSwipeGestures() {
        let swipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeLeft))
        swipeLeft.direction = .left
        swipeLeft.cancelsTouchesInView = false
        mainContentContainerView.addGestureRecognizer(swipeLeft)

        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeRight))
        swipeRight.direction = .right
        swipeRight.cancelsTouchesInView = false
        mainContentContainerView.addGestureRecognizer(swipeRight)
    }

    @objc func handleSwipeLeft() {
        let nextIndex = min(activeTab.rawValue + 1, DashboardTab.workspaces.rawValue)
        dashboardNavigationTabs.selectTabWith(index: nextIndex)
    }

    @objc func handleSwipeRight() {
        let prevIndex = max(activeTab.rawValue - 1, DashboardTab.feed.rawValue)
        dashboardNavigationTabs.selectTabWith(index: prevIndex)
    }
}
