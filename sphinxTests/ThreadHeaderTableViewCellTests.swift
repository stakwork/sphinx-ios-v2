//
//  ThreadHeaderTableViewCellTests.swift
//  sphinxTests
//
//  Unit tests for the ThreadHeaderTableViewCell layout fixes:
//    1. labelHeight uses rendered attributedText, not plain-text estimate.
//    2. labelHeight is not cached — reuse returns the new message's height.
//    3. isLabelTruncated / showMoreVisible gate correctly for tall markdown content.
//
//  Copyright © 2024 sphinx. All rights reserved.
//

import XCTest
@testable import sphinx

// MARK: - Helpers

/// Creates a minimal NoBubbleMessageLayoutState.ThreadOriginalMessage for testing.
private func makeThreadOriginalMessage(text: String) -> NoBubbleMessageLayoutState.ThreadOriginalMessage {
    return NoBubbleMessageLayoutState.ThreadOriginalMessage(
        text: text,
        linkMatches: [],
        highlightedMatches: [],
        boldMatches: [],
        linkMarkdownMatches: [],
        senderPic: nil,
        senderAlias: "Test User",
        senderColor: .gray,
        timestamp: "12:00 PM"
    )
}

/// Loads a ThreadHeaderTableViewCell from its xib.
private func loadCell() -> ThreadHeaderTableViewCell {
    let nib = UINib(nibName: "ThreadHeaderTableViewCell", bundle: Bundle(for: ThreadHeaderTableViewCell.self))
    let objects = nib.instantiate(withOwner: nil, options: nil)
    let cell = objects.compactMap { $0 as? ThreadHeaderTableViewCell }.first!
    cell.awakeFromNib()
    return cell
}

/// Forces a layout pass so `messageLabel.bounds.width` is resolved before measuring.
private func forceLayout(_ cell: ThreadHeaderTableViewCell, containerWidth: CGFloat = 375) {
    cell.frame = CGRect(x: 0, y: 0, width: containerWidth, height: 1000)
    cell.layoutIfNeeded()
}

// MARK: - Long markdown content fixture

/// A message that exercises the full failure mode:
///   - multi-line body text
///   - a code block (mixed fonts, background colour, line spacing)
///   - a long single-token URL
private let kLongMarkdownText: String = {
    var lines = [String]()
    lines.append("Here is a response to the question you sent:")
    lines.append("")
    lines.append("```swift")
    lines.append("func computeSignature(payload: Data, privateKey: SecKey) throws -> Data {")
    lines.append("    var error: Unmanaged<CFError>?")
    lines.append("    guard let signature = SecKeyCreateSignature(privateKey, .ecdsaSignatureMessageX962SHA256, payload as CFData, &error) as Data? else {")
    lines.append("        throw error!.takeRetainedValue() as Error")
    lines.append("    }")
    lines.append("    return signature")
    lines.append("}")
    lines.append("```")
    lines.append("")
    lines.append("You can fetch the full node list using:")
    lines.append("GET https://swarm38.sphinx.chat/api/v2/nodes/abcdef1234567890abcdef1234567890abcdef1234567890?expand=true&include=metadata&version=2&format=json&auth=Bearer+eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9")
    return lines.joined(separator: "\n")
}()

/// A short message that should never trigger the "show more" gate.
private let kShortText = "Hi!"

// MARK: - Tests

final class ThreadHeaderTableViewCellLabelHeightTests: XCTestCase {

    // MARK: - 1. Attributed height > plain-text estimate for long markdown

    func testAttributedHeightExceedsPlainTextEstimateForLongMarkdown() {
        let cell = loadCell()
        forceLayout(cell)

        let msg = makeThreadOriginalMessage(text: kLongMarkdownText)

        // Configure with collapsed state (numberOfLines = 12).
        cell.configureWith(
            threadOriginalMessage: msg,
            isHeaderExpanded: false,
            headerDifference: nil
        )

        // Give Auto Layout a chance to update label bounds after setting attributedText.
        cell.layoutIfNeeded()

        // Measure via the new attributed-string path.
        let attributedHeight = cell.labelHeight

        // Measure via the old plain-text, single-font path to confirm it would under-count.
        let plainTextHeight = UILabel.getTextSize(
            width: UIScreen.main.bounds.width - 32,
            text: cell.messageLabel.text ?? "",
            font: cell.messageLabel.font
        ).height

        XCTAssertGreaterThan(
            attributedHeight, plainTextHeight,
            "Attributed-string height (\(attributedHeight)pt) must exceed plain-text estimate (\(plainTextHeight)pt) for markdown with code blocks."
        )
    }

    // MARK: - 2. isLabelTruncated returns true for long markdown (collapsed)

    func testIsLabelTruncatedIsTrueForLongMarkdown() {
        let cell = loadCell()
        forceLayout(cell)

        let msg = makeThreadOriginalMessage(text: kLongMarkdownText)
        cell.configureWith(
            threadOriginalMessage: msg,
            isHeaderExpanded: false,
            headerDifference: nil
        )
        cell.layoutIfNeeded()

        XCTAssertTrue(
            cell.isLabelTruncated(),
            "isLabelTruncated() must return true for content taller than ~240 pt."
        )
    }

    // MARK: - 3. showMoreVisible is true in collapsed state for long markdown

