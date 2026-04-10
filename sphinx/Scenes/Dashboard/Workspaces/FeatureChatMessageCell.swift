//
//  FeatureChatMessageCell.swift
//  sphinx
//
//  Created on 2025-02-26.
//  Copyright © 2025 sphinx. All rights reserved.
//

import UIKit
import SDWebImage

class FeatureChatMessageCell: UITableViewCell {

    // MARK: - Shared markdown renderer
    private static let markdownRenderer: MarkdownRenderer = {
        var style = MarkdownStyle()
        style.baseFontSize = 15
        return MarkdownRenderer(style: style)
    }()

    // MARK: - Logs expand/collapse state
    private var isLogsExpanded: Bool = false
    private var currentLogsContent: String? = nil

    // MARK: - Dynamically inserted segment views (tables + extra text views)
    private var activeTableViews: [MarkdownTableView] = []
    private var activeSegmentViews: [UIView] = []

    // MARK: - Bubble stack (promoted to stored property for dynamic table insertion)
    private var bubbleStack: UIStackView = UIStackView()

    // MARK: - UI Components

    private let bubbleView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = 18
        view.layer.masksToBounds = true
        return view
    }()

    /// Dedicated background view that carries the bubble colour when a PR card is present.
    /// This lets `bubbleView` stay unclipped (for the card's border) while still showing
    /// properly-rounded corners on the text section.
    private let textBackgroundView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.layer.cornerRadius = 18
        v.layer.masksToBounds = true
        return v
    }()

    /// Non-scrolling UITextView so NSAttributedString (markdown) renders properly.
    private let messageTextView: UITextView = {
        let tv = UITextView()
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.isEditable = false
        tv.isScrollEnabled = false
        tv.isSelectable = true
        tv.backgroundColor = .clear
        tv.textContainerInset = UIEdgeInsets(top: 10, left: 8, bottom: 10, right: 8)
        tv.textContainer.lineFragmentPadding = 0
        tv.linkTextAttributes = [
            .foregroundColor: UIColor.Sphinx.PrimaryBlue,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        tv.delegate = LinkTapCoordinator.shared
        return tv
    }()

    /// Tappable header shown for logs messages (collapsed: "> Logs", expanded: "▾ Logs").
    private let logsHeaderButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.contentHorizontalAlignment = .left
        btn.titleLabel?.font = UIFont.boldSystemFont(ofSize: 15)
        btn.setTitleColor(UIColor.Sphinx.SecondaryText, for: .normal)
        btn.contentEdgeInsets = UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
        btn.isHidden = true
        return btn
    }()

    /// Non-scrolling text view for the logs body (code-block style). Hidden when collapsed.
    private let logsBodyTextView: UITextView = {
        let tv = UITextView()
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.isEditable = false
        tv.isScrollEnabled = false
        tv.isSelectable = true
        tv.backgroundColor = .clear
        tv.textContainerInset = UIEdgeInsets(top: 4, left: 8, bottom: 10, right: 8)
        tv.textContainer.lineFragmentPadding = 0
        tv.isHidden = true
        return tv
    }()

    /// PR artifact card — only shown when a PULL_REQUEST artifact is present.
    private let prCardView: PRArtifactCardView = {
        let v = PRArtifactCardView()
        v.isHidden = true
        return v
    }()

    // MARK: - Callbacks

    /// Called when the clarifying questions view changes its content height
    /// (e.g. navigating between questions) so the host table view can recalculate row height.
    var onHeightChanged: (() -> Void)?

    /// Called when the user taps an attachment tile.
    var onAttachmentTap: ((HiveChatMessageAttachment) -> Void)? {
        didSet { attachmentGridView.onTapAttachment = onAttachmentTap }
    }

    // MARK: - Attachment grid
    private let attachmentGridView: AttachmentGridView = {
        let v = AttachmentGridView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.isHidden = true
        return v
    }()

    private let timestampLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont(name: "Roboto-Regular", size: 11)
        label.textColor = UIColor.Sphinx.SecondaryText
        return label
    }()

    // MARK: - Sender avatar (shown only for sent messages)
    private let senderAvatarImageView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.layer.cornerRadius = 10   // 20pt diameter → 10pt radius
        iv.clipsToBounds = true
        iv.contentMode = .scaleAspectFill
        iv.image = UIImage(named: "profile_avatar")
        iv.isHidden = true
        return iv
    }()

    // MARK: - Alignment constraints (toggled per message role)
    private var bubbleLeadingConstraint: NSLayoutConstraint!
    private var bubbleTrailingConstraint: NSLayoutConstraint!
    private var bubbleTrailingConstraintSent: NSLayoutConstraint!
    private var timestampLeadingConstraint: NSLayoutConstraint!
    private var timestampTrailingConstraint: NSLayoutConstraint!
    private var bubbleWidthConstraint: NSLayoutConstraint!

    // MARK: - Init
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Layout
    private func setupUI() {
        backgroundColor = .Sphinx.Body
        contentView.backgroundColor = .Sphinx.Body
        selectionStyle = .none

        // Wire logs header tap
        logsHeaderButton.addTarget(self, action: #selector(logsHeaderTapped), for: .touchUpInside)

        // Vertical stack inside bubble: text + logs header + logs body + optional PR card + optional attachment grid
        bubbleStack = UIStackView(arrangedSubviews: [messageTextView, logsHeaderButton, logsBodyTextView, prCardView, attachmentGridView])
        bubbleStack.translatesAutoresizingMaskIntoConstraints = false
        bubbleStack.axis = .vertical
        bubbleStack.spacing = 0
        bubbleStack.isLayoutMarginsRelativeArrangement = true

        contentView.addSubview(bubbleView)
        bubbleView.insertSubview(textBackgroundView, belowSubview: bubbleStack)
        bubbleView.addSubview(bubbleStack)
        contentView.addSubview(timestampLabel)
        contentView.addSubview(senderAvatarImageView)

        bubbleLeadingConstraint  = bubbleView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16)
        bubbleTrailingConstraint = bubbleView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        // -36 = avatar(20) + gap(8) + right margin(8)
        bubbleTrailingConstraintSent = bubbleView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -36)

        timestampLeadingConstraint  = timestampLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor)
        timestampTrailingConstraint = timestampLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor)

        bubbleWidthConstraint = bubbleView.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: 0.85)

        NSLayoutConstraint.activate([
            senderAvatarImageView.widthAnchor.constraint(equalToConstant: 20),
            senderAvatarImageView.heightAnchor.constraint(equalToConstant: 20),
            senderAvatarImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            senderAvatarImageView.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor),
            bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            bubbleWidthConstraint,
            bubbleStack.topAnchor.constraint(equalTo: bubbleView.topAnchor),
            bubbleStack.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor),
            bubbleStack.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor),
            bubbleStack.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor),
            timestampLabel.topAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: 4),
            timestampLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            // textBackgroundView covers only the text area (top of bubble → bottom of text view)
            textBackgroundView.topAnchor.constraint(equalTo: bubbleView.topAnchor),
            textBackgroundView.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor),
            textBackgroundView.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor),
            textBackgroundView.bottomAnchor.constraint(equalTo: messageTextView.bottomAnchor),
        ])
    }

    // MARK: - Configure
    func configure(with message: HiveChatMessage, isLastMessage: Bool = false, italicText: String? = nil) {
        let isUser = message.isUserMessage

        // --- Clean up any dynamically inserted segment views from previous use ---
        activeSegmentViews.forEach { $0.removeFromSuperview() }
        activeSegmentViews.removeAll()
        activeTableViews.removeAll()

        // --- Text content ---
        if isUser {
            if let italic = italicText {
                let font = UIFont(name: "Roboto-Italic", size: 15)
                    ?? UIFont.italicSystemFont(ofSize: 15)
                let mutable = NSMutableAttributedString(
                    string: italic,
                    attributes: [.font: font, .foregroundColor: UIColor.Sphinx.TextMessages.withAlphaComponent(0.5)]
                )
                messageTextView.attributedText = mutable
            } else if let logsBody = message.logsContent {
                currentLogsContent = logsBody
                configureLogsViews()
            } else {
                renderSegmentedContent(
                    message.resolvedDisplayText,
                    cachedSegments: message.cachedSegments,
                    cachedColumnWidths: message.cachedColumnWidths,
                    cachedRenderedText: message.cachedRenderedText,
                    cachedTableImages: message.cachedTableImages
                )
            }
            // For logs messages, configureLogsViews() already manages messageTextView visibility.
            // Only touch it for non-logs messages.
            if message.logsContent == nil && italicText == nil {
                // messageTextView visibility is handled inside renderSegmentedContent
            } else if message.logsContent == nil {
                let hasText = !message.resolvedDisplayText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                messageTextView.isHidden = !hasText
            }
            bubbleView.backgroundColor      = UIColor.Sphinx.SentMsgBG
            timestampLabel.textColor        = UIColor.Sphinx.SecondaryTextSent
            timestampLabel.textAlignment    = .right
            bubbleLeadingConstraint.isActive  = false
            bubbleTrailingConstraint.isActive = false
            bubbleTrailingConstraintSent.isActive = true
            timestampLeadingConstraint.isActive  = false
            timestampTrailingConstraint.isActive = true

            // Sender avatar
            senderAvatarImageView.isHidden = false
            if let urlStr = message.createdBy?.image, let url = URL(string: urlStr) {
                senderAvatarImageView.sd_setImage(
                    with: url,
                    placeholderImage: UIImage(named: "profile_avatar"),
                    options: .lowPriority
                )
            } else {
                senderAvatarImageView.image = UIImage(named: "profile_avatar")
            }
        } else {
            if let logsBody = message.logsContent {
                currentLogsContent = logsBody
                configureLogsViews()
            } else {
                renderSegmentedContent(
                    message.resolvedDisplayText,
                    cachedSegments: message.cachedSegments,
                    cachedColumnWidths: message.cachedColumnWidths,
                    cachedRenderedText: message.cachedRenderedText,
                    cachedTableImages: message.cachedTableImages
                )
            }
            bubbleView.backgroundColor      = UIColor.Sphinx.ReceivedMsgBG
            timestampLabel.textColor        = UIColor.Sphinx.SecondaryText
            timestampLabel.textAlignment    = .left
            bubbleTrailingConstraintSent.isActive = false
            bubbleTrailingConstraint.isActive = true
            bubbleLeadingConstraint.isActive  = true
            timestampTrailingConstraint.isActive = false
            timestampLeadingConstraint.isActive  = true

            // Hide sender avatar for received messages
            senderAvatarImageView.isHidden = true
        }

        // --- PR artifact card ---
        if let prArtifact = message.artifacts.first(where: { $0.isPullRequest }),
           let prContent = prArtifact.prContent {
            prCardView.configure(with: prContent)
            prCardView.isHidden = false
            // Fix 1: expand bubble to 60% fixed width for PR card
            bubbleWidthConstraint.isActive = false
            bubbleWidthConstraint = bubbleView.widthAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: 0.60)
            bubbleWidthConstraint.isActive = true
            // Fix 2: only round top corners; disable masksToBounds so card's own corners/border show
            bubbleView.layer.cornerRadius = 18
            bubbleView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
            bubbleView.layer.masksToBounds = false
            // Move bubble colour onto textBackgroundView so the bottom corners clip correctly
            bubbleView.backgroundColor = .clear
            let roleColour: UIColor = isUser ? UIColor.Sphinx.SentMsgBG : UIColor.Sphinx.ReceivedMsgBG
            textBackgroundView.backgroundColor = roleColour
            textBackgroundView.layer.maskedCorners = [
                .layerMinXMinYCorner, .layerMaxXMinYCorner,
                .layerMinXMaxYCorner, .layerMaxXMaxYCorner
            ]
            textBackgroundView.layer.masksToBounds = true
        } else {
            prCardView.isHidden = true
            // Restore default width constraint
            bubbleWidthConstraint.isActive = false
            bubbleWidthConstraint = bubbleView.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: 0.85)
            bubbleWidthConstraint.isActive = true
            // Restore full corner masking
            bubbleView.layer.maskedCorners = [
                .layerMinXMinYCorner, .layerMaxXMinYCorner,
                .layerMinXMaxYCorner, .layerMaxXMaxYCorner
            ]
            bubbleView.layer.masksToBounds = true
            // textBackgroundView not needed — clear it
            textBackgroundView.backgroundColor = .clear
        }

        // --- LONGFORM border ---
        if message.isLongformMessage {
            bubbleView.layer.borderWidth = 1
            bubbleView.layer.borderColor = UIColor.Sphinx.LightDivider.cgColor
        } else {
            bubbleView.layer.borderWidth = 0
            bubbleView.layer.borderColor = UIColor.clear.cgColor
        }

        // --- Timestamp ---
        if let ts = message.createdAt {
            timestampLabel.text    = formatTimestamp(ts)
            timestampLabel.isHidden = false
        } else {
            timestampLabel.isHidden = true
        }

        // --- Attachment grid ---
        if !message.attachments.isEmpty {
            attachmentGridView.configure(with: message.attachments)
            attachmentGridView.isHidden = false
            // Keep bubble at same max width as text messages
            bubbleWidthConstraint.isActive = false
            bubbleWidthConstraint = bubbleView.widthAnchor.constraint(
                equalTo: contentView.widthAnchor, multiplier: 0.85
            )
            bubbleWidthConstraint.isActive = true
        } else {
            attachmentGridView.isHidden = true
        }
    }

    // MARK: - Segmented content rendering

    /// Splits `rawText` into text/table segments and renders each in order into the bubble stack.
    /// When `cachedSegments` is provided the expensive `MarkdownContentSplitter.split()` call is
    /// skipped. When `cachedColumnWidths` is provided each table skips `calculateColumnWidths()`.
    private func renderSegmentedContent(
        _ rawText: String,
        cachedSegments: [MessageContentSegment]? = nil,
        cachedColumnWidths: [[CGFloat]]? = nil,
        cachedRenderedText: [NSAttributedString?]? = nil,
        cachedTableImages: [UIImage]? = nil
    ) {
        let segments = cachedSegments ?? MarkdownContentSplitter.split(rawText)

        // Insert all segments in order directly before prCardView.
        // The first .text segment reuses the existing messageTextView (position 0 in stack).
        // Every subsequent segment — whether text or table — is a new view inserted after
        // the previous one, preserving exact document order.

        let prCardIndex = bubbleStack.arrangedSubviews.firstIndex(of: prCardView) ?? bubbleStack.arrangedSubviews.count
        // We'll track where the *next* new view should be inserted (just before prCardView initially)
        var nextInsertIndex = prCardIndex

        var usedMessageTextView = false
        var tableSegmentIndex = 0

        for (segmentIndex, segment) in segments.enumerated() {
            switch segment {
            case .text(let txt):
                // Use pre-rendered attributed string when available — avoids regex on main thread
                let mutable: NSMutableAttributedString
                if let preRendered = cachedRenderedText?[segmentIndex] {
                    mutable = NSMutableAttributedString(attributedString: preRendered)
                } else {
                    let rendered = FeatureChatMessageCell.markdownRenderer.render(txt)
                    mutable = NSMutableAttributedString(attributedString: rendered)
                    mutable.enumerateAttribute(.foregroundColor, in: NSRange(location: 0, length: mutable.length)) { value, range, _ in
                        if let color = value as? UIColor, color == UIColor.Sphinx.Text {
                            mutable.addAttribute(.foregroundColor, value: UIColor.Sphinx.TextMessages, range: range)
                        }
                    }
                }

                if !usedMessageTextView {
                    // Reuse the pre-existing messageTextView for the first text segment
                    messageTextView.attributedText = mutable
                    messageTextView.isHidden = txt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    usedMessageTextView = true
                    // messageTextView is already in the stack at index 0 — nextInsertIndex stays
                    // pointing after it only if we need to insert something before prCardView
                } else {
                    // Create an additional text view for subsequent text segments
                    let tv = UITextView()
                    tv.translatesAutoresizingMaskIntoConstraints = false
                    tv.isEditable = false
                    tv.isScrollEnabled = false
                    tv.isSelectable = true
                    tv.backgroundColor = .clear
                    tv.textContainerInset = UIEdgeInsets(top: 6, left: 8, bottom: 6, right: 8)
                    tv.textContainer.lineFragmentPadding = 0
                    tv.linkTextAttributes = [
                        .foregroundColor: UIColor.Sphinx.PrimaryBlue,
                        .underlineStyle: NSUnderlineStyle.single.rawValue
                    ]
                    tv.attributedText = mutable
                    tv.isHidden = txt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    bubbleStack.insertArrangedSubview(tv, at: nextInsertIndex)
                    nextInsertIndex += 1
                    activeSegmentViews.append(tv)
                }

            case .table(let headers, let rows):
                if !usedMessageTextView {
                    messageTextView.isHidden = true
                    usedMessageTextView = true
                }
                let tableView = MarkdownTableView()
                // Fast path: use pre-rendered UIImage (zero view creation, just imageView.image =)
                if let images = cachedTableImages, tableSegmentIndex < images.count,
                   let widths = cachedColumnWidths, tableSegmentIndex < widths.count {
                    let tableW = widths[tableSegmentIndex].reduce(0, +)
                    let tableH = CGFloat(rows.count + 1) * 36
                    tableView.configure(image: images[tableSegmentIndex], tableWidth: tableW, tableHeight: tableH)
                } else if let widths = cachedColumnWidths, tableSegmentIndex < widths.count {
                    tableView.configure(headers: headers, rows: rows, precomputedColumnWidths: widths[tableSegmentIndex])
                } else {
                    tableView.configure(headers: headers, rows: rows)
                }
                tableSegmentIndex += 1
                tableView.heightAnchor.constraint(equalToConstant: tableView.intrinsicContentHeight).isActive = true
                bubbleStack.insertArrangedSubview(tableView, at: nextInsertIndex)
                nextInsertIndex += 1
                activeTableViews.append(tableView)
                activeSegmentViews.append(tableView)

                // Post-table spacer so content after the table has clear visual separation
                let spacer = UIView()
                spacer.translatesAutoresizingMaskIntoConstraints = false
                spacer.backgroundColor = .clear
                spacer.heightAnchor.constraint(equalToConstant: 8).isActive = true
                bubbleStack.insertArrangedSubview(spacer, at: nextInsertIndex)
                nextInsertIndex += 1
                activeSegmentViews.append(spacer)
            }
        }

        // If no segments at all, hide the text view
        if segments.isEmpty {
            messageTextView.isHidden = true
        }

        // Notify host table view to recalculate row height
        if !activeTableViews.isEmpty {
            onHeightChanged?()
        }
    }

    // MARK: - Logs helpers

    /// Configures the logs header button and body text view based on current expand state.
    private func configureLogsViews() {
        // Hide the regular message text view — logs use dedicated views
        messageTextView.isHidden = true

        // Header
        let title = isLogsExpanded ? "Logs (tap to collapse)" : "Logs (tap to expand)"
        logsHeaderButton.setTitle(title, for: .normal)
        logsHeaderButton.isHidden = false

        // Body
        if isLogsExpanded, let content = currentLogsContent {
            logsBodyTextView.attributedText = makeLogsBodyAttributedString(content: content)
            logsBodyTextView.isHidden = false
        } else {
            logsBodyTextView.isHidden = true
        }
    }

    @objc private func logsHeaderTapped() {
        isLogsExpanded.toggle()
        configureLogsViews()
        onHeightChanged?()
    }

    private func makeLogsBodyAttributedString(content: String) -> NSAttributedString {
        let style = FeatureChatMessageCell.markdownRenderer.style
        let codeAttrs: [NSAttributedString.Key: Any] = [
            .font: style.codeFont,
            .foregroundColor: style.codeForeground,
            .backgroundColor: style.codeBackground
        ]
        let paddedLines = content.components(separatedBy: "\n").map { "  \($0)  " }
        let padded = paddedLines.joined(separator: "\n")
        return NSAttributedString(string: padded, attributes: codeAttrs)
    }

    // MARK: - Helpers

    private func formatTimestamp(_ timestamp: String) -> String {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = iso.date(from: timestamp)
        if date == nil {
            iso.formatOptions = [.withInternetDateTime]
            date = iso.date(from: timestamp)
        }
        guard let d = date else { return timestamp }
        let fmt = DateFormatter()
        fmt.dateFormat = "h:mm a"
        return fmt.string(from: d)
    }

    // MARK: - Link tap coordinator (shared, stateless)
    private class LinkTapCoordinator: NSObject, UITextViewDelegate {
        static let shared = LinkTapCoordinator()
        func textView(_ textView: UITextView,
                      shouldInteractWith url: URL,
                      in characterRange: NSRange,
                      interaction: UITextItemInteraction) -> Bool {
            let urlString = url.absoluteString
            if urlString.isHivePlanLink || urlString.isHiveTaskLink {
                if let topVC = UIApplication.shared.topMostViewController() {
                    HiveLinkNavigator.navigate(hiveLink: urlString, from: topVC)
                }
            } else {
                UIApplication.shared.open(url)
            }
            return false
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        // Remove any dynamically inserted segment views (extra text views + table views)
        activeSegmentViews.forEach { $0.removeFromSuperview() }
        activeSegmentViews.removeAll()
        activeTableViews.removeAll()

        // Reset logs state
        isLogsExpanded = false
        currentLogsContent = nil
        logsHeaderButton.isHidden = true
        logsHeaderButton.setTitle("Logs (tap to expand)", for: .normal)
        logsBodyTextView.isHidden = true
        logsBodyTextView.attributedText = nil

        messageTextView.attributedText = nil
        messageTextView.isHidden = false
        messageTextView.textContainerInset = UIEdgeInsets(top: 10, left: 8, bottom: 10, right: 8)
        prCardView.isHidden = true
        onHeightChanged = nil
        attachmentGridView.reset()
        attachmentGridView.isHidden = true
        onAttachmentTap = nil
        bubbleView.layer.cornerRadius = 18
        timestampLabel.text    = nil
        timestampLabel.isHidden = false
        senderAvatarImageView.isHidden = true
        senderAvatarImageView.sd_cancelCurrentImageLoad()
        senderAvatarImageView.image = UIImage(named: "profile_avatar")
        bubbleLeadingConstraint.isActive  = false
        bubbleTrailingConstraint.isActive = false
        bubbleTrailingConstraintSent.isActive = false
        timestampLeadingConstraint.isActive  = false
        timestampTrailingConstraint.isActive = false
        // Reset bubble width to default
        bubbleWidthConstraint.isActive = false
        bubbleWidthConstraint = bubbleView.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: 0.85)
        bubbleWidthConstraint.isActive = true
        // Reset corner masking to full
        bubbleView.layer.maskedCorners = [
            .layerMinXMinYCorner, .layerMaxXMinYCorner,
            .layerMinXMaxYCorner, .layerMaxXMaxYCorner
        ]
        bubbleView.layer.masksToBounds = true
        bubbleView.layer.borderWidth = 0
        bubbleView.layer.borderColor = UIColor.clear.cgColor
        textBackgroundView.backgroundColor = .clear
    }
}
