//
//  NewChatTableDataSource+PreloaderExtension.swift
//  sphinx
//
//  Created by Tomas Timinskas on 12/06/2023.
//  Copyright © 2023 sphinx. All rights reserved.
//

import Foundation

extension NewChatTableDataSource {
    @objc func restorePreloadedMessages() {
        guard let chat = chat else {
            return
        }
        
        if let messagesStateArray = preloaderHelper.getMessageStateArray(for: chat.id) {
            messageTableCellStateArray = messagesStateArray
            updateSnapshot()
        }
    }
    
    @objc func saveMessagesToPreloader() {
        guard let chat = chat else {
            return
        }
        
        if let firstVisibleRow = tableView.indexPathsForVisibleRows?.last {
            preloaderHelper.add(
                messageStateArray: messageTableCellStateArray.subarray(size: firstVisibleRow.row + 10),
                for: chat.id
            )
        }
    }
    
    @objc func saveSnapshotCurrentState() {
        // Do not overwrite a saved state that hasn't been consumed yet
        guard !isRestoringScrollPosition else { return }
        guard let chatId = chat?.id else { return }
        
        // In the inverted UITableView, .last = highest index = topmost visible row on screen
        guard var topIndexPath = tableView.indexPathsForVisibleRows?.last else { return }
        
        // Skip date-separator rows (message == nil); walk toward lower index (newer, but still visible)
        while topIndexPath.row >= 0 {
            let state = messageTableCellStateArray[topIndexPath.row]
            if let messageId = state.message?.id {
                // Found a real message row — compute pixel offset
                let isAtBottom = tableView.contentOffset.y <= Constants.kChatTableContentInset
                if isAtBottom {
                    preloaderHelper.save(firstRowId: messageId, difference: 0, isAtBottom: true, for: chatId)
                } else {
                    let cellRect = tableView.rectForRow(at: topIndexPath)
                    let cellRectInView = tableView.convert(cellRect, to: tableView)
                    let visibleTop = tableView.contentOffset.y + tableView.contentInset.top
                    let difference = cellRectInView.origin.y - visibleTop
                    preloaderHelper.save(firstRowId: messageId, difference: difference, isAtBottom: false, for: chatId)
                }
                return
            }
            if topIndexPath.row == 0 { break }
            topIndexPath = IndexPath(row: topIndexPath.row - 1, section: topIndexPath.section)
        }
    }
    
    @objc func restoreScrollLastPosition() {
        guard let chatId = chat?.id else { return }
        tableView.alpha = 1.0
        
        if let pinnedMessageId = pinnedMessageId {
            if let index = getTableCellStateFor(messageId: pinnedMessageId, and: nil)?.0 {
                tableView.scrollToRow(at: IndexPath(row: index, section: 0), at: .top, animated: true)
            }
            isRestoringScrollPosition = false
            return
        }
        
        if let scrollState = preloaderHelper.getScrollState(for: chatId, pinnedMessageId: nil),
           !scrollState.isAtBottom {
            // Find the row whose message.id matches the saved anchor
            if let index = messageTableCellStateArray.firstIndex(where: { $0.message?.id == scrollState.firstRowId }) {
                let rowCount = tableView.numberOfRows(inSection: 0)
                guard index < rowCount else {
                    isRestoringScrollPosition = false
                    delegate?.didScrollToBottom()
                    return
                }
                tableView.scrollToRow(at: IndexPath(row: index, section: 0), at: .top, animated: false)
                // Apply saved pixel offset from viewport top
                tableView.contentOffset.y = tableView.contentOffset.y - scrollState.difference
                isRestoringScrollPosition = false
                return
            }
        }
        
        // Fallback: scroll to bottom (most recent messages)
        isRestoringScrollPosition = false
        if tableView.contentOffset.y <= Constants.kChatTableContentInset {
            delegate?.didScrollToBottom()
        }
    }
}

