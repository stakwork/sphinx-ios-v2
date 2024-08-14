//
//  ThreadMessageLayoutState.swift
//  sphinx
//
//  Created by Tomas Timinskas on 25/07/2023.
//  Copyright © 2023 sphinx. All rights reserved.
//

import UIKit

struct ThreadLayoutState {
    
    struct ThreadMessages {
        var orignalThreadMessage: ThreadOriginalMessage
        var threadPeople: [ThreadPeople]
        var threadPeopleCount: Int
        var repliesCount: Int
        var lastReplyTimestamp: String
        
        init(
            orignalThreadMessage: ThreadOriginalMessage,
            threadPeople: [ThreadPeople],
            threadPeopleCount: Int,
            repliesCount: Int,
            lastReplyTimestamp: String
        ) {
            self.orignalThreadMessage = orignalThreadMessage
            self.threadPeople = threadPeople
            self.threadPeopleCount = threadPeopleCount
            self.repliesCount = repliesCount
            self.lastReplyTimestamp = lastReplyTimestamp
        }
    }
    
    struct ThreadOriginalMessage {
        var text: String
        var linkMatches: [NSTextCheckingResult]
        var highlightedMatches: [NSTextCheckingResult]
        var boldMatches: [NSTextCheckingResult]
        var linkMarkdownMatches: [(NSTextCheckingResult, String, String, Bool)]
        var timestamp: String
        var senderInfo: (UIColor, String, String?)
        
        init(
            text: String,
            linkMatches: [NSTextCheckingResult],
            highlightedMatches: [NSTextCheckingResult],
            boldMatches: [NSTextCheckingResult],
            linkMarkdownMatches: [(NSTextCheckingResult, String, String, Bool)],
            timestamp: String,
            senderInfo: (UIColor, String, String?)
        ) {
            self.text = text
            self.linkMatches = linkMatches
            self.highlightedMatches = highlightedMatches
            self.boldMatches = boldMatches
            self.linkMarkdownMatches = linkMarkdownMatches
            self.timestamp = timestamp
            self.senderInfo = senderInfo
        }
        
        var hasNoMarkdown: Bool {
            return linkMatches.isEmpty && boldMatches.isEmpty && highlightedMatches.isEmpty && linkMarkdownMatches.isEmpty
        }
    }
    
    struct ThreadPeople {
        var senderIndo: (UIColor, String, String?)
        
        init(
            senderIndo: (UIColor, String, String?)
        ) {
            self.senderIndo = senderIndo
        }
    }
}
