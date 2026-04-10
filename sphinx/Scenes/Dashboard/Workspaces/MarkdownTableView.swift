//
//  MarkdownTableView.swift
//  sphinx
//
//  Created on 2026-04-09.
//  Copyright © 2025 sphinx. All rights reserved.
//

import UIKit

/// A horizontally-scrollable view that renders a GFM markdown table as a pre-rendered `UIImage`.
///
/// **Performance design:**
/// - `renderImage(headers:rows:columnWidths:scale:)` is a **static** method that uses Core
///   Graphics (thread-safe) to produce a `UIImage` entirely off the main thread.
/// - `configure(image:tableWidth:tableHeight:)` just assigns the image to a `UIImageView` —
///   zero view/label creation, zero constraint activation in `cellForRowAt`.
/// - `calculateColumnWidths` is also static for background-thread use.
class MarkdownTableView: UIView {

    // MARK: - Constants

    private static let rowHeight: CGFloat = 36
    private static let cellPadding: CGFloat = 24   // 8pt left + 8pt right + 8pt safety
    private static let labelInset: CGFloat = 8     // horizontal text inset inside each cell
    static let headerFont = UIFont.boldSystemFont(ofSize: 13)
    static let bodyFont   = UIFont.systemFont(ofSize: 13)

    // MARK: - Stored state

    private var imageHeight: CGFloat = 0
    private var imageWidth: CGFloat = 0

    var intrinsicContentHeight: CGFloat { imageHeight }

    // MARK: - Subviews

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        sv.showsHorizontalScrollIndicator = true
        sv.showsVerticalScrollIndicator   = false
        sv.bounces = true
        return sv
    }()

    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .topLeft
        return iv
    }()

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)
        scrollView.addSubview(imageView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        let w = max(imageWidth, scrollView.bounds.width)
        imageView.frame = CGRect(x: 0, y: 0, width: w, height: imageHeight)
        scrollView.contentSize = CGSize(width: w, height: imageHeight)
    }

    // MARK: - Public API

    /// Displays a pre-rendered table image (produced by `renderImage` off the main thread).
    /// This is the fast path — zero drawing in cellForRowAt.
    func configure(image: UIImage, tableWidth: CGFloat, tableHeight: CGFloat) {
        imageWidth  = tableWidth
        imageHeight = tableHeight
        imageView.image = image
        setNeedsLayout()
    }

    /// Fallback: renders synchronously on the calling thread (main). Used when no cached
    /// image is available so the cell still shows something correct.
    func configure(headers: [String], rows: [[String]]) {
        let widths = MarkdownTableView.calculateColumnWidths(
            headers: headers, rows: rows, totalColumns: headers.count)
        let w = widths.reduce(0, +)
        let h = CGFloat(rows.count + 1) * rowHeight
        let img = MarkdownTableView.renderImage(
            headers: headers, rows: rows, columnWidths: widths,
            tableWidth: w, tableHeight: h, scale: UIScreen.main.scale)
        configure(image: img, tableWidth: w, tableHeight: h)
    }

    func configure(headers: [String], rows: [[String]], precomputedColumnWidths: [CGFloat]) {
        let w = precomputedColumnWidths.reduce(0, +)
        let h = CGFloat(rows.count + 1) * rowHeight
        let img = MarkdownTableView.renderImage(
            headers: headers, rows: rows, columnWidths: precomputedColumnWidths,
            tableWidth: w, tableHeight: h, scale: UIScreen.main.scale)
        configure(image: img, tableWidth: w, tableHeight: h)
    }

    // MARK: - Column-width measurement (static — background-thread safe)

    static func calculateColumnWidths(headers: [String], rows: [[String]], totalColumns: Int) -> [CGFloat] {
        var widths = [CGFloat](repeating: 0, count: totalColumns)
        let measure: (String, UIFont) -> CGFloat = { text, font in
            ceil((text as NSString).size(withAttributes: [.font: font]).width) + cellPadding
        }
        for (col, h) in headers.enumerated() {
            widths[col] = max(widths[col], measure(h, headerFont))
        }
        for row in rows {
            for (col, cell) in row.enumerated() where col < totalColumns {
                widths[col] = max(widths[col], measure(cell, bodyFont))
            }
        }
        return widths
    }

    // MARK: - Core Graphics image renderer (static — thread-safe)

    /// Renders the table grid into a `UIImage` using Core Graphics.
    /// Safe to call from any thread — no UIKit view hierarchy involved.
    static func renderImage(
        headers: [String],
        rows: [[String]],
        columnWidths: [CGFloat],
        tableWidth: CGFloat,
        tableHeight: CGFloat,
        scale: CGFloat
    ) -> UIImage {
        let rh   = rowHeight
        let allRows = [headers] + rows

        // Resolve colours on whichever thread we're on — asset-catalog colours are thread-safe
        let dividerColor   = UIColor.Sphinx.LightDivider
        let textColor      = UIColor.Sphinx.TextMessages
        let headerBGColor  = dividerColor
        let evenRowColor   = dividerColor.withAlphaComponent(0.35)
        let oddRowColor    = dividerColor.withAlphaComponent(0.12)

        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: tableWidth, height: tableHeight),
            format: format
        )

        let image = renderer.image { ctx in
            let cgCtx = ctx.cgContext

            for (rowIndex, cells) in allRows.enumerated() {
                let isHeader = rowIndex == 0
                let y = CGFloat(rowIndex) * rh

                // Row background
                let bgColor: UIColor
                if isHeader {
                    bgColor = headerBGColor
                } else {
                    bgColor = rowIndex % 2 == 0 ? evenRowColor : oddRowColor
                }
                cgCtx.setFillColor(bgColor.cgColor)
                cgCtx.fill(CGRect(x: 0, y: y, width: tableWidth, height: rh))

                // Cell text
                let font: UIFont = isHeader ? headerFont : bodyFont
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: textColor
                ]
                var x: CGFloat = 0
                for (col, colWidth) in columnWidths.enumerated() {
                    let text = col < cells.count ? cells[col] : ""
                    let textRect = CGRect(
                        x: x + labelInset,
                        y: y + (rh - font.lineHeight) / 2,
                        width: colWidth - labelInset * 2,
                        height: font.lineHeight
                    )
                    (text as NSString).draw(in: textRect, withAttributes: attrs)
                    x += colWidth
                }

                // 1pt divider line below header
                if isHeader {
                    cgCtx.setFillColor(dividerColor.cgColor)
                    cgCtx.fill(CGRect(x: 0, y: y + rh - 1, width: tableWidth, height: 1))
                }
            }
        }

        return image
    }

    // MARK: - Private helpers

    private var rowHeight: CGFloat { MarkdownTableView.rowHeight }
}
