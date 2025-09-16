//
//  NewChatTableDataSource+ScrollExtension.swift
//  sphinx
//
//  Created by Tomas Timinskas on 13/06/2023.
//  Copyright © 2023 sphinx. All rights reserved.
//

import UIKit

extension NewChatTableDataSource: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if messageTableCellStateArray.count > indexPath.row {
            let mutableTableCellStateArray = messageTableCellStateArray[indexPath.row]
            
            if let message = mutableTableCellStateArray.message, mutableTableCellStateArray.isThread {
                delegate?.shouldShowThreadFor(message: message)
            }
        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if tableView.contentSize.height <= 0 {
            return
        }
        
        let difference: CGFloat = 16
        let scrolledToTop = tableView.contentOffset.y > tableView.contentSize.height - tableView.frame.size.height - difference - 1500
        let scrolledToBottom = tableView.contentOffset.y < -10
        let didMoveOutOfBottom = tableView.contentOffset.y > -10
                
        if scrolledToTop {
            didScrollToTop()
        } else if scrolledToBottom {
            didScrollToBottom()
        }
        
        if didMoveOutOfBottom {
            didMoveOutOfBottomArea()
        }
    }
    
    func scrollViewShouldScrollToTop(_ scrollView: UIScrollView) -> Bool {
        return false
    }
    
    @objc func didMoveOutOfBottomArea() {
        scrolledAtBottom = false
        
        delegate?.didScrollOutOfBottomArea()
    }
    
    @objc func didScrollToBottom() {
        if scrolledAtBottom {
            return
        }
        
        scrolledAtBottom = true
        
        delegate?.didScrollToBottom()
    }
    
    @objc func didScrollToTop() {
        if loadingMoreItems {
            return
        }
        
        loadingMoreItems = true
        
        loadMoreItems()
    }
    
    @objc func loadMoreItems() {
        configureResultsController(items: messagesCount + 50)
    }
    
    func fetchMoreItems() {
//        if messagesArray.count >= chatMessagesTotalCount {
//            if let publicKey = contact?.publicKey ?? chat?.ownerPubkey {
//                if let minIndex = self.minIndex {
//                    SphinxOnionManager.sharedInstance.startChatMsgBlockFetch(
//                        startIndex: minIndex - 1,
//                        itemsPerPage: 50,
//                        stopIndex: 0,
//                        publicKey: publicKey
//                    )
//                }
//            }
//        }
    }
    
    @objc func shouldHideNewMsgsIndicator() -> Bool {
        return tableView.contentOffset.y < -10 || tableView.alpha == 0
    }
}
