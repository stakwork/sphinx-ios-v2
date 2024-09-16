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
        guard let tableCellState = messageTableCellStateArray.last else {
            return
        }
        
        dataSourceQueue.async {
            var snapshot = self.dataSource.snapshot()
            
            if snapshot.itemIdentifiers.contains(tableCellState) {
                snapshot.reloadItems([tableCellState])
                
                DispatchQueue.main.async {
                    self.dataSource.apply(snapshot, animatingDifferences: false)
                }
            }
        }
    }
}
