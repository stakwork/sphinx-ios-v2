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

    /// Bubble max-width multiplier (mirrors FeatureChatMessageCell bubbleWidthConstraint).
    private static let bubbleWidthRatio: CGFloat = 0.85

    /// Pre-computes all expensive non-UI work for every message:
    ///   - `cachedSegments`     — avoids re-parsing in `cellForRowAt`
    ///   - `cachedColumnWidths` — avoids Core Text measurement in `cellForRowAt`
    ///   - `cachedRenderedText` — avoids regex markdown rendering in `cellForRowAt`
    ///   - `estimatedCellHeight`— lets `estimatedHeightForRowAt` return an accurate value
    ///                            so UITableView never triggers off-screen cell measurement
    ///
    /// - Parameter screenWidth: pass `UIScreen.main.bounds.width` from the call-site
    ///   (must be read on the main thread before dispatching to background).
    /// **Must be called on a background queue.**
    /// Alamofire callbacks fire on the main queue — callers must wrap in
    /// `DispatchQueue.global(qos: .userInitiated).async { … }` before calling this.
    static func precompute(_ messages: inout [HiveChatMessage], screenWidth: CGFloat) {
        let bubbleWidth = screenWidth * bubbleWidthRatio

        for i in messages.indices {
            let segments = MarkdownContentSplitter.split(messages[i].resolvedDisplayText)

            var tableWidths: [[CGFloat]] = []
            var renderedText: [NSAttributedString?] = []
            var estimatedHeight: CGFloat = 0

            for segment in segments {
                switch segment {
                case .text(let txt):
                    // Pre-render markdown → NSAttributedString off the main thread.
                    let rendered = backgroundRenderer.render(txt)
                    let mutable = NSMutableAttributedString(attributedString: rendered)
                    // Remap generic Sphinx.Text colour → bubble TextMessages colour so the
                    // cell can assign .attributedText directly without any enumeration.
                    mutable.enumerateAttribute(.foregroundColor,
                                               in: NSRange(location: 0, length: mutable.length)) { value, range, _ in
                        if let color = value as? UIColor, color == UIColor.Sphinx.Text {
                            mutable.addAttribute(.foregroundColor,
                                                 value: UIColor.Sphinx.TextMessages,
                                                 range: range)
                        }
                    }
                    renderedText.append(mutable)

                    // Estimate the rendered height of this text segment inside the bubble.
                    // Use a constrained bounding rect — no UIKit view required.
                    let textInsetH: CGFloat = 8 + 8   // left + right textContainerInset
                    let textWidth = max(bubbleWidth - textInsetH, 1)
                    let bounds = mutable.boundingRect(
                        with: CGSize(width: textWidth, height: .greatestFiniteMagnitude),
                        options: [.usesLineFragmentOrigin, .usesFontLeading],
                        context: nil
                    )
                    let textInsetV: CGFloat = 10 + 10  // top + bottom textContainerInset
                    estimatedHeight += ceil(bounds.height) + textInsetV

                case .table(let h, let r):
                    let widths = MarkdownTableView.calculateColumnWidths(
                        headers: h, rows: r, totalColumns: h.count)
                    tableWidths.append(widths)
                    renderedText.append(nil) // index placeholder

                    // Table height: (rows + 1 header) × rowHeight + 8pt spacer
                    let rowCount = CGFloat(r.count + 1)
                    estimatedHeight += rowCount * 36 + 8
                }
            }

            // Add timestamp label height + top/bottom cell padding
            estimatedHeight += 15 + 4 + 4   // ~15pt label + 4pt top + 4pt bottom

            messages[i].cachedSegments      = segments
            messages[i].cachedColumnWidths   = tableWidths
            messages[i].cachedRenderedText   = renderedText
            messages[i].estimatedCellHeight  = estimatedHeight
        }
    }
}
