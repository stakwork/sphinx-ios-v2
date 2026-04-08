//
//  MessagesPreloaderHelper.swift
//  sphinx
//
//  Created by Tomas Timinskas on 07/06/2023.
//  Copyright © 2023 sphinx. All rights reserved.
//

import Foundation
import CoreGraphics

@MainActor class MessagesPreloaderHelper {

    nonisolated(unsafe) class var sharedInstance : MessagesPreloaderHelper {
        struct Static {
            nonisolated(unsafe) static let instance = MessagesPreloaderHelper()
        }
        return Static.instance
    }
    
    struct ScrollState {
        var firstRowId: Int      // message.id of the topmost visible row
        var difference: CGFloat  // pixel offset of that row from the top of the viewport
        var isAtBottom: Bool
    }
    
    var chatMessages: [Int: [MessageTableCellState]] = [:]
    var chatScrollState: [Int: ScrollState] = [:]
    
    var tribesData: [String: MessageTableCellState.TribeData] = [:]
    var linksData: [String: MessageTableCellState.LinkData] = [:]
    
    func add(
        messageStateArray: [MessageTableCellState],
        for chatId: Int
    ) {
        self.chatMessages[chatId] = messageStateArray
    }
    
    func getPreloadedMessagesCount(for chatId: Int) -> Int {
        return chatMessages[chatId]?.count ?? 0
    }
    
    func getMessageStateArray(for chatId: Int) -> [MessageTableCellState]? {
        if let messageStateArray = chatMessages[chatId], messageStateArray.count > 0 {
            return messageStateArray
        }
        return nil
    }
    
    func save(firstRowId: Int, difference: CGFloat, isAtBottom: Bool, for chatId: Int) {
        chatScrollState[chatId] = ScrollState(firstRowId: firstRowId, difference: difference, isAtBottom: isAtBottom)
    }
    
    func getScrollState(for chatId: Int, pinnedMessageId: Int? = nil) -> ScrollState? {
        if let pinnedMessageId = pinnedMessageId {
            return ScrollState(firstRowId: pinnedMessageId, difference: 0, isAtBottom: false)
        }
        return chatScrollState[chatId]
    }
    
    func reset(for chatId: Int) {
        chatScrollState.removeValue(forKey: chatId)
    }
}