    func testShowMoreVisibleIsTrueWhenCollapsedWithLongMarkdown() {
        let cell = loadCell()
        forceLayout(cell)

        let msg = makeThreadOriginalMessage(text: kLongMarkdownText)
        cell.configureWith(
            threadOriginalMessage: msg,
            isHeaderExpanded: false,
            headerDifference: nil
        )
        cell.layoutIfNeeded()

        XCTAssertTrue(
            cell.showMoreVisible(false),
            "showMoreVisible(_:false) must be true for long markdown in collapsed state."
        )
    }

    // MARK: - 4. showMoreVisible is false when expanded

    func testShowMoreVisibleIsFalseWhenExpanded() {
        let cell = loadCell()
        forceLayout(cell)

        let msg = makeThreadOriginalMessage(text: kLongMarkdownText)
        cell.configureWith(
            threadOriginalMessage: msg,
            isHeaderExpanded: true,
            headerDifference: nil
        )
        cell.layoutIfNeeded()

        XCTAssertFalse(
            cell.showMoreVisible(true),
            "showMoreVisible(_:true) must be false — the expanded state never shows the 'show more' affordance."
        )
    }

    // MARK: - 5. Short message does not trigger the show-more gate

    func testShortMessageIsNotTruncated() {
        let cell = loadCell()
        forceLayout(cell)

        let msg = makeThreadOriginalMessage(text: kShortText)
        cell.configureWith(
            threadOriginalMessage: msg,
            isHeaderExpanded: false,
            headerDifference: nil
        )
        cell.layoutIfNeeded()

        XCTAssertFalse(
            cell.isLabelTruncated(),
            "Short message must not be considered truncated."
        )
        XCTAssertFalse(
            cell.showMoreVisible(false),
            "showMoreVisible(_:false) must be false for a short message."
        )
    }
}

// MARK: - Reuse (stale-height) Tests

final class ThreadHeaderTableViewCellReuseTests: XCTestCase {

    // MARK: - 6. Height is recomputed after reuse — no stale cached value

    func testHeightReflectsSecondMessageAfterReuse() {
        let cell = loadCell()
        forceLayout(cell)

        // First configure with tall content.
        let tallMsg = makeThreadOriginalMessage(text: kLongMarkdownText)
        cell.configureWith(
            threadOriginalMessage: tallMsg,
            isHeaderExpanded: false,
            headerDifference: nil
        )
        cell.layoutIfNeeded()
        let tallHeight = cell.labelHeight

        // Simulate cell reuse.
        cell.prepareForReuse()

        // Reconfigure with short content.
        let shortMsg = makeThreadOriginalMessage(text: kShortText)
        cell.configureWith(
            threadOriginalMessage: shortMsg,
            isHeaderExpanded: false,
            headerDifference: nil
        )
        cell.layoutIfNeeded()
        let shortHeight = cell.labelHeight

        XCTAssertLessThan(
            shortHeight, tallHeight,
            "After reuse with a short message, labelHeight (\(shortHeight)pt) must be less than the previously configured tall height (\(tallHeight)pt). A stale lazy var would return the tall value here."
        )
    }
}

// MARK: - Content-view containment tests

final class ThreadHeaderTableViewCellContainmentTests: XCTestCase {

    // MARK: - 7. contentView height >= rendered label height (collapsed)

    func testContentViewHeightIsAtLeastLabelHeightWhenCollapsed() {
        let cell = loadCell()
        forceLayout(cell, containerWidth: 375)

        let msg = makeThreadOriginalMessage(text: kLongMarkdownText)
        cell.configureWith(
            threadOriginalMessage: msg,
            isHeaderExpanded: false,
            headerDifference: nil
        )

        // Two layout passes mirror how UITableView resolves self-sizing cells.
        cell.setNeedsLayout()
        cell.layoutIfNeeded()
        cell.setNeedsLayout()
        cell.layoutIfNeeded()

        let renderedLabelHeight = cell.labelHeight
        let contentViewHeight  = cell.contentView.frame.height

        XCTAssertGreaterThanOrEqual(
            contentViewHeight, renderedLabelHeight,
            "contentView height (\(contentViewHeight)pt) must be >= rendered label height (\(renderedLabelHeight)pt) in collapsed state — text must not overflow its container."
        )
    }

    // MARK: - 8. contentView height >= rendered label height (expanded)

    func testContentViewHeightIsAtLeastLabelHeightWhenExpanded() {
        let cell = loadCell()
        forceLayout(cell, containerWidth: 375)

        let msg = makeThreadOriginalMessage(text: kLongMarkdownText)
        cell.configureWith(
            threadOriginalMessage: msg,
            isHeaderExpanded: true,   // numberOfLines = 0 → unconstrained height
            headerDifference: nil
        )

        cell.setNeedsLayout()
        cell.layoutIfNeeded()
        cell.setNeedsLayout()
        cell.layoutIfNeeded()

        let renderedLabelHeight = cell.labelHeight
        let contentViewHeight  = cell.contentView.frame.height

        XCTAssertGreaterThanOrEqual(
            contentViewHeight, renderedLabelHeight,
            "contentView height (\(contentViewHeight)pt) must be >= rendered label height (\(renderedLabelHeight)pt) in expanded state — full message must not clip."
        )
    }
}
