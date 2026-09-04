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
        }
        if scrolledToBottom {
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

        guard pagination.beginUserLoad(isThread: isThread, hasChat: chat != nil) else {
            return
        }

        fetchMoreItems()
    }
    
    func loadMoreItems(itemsCount: Int) {
        configureResultsController(
            items: messagesCountRequested + itemsCount,
            expandingForPagination: true
        )
    }
    
    @objc func loadMoreItems() {
        loadMoreItems(itemsCount: 50)
    }
    
    func fetchMoreItems() {
        if isThread {
            pagination.failToStart(reason: "thread")
            return
        }

        guard chat != nil else {
            pagination.failToStart(reason: "no chat")
            return
        }

        guard let publicKey = contact?.publicKey ?? chat?.ownerPubkey else {
            pagination.failToStart(reason: "no pubkey")
            return
        }

        guard SphinxOnionManager.sharedInstance.getAccountSeed() != nil else {
            pagination.failToStart(reason: "nil seed")
            return
        }

        guard let chat = chat else {
            pagination.failToStart(reason: "no chat")
            return
        }

        let backgroundContext = CoreDataManager.sharedManager.getBackgroundContext()
        var minIndex: Int? = nil
        let itemsPerPage = 100

        backgroundContext.perform {
            minIndex = TransactionMessage.getMinMessageIndex(for: chat, context: backgroundContext)

            if let minIndex = minIndex {
                if (minIndex - 1) <= 0 {
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        self.finishPaginationPage(messagesCount: 0, itemsPerPage: itemsPerPage, alreadyAtOldest: true)
                    }
                    return
                }
                SphinxOnionManager.sharedInstance.startChatMsgBlockFetch(
                    startIndex: minIndex - 1,
                    itemsPerPage: itemsPerPage,
                    stopIndex: 0,
                    publicKey: publicKey
                ) { messagesCount in
                    Task { @MainActor [weak self] in
                        guard let self = self else { return }
                        // Fetched messages arrive as unconfirmed — check their send status now
                        // rather than waiting for the next didChangeContentWith cycle.
                        SphinxOnionManager.sharedInstance.getMessagesStatusForPendingMessages()
                        self.finishPaginationPage(
                            messagesCount: messagesCount,
                            itemsPerPage: itemsPerPage,
                            alreadyAtOldest: false
                        )
                    }
                }
            } else {
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.finishPaginationPage(messagesCount: 0, itemsPerPage: itemsPerPage, alreadyAtOldest: true)
                }
            }
        }
    }
    
    func finishPaginationPage(
        messagesCount: Int,
        itemsPerPage: Int,
        alreadyAtOldest: Bool
    ) {
        if alreadyAtOldest {
            pagination.completeAlreadyAtOldest()
        } else {
            print("pagination network messagesCount=\(messagesCount) page=\(itemsPerPage)")
            pagination.completeNetworkPage(
                messagesCount: messagesCount,
                itemsPerPage: itemsPerPage
            )
        }

        loadMoreItems(itemsCount: messagesCount)

        if isSearching {
            delegate?.shouldToggleSearchLoadingWheel(active: false)
        }
    }

    @objc func shouldHideNewMsgsIndicator() -> Bool {
        return tableView.contentOffset.y < -10 || tableView.alpha == 0
    }
}
