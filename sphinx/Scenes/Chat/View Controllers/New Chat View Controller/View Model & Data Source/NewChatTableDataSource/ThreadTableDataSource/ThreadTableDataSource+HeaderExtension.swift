//
//  ThreadTableDataSource+HeaderExtension.swift
//  sphinx
//
//  Created by Tomas Timinskas on 03/08/2023.
//  Copyright © 2023 sphinx. All rights reserved.
//

import UIKit

extension ThreadTableDataSource : ThreadHeaderTableViewCellDelegate {    
    func shouldExpandHeaderMessage() {
        guard isHeaderExpanded == false else {
            return
        }
        isHeaderExpanded = true
        reloadHeaderRow()
        tableView.scrollToBottom(animated: false)
    }
    
    func shouldCollapseHeaderMessage() {
        guard isHeaderExpanded == true else {
            return
        }
        isHeaderExpanded = false
        reloadHeaderRow()
    }
    
    func reloadHeaderRow() {
        var snapshot = dataSource.snapshot()
        guard let headerItem = snapshot.itemIdentifiers.first(where: { $0.isThreadHeaderMessage }) else {
            return
        }
        snapshot.reloadItems([headerItem])
        dataSource.apply(snapshot, animatingDifferences: false)
    }
}
