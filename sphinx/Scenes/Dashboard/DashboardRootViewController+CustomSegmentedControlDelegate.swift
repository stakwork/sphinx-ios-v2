// DashboardRootViewController+CustomSegmentedControlDelegate.swift
//
// Created by CypherPoet.
// ✌️
//

import UIKit


extension DashboardRootViewController: CustomSegmentedControlDelegate {
    
    func segmentedControlDidSwitch(
        to index: Int
    ) {
        let newTab = DashboardTab(rawValue: index)!
        let oldTab = activeTab
        let isLeavingOrEnteringFeed = (oldTab == .feed || newTab == .feed)
        
        if isLeavingOrEnteringFeed {
            resetSearchField()
        } else if let term = searchTextField.text, !term.isEmpty {
            applySearchTerm(term, for: newTab)
        }
        
        activeTab = newTab
    }
}
