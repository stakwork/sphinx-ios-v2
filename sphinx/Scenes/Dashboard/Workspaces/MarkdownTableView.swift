//
//  MarkdownTableView.swift
//  sphinx
//
//  Created on 2026-04-09.
//  Copyright © 2025 sphinx. All rights reserved.
//

import UIKit

/// A horizontally-scrollable table view that renders a GFM-style markdown table
/// as a programmatic grid of selectable UITextView cells inside a UIScrollView.
///
/// **Performance notes:**
/// - `calculateColumnWidths` is `static internal` so the caller can run it on a background
///   thread and pass pre-computed widths to `configure(headers:rows:precomputedColumnWidths:)`.
/// - All subviews inside `contentView` use direct `.frame` assignment (no Auto Layout
///   constraints), making `configure()` cheap enough to call from `cellForRowAt`.
class MarkdownTableView: UIView {

    // MARK: - Constants

    private static let rowHeight: CGFloat = 36
    /// 8pt each side + 8pt safety buffer to prevent truncation
    private static let cellPadding: CGFloat = 24
    private static let horizontalMargin: CGFloat = 0
    static let headerFont = UIFont.boldSystemFont(ofSize: 13)
    static let bodyFont   = UIFont.systemFont(ofSize: 13)

    // MARK: - Stored state

    private var rowCount: Int = 0
    /// Total pixel width of the content (sum of column widths). Drives contentSize + layout.
    private var totalContentWidth: CGFloat = 0

    /// Returns the total height needed for the table (header row + all data rows).
    var intrinsicContentHeight: CGFloat {
        return CGFloat(rowCount + 1) * MarkdownTableView.rowHeight
    }

    // MARK: - Subviews

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        sv.showsHorizontalScrollIndicator = true
        sv.showsVerticalScrollIndicator   = false
        sv.bounces = true
        sv.alwaysBounceHorizontal = false
        return sv
    }()

    /// Frame-layout container — subviews inside use `.frame`, not Auto Layout.
    private let contentView = UIView()

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        setupScrollView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        translatesAutoresizingMaskIntoConstraints = false
        setupScrollView()
    }

    private func setupScrollView() {
        addSubview(scrollView)
        scrollView.addSubview(contentView)

        // Only the scroll view itself uses Auto Layout (pinned to self). Everything
        // inside contentView uses frame layout set in configure().
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        // Update contentView frame and scrollView.contentSize whenever our bounds change.
        let tableHeight = intrinsicContentHeight
        let contentWidth = max(totalContentWidth, scrollView.bounds.width)
        contentView.frame = CGRect(x: 0, y: 0, width: contentWidth, height: tableHeight)
        scrollView.contentSize = CGSize(width: contentWidth, height: tableHeight)
    }

    // MARK: - Public API

    /// Configures (or re-configures) the table. Measures column widths inline.
    func configure(headers: [String], rows: [[String]]) {
        let widths = MarkdownTableView.calculateColumnWidths(
            headers: headers, rows: rows, totalColumns: headers.count)
        buildGrid(headers: headers, rows: rows, columnWidths: widths)
    }

    /// Configures (or re-configures) the table using pre-computed column widths.
    /// Skips `NSString.size(withAttributes:)` entirely — safe to call from `cellForRowAt`.
    func configure(headers: [String], rows: [[String]], precomputedColumnWidths: [CGFloat]) {
        buildGrid(headers: headers, rows: rows, columnWidths: precomputedColumnWidths)
    }

    // MARK: - Column-width measurement (static — background-thread safe)

    /// Calculates the minimum column widths needed to display all content without truncation.
    /// `static internal` so callers can run this on a background thread.
    /// Font constants are static — safe to read off the main thread.
    static func calculateColumnWidths(headers: [String], rows: [[String]], totalColumns: Int) -> [CGFloat] {
        var widths = [CGFloat](repeating: 0, count: totalColumns)

        let measure: (String, UIFont) -> CGFloat = { text, font in
            let size = (text as NSString).size(withAttributes: [.font: font])
            return ceil(size.width) + MarkdownTableView.cellPadding
        }

        for (col, header) in headers.enumerated() {
            widths[col] = max(widths[col], measure(header, headerFont))
        }
        for row in rows {
            for (col, cell) in row.enumerated() where col < totalColumns {
                widths[col] = max(widths[col], measure(cell, bodyFont))
            }
        }
        return widths
    }

    // MARK: - Private grid builder

    /// Builds the entire grid using direct `.frame` assignment — no Auto Layout constraints
    /// created per cell, making this safe and fast to call from `cellForRowAt`.
    private func buildGrid(headers: [String], rows: [[String]], columnWidths: [CGFloat]) {
        rowCount = rows.count

        // Remove all previously created grid subviews
        contentView.subviews.forEach { $0.removeFromSuperview() }

        guard !headers.isEmpty else {
            totalContentWidth = 0
            return
        }

        totalContentWidth = columnWidths.reduce(0, +)
        let rh = MarkdownTableView.rowHeight

        // We don't know the final scrollView width at configure time, so we use
        // totalContentWidth as a placeholder; layoutSubviews() corrects it.
        let contentWidth = max(totalContentWidth, 1)
        contentView.frame = CGRect(x: 0, y: 0, width: contentWidth, height: intrinsicContentHeight)
        scrollView.contentSize = CGSize(width: contentWidth, height: intrinsicContentHeight)

        // Draw all rows (index 0 = header)
        let allRows = [headers] + rows
        for (rowIndex, cells) in allRows.enumerated() {
            let isHeader = rowIndex == 0
            let yOffset = CGFloat(rowIndex) * rh

            // Row background (frame-based)
            let rowBG = UIView(frame: CGRect(x: 0, y: yOffset, width: contentWidth, height: rh))
            if isHeader {
                rowBG.backgroundColor = UIColor.Sphinx.LightDivider
            } else {
                rowBG.backgroundColor = (rowIndex % 2 == 0)
                    ? UIColor.Sphinx.LightDivider.withAlphaComponent(0.35)
                    : UIColor.Sphinx.LightDivider.withAlphaComponent(0.12)
            }
            contentView.addSubview(rowBG)

            // Cell text views (frame-based)
            let font: UIFont = isHeader ? MarkdownTableView.headerFont : MarkdownTableView.bodyFont
            var xOffset: CGFloat = 0
            for (col, colWidth) in columnWidths.enumerated() {
                let text = col < cells.count ? cells[col] : ""
                let tv = UITextView(frame: CGRect(x: xOffset, y: yOffset, width: colWidth, height: rh))
                tv.isEditable = false
                tv.isScrollEnabled = false
                tv.isSelectable = true
                tv.backgroundColor = .clear
                tv.font = font
                tv.textColor = UIColor.Sphinx.TextMessages
                tv.textContainerInset = UIEdgeInsets(top: 9, left: 8, bottom: 9, right: 8)
                tv.textContainer.lineFragmentPadding = 0
                tv.textContainer.maximumNumberOfLines = 1
                tv.textContainer.lineBreakMode = .byClipping
                tv.text = text
                contentView.addSubview(tv)
                xOffset += colWidth
            }

            // 1pt divider below header row
            if isHeader {
                let divider = UIView(frame: CGRect(x: 0, y: rh - 1, width: contentWidth, height: 1))
                divider.backgroundColor = UIColor.Sphinx.LightDivider
                rowBG.addSubview(divider)
            }
        }

        setNeedsLayout()
    }
}
