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

    nonisolated(unsafe) private static let backgroundRenderer: MarkdownRenderer = {
        var style = MarkdownStyle()
        style.baseFontSize = 15
        return MarkdownRenderer(style: style)
    }()

    nonisolated(unsafe) private static let bubbleWidthRatio: CGFloat = 0.85

    /// Pre-computes all expensive work for every message off the main thread:
    ///   - `cachedSegments`     — markdown split result
    ///   - `cachedColumnWidths` — per-table column widths (Core Text measurement)
    ///   - `cachedRenderedText` — per-text-segment NSAttributedString (regex rendering)
    ///   - `cachedTableImages`  — per-table UIImage rendered via Core Graphics
    ///   - `estimatedCellHeight`— height estimate for estimatedHeightForRowAt
    ///
    /// - Parameter screenWidth: capture `UIScreen.main.bounds.width` on the main thread
    ///   before dispatching to background, then pass it here.
    /// - Parameter scale: capture `UIScreen.main.scale` on the main thread similarly.
    static func precompute(_ messages: inout [HiveChatMessage], screenWidth: CGFloat, scale: CGFloat = 2) {
        let bubbleWidth = screenWidth * bubbleWidthRatio

        for i in messages.indices {
            let segments = MarkdownContentSplitter.split(messages[i].resolvedDisplayText)

            var tableWidths: [[CGFloat]] = []
            var renderedText: [NSAttributedString?] = []
            var tableImages: [UIImage] = []
            var estimatedHeight: CGFloat = 0

            for segment in segments {
                switch segment {
                case .text(let txt):
                    let rendered = backgroundRenderer.render(txt)
                    let mutable = NSMutableAttributedString(attributedString: rendered)
                    mutable.enumerateAttribute(.foregroundColor,
                                               in: NSRange(location: 0, length: mutable.length)) { value, range, _ in
                        if let color = value as? UIColor, color == UIColor.Sphinx.Text {
                            mutable.addAttribute(.foregroundColor,
                                                 value: UIColor.Sphinx.TextMessages,
                                                 range: range)
                        }
                    }
                    renderedText.append(mutable)

                    let textWidth = max(bubbleWidth - 16, 1)
                    let bounds = mutable.boundingRect(
                        with: CGSize(width: textWidth, height: .greatestFiniteMagnitude),
                        options: [.usesLineFragmentOrigin, .usesFontLeading],
                        context: nil
                    )
                    estimatedHeight += ceil(bounds.height) + 20 // top+bottom insets

                case .table(let h, let r):
                    let widths = MarkdownTableView.calculateColumnWidths(
                        headers: h, rows: r, totalColumns: h.count)
                    tableWidths.append(widths)
                    renderedText.append(nil)

                    let tableW = widths.reduce(0, +)
                    let tableH = CGFloat(r.count + 1) * 36
                    // Render the table to a UIImage via Core Graphics — thread-safe
                    let img = MarkdownTableView.renderImage(
                        headers: h, rows: r,
                        columnWidths: widths,
                        tableWidth: tableW,
                        tableHeight: tableH,
                        scale: scale
                    )
                    tableImages.append(img)
                    estimatedHeight += tableH + 8
                }
            }

            estimatedHeight += 23 // timestamp + cell padding

            messages[i].cachedSegments      = segments
            messages[i].cachedColumnWidths   = tableWidths
            messages[i].cachedRenderedText   = renderedText
            messages[i].cachedTableImages    = tableImages
            messages[i].estimatedCellHeight  = estimatedHeight
        }
    }
}
