//
//  HiveChatMessage+Precompute.swift
//  sphinx
//
//  Created on 2026-04-10.
//  Copyright © 2025 sphinx. All rights reserved.
//

import Foundation

extension HiveChatMessage {

    /// Pre-computes segment parsing and column-width measurement for every message in the array.
    ///
    /// **Call this on a background queue** (`DispatchQueue.global(qos: .userInitiated)`) so that
    /// the expensive `MarkdownContentSplitter.split()` and `NSString.size(withAttributes:)` work
    /// never blocks the main thread / `cellForRowAt`.
    ///
    /// After this returns, each message's `cachedSegments` and `cachedColumnWidths` are populated,
    /// and `FeatureChatMessageCell.renderSegmentedContent` will use them directly instead of
    /// computing inline.
    static func precompute(_ messages: inout [HiveChatMessage]) {
        for i in messages.indices {
            let segments = MarkdownContentSplitter.split(messages[i].resolvedDisplayText)
            let tableWidths: [[CGFloat]] = segments.compactMap { segment in
                guard case .table(let h, let r) = segment else { return nil }
                return MarkdownTableView.calculateColumnWidths(headers: h, rows: r, totalColumns: h.count)
            }
            messages[i].cachedSegments = segments
            messages[i].cachedColumnWidths = tableWidths
        }
    }
}
