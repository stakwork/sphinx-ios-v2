//
//  MarkdownTableView.swift
//  sphinx
//
//  Created on 2026-04-09.
//  Copyright © 2025 sphinx. All rights reserved.
//

import UIKit

/// A horizontally-scrollable table view that renders a GFM-style markdown table
/// as a programmatic grid of UILabel cells inside a UIScrollView.
class MarkdownTableView: UIView {

    // MARK: - Constants

    private static let rowHeight: CGFloat = 36
    private static let cellPadding: CGFloat = 16   // 8pt each side
    private static let headerFont = UIFont.boldSystemFont(ofSize: 13)
    private static let bodyFont   = UIFont.systemFont(ofSize: 13)

    // MARK: - Stored state (for intrinsicContentHeight)

    private var rowCount: Int = 0

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

    private let contentView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

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

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            // Content height matches the scroll view height (no vertical scroll)
            contentView.heightAnchor.constraint(equalTo: scrollView.heightAnchor),
        ])
    }

    // MARK: - Public API

    /// Configures (or re-configures) the table grid. Safe to call multiple times.
    func configure(headers: [String], rows: [[String]]) {
        rowCount = rows.count

        // Idempotent: remove all previous subviews from the content view
        contentView.subviews.forEach { $0.removeFromSuperview() }

        guard !headers.isEmpty else { return }

        let totalColumns = headers.count
        let columnWidths = calculateColumnWidths(headers: headers, rows: rows, totalColumns: totalColumns)
        let totalWidth   = columnWidths.reduce(0, +)

        // Set content width so horizontal scroll activates when table is wider than the container
        let contentWidthConstraint = contentView.widthAnchor.constraint(equalToConstant: totalWidth)
        contentWidthConstraint.priority = .defaultHigh
        contentWidthConstraint.isActive = true

        // Draw header row
        drawRow(
            cells: headers,
            rowIndex: 0,
            isHeader: true,
            columnWidths: columnWidths,
            totalWidth: totalWidth
        )

        // 1pt divider below header
        let divider = UIView()
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.backgroundColor = UIColor.Sphinx.LightDivider
        contentView.addSubview(divider)
        NSLayoutConstraint.activate([
            divider.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            divider.widthAnchor.constraint(equalToConstant: totalWidth),
            divider.topAnchor.constraint(equalTo: contentView.topAnchor, constant: MarkdownTableView.rowHeight),
            divider.heightAnchor.constraint(equalToConstant: 1)
        ])

        // Draw data rows
        for (idx, rowCells) in rows.enumerated() {
            drawRow(
                cells: rowCells,
                rowIndex: idx + 1,
                isHeader: false,
                columnWidths: columnWidths,
                totalWidth: totalWidth
            )
        }
    }

    // MARK: - Private helpers

    private func calculateColumnWidths(headers: [String], rows: [[String]], totalColumns: Int) -> [CGFloat] {
        var widths = [CGFloat](repeating: 0, count: totalColumns)

        let measure: (String, UIFont) -> CGFloat = { text, font in
            let size = (text as NSString).size(withAttributes: [.font: font])
            return size.width + MarkdownTableView.cellPadding
        }

        for (col, header) in headers.enumerated() {
            widths[col] = max(widths[col], measure(header, MarkdownTableView.headerFont))
        }

        for row in rows {
            for (col, cell) in row.enumerated() where col < totalColumns {
                widths[col] = max(widths[col], measure(cell, MarkdownTableView.bodyFont))
            }
        }

        return widths
    }

    private func drawRow(
        cells: [String],
        rowIndex: Int,
        isHeader: Bool,
        columnWidths: [CGFloat],
        totalWidth: CGFloat
    ) {
        let yOffset = CGFloat(rowIndex) * MarkdownTableView.rowHeight

        // Row background
        let rowBG = UIView()
        rowBG.translatesAutoresizingMaskIntoConstraints = false
        if isHeader {
            rowBG.backgroundColor = UIColor.Sphinx.LightDivider
        } else {
            rowBG.backgroundColor = (rowIndex % 2 == 0)
                ? UIColor.Sphinx.Body
                : UIColor.Sphinx.ReceivedMsgBG
        }
        contentView.addSubview(rowBG)
        NSLayoutConstraint.activate([
            rowBG.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            rowBG.topAnchor.constraint(equalTo: contentView.topAnchor, constant: yOffset),
            rowBG.widthAnchor.constraint(equalToConstant: totalWidth),
            rowBG.heightAnchor.constraint(equalToConstant: MarkdownTableView.rowHeight)
        ])

        // Cell labels
        var xOffset: CGFloat = 0
        let font: UIFont = isHeader ? MarkdownTableView.headerFont : MarkdownTableView.bodyFont

        for (col, colWidth) in columnWidths.enumerated() {
            let text = col < cells.count ? cells[col] : ""
            let label = UILabel()
            label.translatesAutoresizingMaskIntoConstraints = false
            label.text = text
            label.font = font
            label.textColor = UIColor.Sphinx.TextMessages
            label.numberOfLines = 1
            label.lineBreakMode = .byTruncatingTail
            contentView.addSubview(label)

            let currentX = xOffset
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: currentX + 8),
                label.topAnchor.constraint(equalTo: contentView.topAnchor, constant: yOffset),
                label.widthAnchor.constraint(equalToConstant: colWidth - 16),
                label.heightAnchor.constraint(equalToConstant: MarkdownTableView.rowHeight)
            ])

            xOffset += colWidth
        }
    }
}
