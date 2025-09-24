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
        let scrolledToTop = tableView.contentOffset.y > tableView.contentSize.height - tableView.frame.size.height - difference - 5000
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
        if isSearching {
            return
        }
        
        if loadingMoreItems {
            return
        }
        
        loadingMoreItems = true
        
        fetchMoreItems()
    }
    
    @objc func loadMoreItems() {
        configureResultsController(items: messagesCountRequested + 50)
    }
    
    func fetchMoreItems() {
        if isThread {
            return
        }
        if let publicKey = contact?.publicKey ?? chat?.ownerPubkey {
            if let chat = chat {
                let backgroundContext = CoreDataManager.sharedManager.getBackgroundContext()
                var minIndex: Int? = nil
                let itemsPerPage = 100
                
                backgroundContext.perform {
                    minIndex = TransactionMessage.getMinMessageIndex(for: chat, context: backgroundContext)
                    
                    if let minIndex = minIndex {
                        if (minIndex - 1) <= 0 {
                            return
                        }
                        DispatchQueue.global(qos: .background).async {
                            SphinxOnionManager.sharedInstance.startChatMsgBlockFetch(
                                startIndex: minIndex - 1,
                                itemsPerPage: itemsPerPage,
                                stopIndex: 0,
                                publicKey: publicKey
                            ) { messagesCount in
                                self.loadMoreItems()
                                
                                if messagesCount <= 0 {
                                    self.processMessages(
                                        messages: self.messagesArray,
                                        showLoadingMore: false
                                    )
                                    
                                    if self.isSearching {
                                        self.delegate?.shouldToggleSearchLoadingWheel(active: false)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    @objc func shouldHideNewMsgsIndicator() -> Bool {
        return tableView.contentOffset.y < -10 || tableView.alpha == 0
    }
}
