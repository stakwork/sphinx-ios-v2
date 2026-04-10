//
//  HiveChatMessage+Precompute.swift
//  sphinx
//
//  Created on 2026-04-10.
//  Copyright © 2025 sphinx. All rights reserved.
//

import Foundation
import UIKit

extension HiveChatMessage {

    /// Shared renderer used exclusively for background pre-rendering.
    /// Created once — `MarkdownRenderer` is a pure value transformer with no UIKit mutation.
    private static let backgroundRenderer: MarkdownRenderer = {
        var style = MarkdownStyle()
        style.baseFontSize = 15
        return MarkdownRenderer(style: style)
    }()

    /// Pre-computes segment parsing, column-width measurement, and markdown→AttributedString
    /// rendering for every message in the array.
    ///
    /// **Call this on a background queue** (`DispatchQueue.global(qos: .userInitiated)`) so that
    /// the expensive work never blocks the main thread / `cellForRowAt`.
    ///
    /// After this returns each message has:
    /// - `cachedSegments`     — split result (avoids re-parsing in cell)
    /// - `cachedColumnWidths` — per-table column widths (avoids Core Text measurement in cell)
    /// - `cachedRenderedText` — pre-rendered `NSAttributedString` per segment (avoids regex rendering in cell)
    static func precompute(_ messages: inout [HiveChatMessage]) {
        for i in messages.indices {
            let segments = MarkdownContentSplitter.split(messages[i].resolvedDisplayText)

            var tableWidths: [[CGFloat]] = []
            var renderedText: [NSAttributedString?] = []

            for segment in segments {
                switch segment {
                case .text(let txt):
                    // Pre-render markdown → NSAttributedString off the main thread.
                    // NSAttributedString construction (regex + font metrics) is thread-safe here
                    // because MarkdownRenderer touches no UIKit view state.
                    let rendered = backgroundRenderer.render(txt)
                    let mutable = NSMutableAttributedString(attributedString: rendered)
                    // Remap the generic Sphinx.Text colour to the bubble-appropriate TextMessages colour
                    // so the cell just assigns .attributedText directly without any enumeration.
                    mutable.enumerateAttribute(.foregroundColor,
                                               in: NSRange(location: 0, length: mutable.length)) { value, range, _ in
                        if let color = value as? UIColor, color == UIColor.Sphinx.Text {
                            mutable.addAttribute(.foregroundColor,
                                                 value: UIColor.Sphinx.TextMessages,
                                                 range: range)
                        }
                    }
                    renderedText.append(mutable)

                case .table(let h, let r):
                    tableWidths.append(
                        MarkdownTableView.calculateColumnWidths(headers: h, rows: r, totalColumns: h.count)
                    )
                    renderedText.append(nil) // placeholder keeps index alignment with segments
                }
            }

            messages[i].cachedSegments     = segments
            messages[i].cachedColumnWidths  = tableWidths
            messages[i].cachedRenderedText  = renderedText
        }
    }
}
