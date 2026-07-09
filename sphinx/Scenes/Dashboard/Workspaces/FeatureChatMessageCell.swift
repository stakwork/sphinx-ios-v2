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

    /// Publish script card — only shown when a PUBLISH_SCRIPT artifact is present.
    private let publishScriptCardView: PublishScriptCardView = {
        let v = PublishScriptCardView()
        v.isHidden = true
        return v
    }()

    /// Publish workflow card — only shown when a PUBLISH_WORKFLOW artifact is present.
    private let publishWorkflowCardView: PublishWorkflowCardView = {
        let v = PublishWorkflowCardView()
        v.isHidden = true
        return v
    }()

    /// Publish prompt card — only shown when a PUBLISH_PROMPT artifact is present.
    private let publishPromptCardView: PublishPromptCardView = {
        let v = PublishPromptCardView()
        v.isHidden = true
        return v
    }()

    /// Retains the current PUBLISH_SCRIPT artifact for closure bridging.
    private var currentPublishScriptArtifact: HiveChatMessageArtifact?

    /// Retains the current PUBLISH_WORKFLOW artifact for closure bridging.
    private var currentPublishWorkflowArtifact: HiveChatMessageArtifact?

    /// Retains the current PUBLISH_PROMPT artifact for closure bridging.
    private var currentPublishPromptArtifact: HiveChatMessageArtifact?

    // MARK: - Callbacks

    /// Called when the clarifying questions view changes its content height
    /// (e.g. navigating between questions) so the host table view can recalculate row height.
    var onHeightChanged: (() -> Void)?

    /// Called when the user taps an attachment tile.
    var onAttachmentTap: ((HiveChatMessageAttachment) -> Void)? {
        didSet { attachmentGridView.onTapAttachment = onAttachmentTap }
    }

    /// Called when the user taps "Publish" on the publish script card.
    var onPublishScriptTapped: ((_ artifact: HiveChatMessageArtifact) -> Void)?
    /// Called when the user taps the version badge on the publish script card.
    var onOpenScriptVersionTapped: ((_ artifact: HiveChatMessageArtifact) -> Void)?
    /// Called when the user taps "Publish" on the publish workflow card.
    var onPublishWorkflowTapped: ((_ artifact: HiveChatMessageArtifact) -> Void)?
    /// Called when the user taps "Publish" on the publish prompt card.
    var onPublishPromptTapped: ((_ artifact: HiveChatMessageArtifact) -> Void)?
    /// Called when the user taps the version row / external-link on the publish prompt card.
    var onOpenPromptVersionTapped: ((_ artifact: HiveChatMessageArtifact) -> Void)?

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

    // MARK: - Suggestion chips
    private let suggestionChipsView = SuggestionChipsView()
    private var chipsTopConstraint:      NSLayoutConstraint!
    private var chipsLeadingConstraint:  NSLayoutConstraint!
    private var chipsTrailingConstraint: NSLayoutConstraint!
    private var chipsBottomConstraint:   NSLayoutConstraint!

    var onSuggestionTapped: ((String) -> Void)? {
        didSet { suggestionChipsView.onChipTapped = onSuggestionTapped }
    }

    // MARK: - Alignment constraints (toggled per message role)
    private var bubbleLeadingConstraint: NSLayoutConstraint!
    private var bubbleTrailingConstraint: NSLayoutConstraint!
    private var bubbleTrailingConstraintSent: NSLayoutConstraint!
    private var timestampLeadingConstraint: NSLayoutConstraint!
    private var timestampTrailingConstraint: NSLayoutConstraint!
    private var bubbleWidthConstraint: NSLayoutConstraint!
    private var timestampBottomConstraint: NSLayoutConstraint!

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

        // Vertical stack inside bubble: text + logs header + logs body + optional PR card + optional publish script/workflow/prompt card + optional attachment grid
        bubbleStack = UIStackView(arrangedSubviews: [messageTextView, logsHeaderButton, logsBodyTextView, prCardView, publishScriptCardView, publishWorkflowCardView, publishPromptCardView, attachmentGridView])
        bubbleStack.translatesAutoresizingMaskIntoConstraints = false
        bubbleStack.axis = .vertical
        bubbleStack.spacing = 0
        bubbleStack.isLayoutMarginsRelativeArrangement = true

        contentView.addSubview(bubbleView)
        bubbleView.insertSubview(textBackgroundView, belowSubview: bubbleStack)
        bubbleView.addSubview(bubbleStack)
        contentView.addSubview(timestampLabel)
        contentView.addSubview(senderAvatarImageView)
        contentView.addSubview(suggestionChipsView)

        bubbleLeadingConstraint  = bubbleView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16)
        bubbleTrailingConstraint = bubbleView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        // -36 = avatar(20) + gap(8) + right margin(8)
        bubbleTrailingConstraintSent = bubbleView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -36)

        timestampLeadingConstraint  = timestampLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor)
        timestampTrailingConstraint = timestampLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor)

        bubbleWidthConstraint = bubbleView.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: 0.85)

        timestampBottomConstraint = timestampLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4)

        chipsTopConstraint      = suggestionChipsView.topAnchor.constraint(equalTo: timestampLabel.bottomAnchor, constant: 6)
        chipsLeadingConstraint  = suggestionChipsView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16)
        chipsTrailingConstraint = suggestionChipsView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        chipsBottomConstraint   = suggestionChipsView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8)
        // Chip constraints are NOT activated here — toggled in configure/prepareForReuse

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
            timestampBottomConstraint,
            // textBackgroundView covers only the text area (top of bubble → bottom of text view)
            textBackgroundView.topAnchor.constraint(equalTo: bubbleView.topAnchor),
            textBackgroundView.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor),
            textBackgroundView.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor),
            textBackgroundView.bottomAnchor.constraint(equalTo: messageTextView.bottomAnchor),
        ])
    }

    // MARK: - Configure
    func configure(with message: HiveChatMessage, isLastMessage: Bool = false, italicText: String? = nil, suggestions: [String] = []) {
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
                renderSegmentedContent(message.resolvedDisplayText)
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
                renderSegmentedContent(message.resolvedDisplayText)
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
            configureBottomJoinedCard(isUser: isUser, bottomCard: prCardView)
        } else {
            prCardView.isHidden = true
        }

        // --- Publish Script / Publish Workflow / Publish Prompt artifact cards ---
        // A message carries at most one of these; precedence order is script → workflow → prompt.
        let psArtifact = message.artifacts.first(where: { $0.isPublishScript })
        let pwArtifact = message.artifacts.first(where: { $0.isPublishWorkflow })
        let ppArtifact = message.artifacts.first(where: { $0.isPublishPrompt })

        if let psArtifact, let psContent = psArtifact.publishScriptContent {
            // Publish Script card
            currentPublishScriptArtifact = psArtifact
            publishScriptCardView.configure(with: psContent)
            publishScriptCardView.isHidden = false
            publishWorkflowCardView.isHidden = true
            currentPublishWorkflowArtifact = nil
            publishPromptCardView.isHidden = true
            currentPublishPromptArtifact = nil
            publishPromptCardView.onPublishTapped = nil
            publishPromptCardView.onOpenVersionTapped = nil
            configureBottomJoinedCard(isUser: isUser, bottomCard: publishScriptCardView)
            publishScriptCardView.onPublishTapped = { [weak self] in
                guard let self, let artifact = self.currentPublishScriptArtifact else { return }
                self.onPublishScriptTapped?(artifact)
            }
            publishScriptCardView.onOpenVersionTapped = { [weak self] in
                guard let self, let artifact = self.currentPublishScriptArtifact else { return }
                self.onOpenScriptVersionTapped?(artifact)
            }
        } else if let pwArtifact, let pwContent = pwArtifact.publishWorkflowContent {
            // Publish Workflow card
            currentPublishWorkflowArtifact = pwArtifact
            publishWorkflowCardView.configure(with: pwContent)
            publishWorkflowCardView.isHidden = false
            publishScriptCardView.isHidden = true
            currentPublishScriptArtifact = nil
            publishPromptCardView.isHidden = true
            currentPublishPromptArtifact = nil
            publishPromptCardView.onPublishTapped = nil
            publishPromptCardView.onOpenVersionTapped = nil
            configureBottomJoinedCard(isUser: isUser, bottomCard: publishWorkflowCardView)
            publishWorkflowCardView.onPublishTapped = { [weak self] in
                guard let self, let artifact = self.currentPublishWorkflowArtifact else { return }
                self.onPublishWorkflowTapped?(artifact)
            }
        } else if let ppArtifact, let ppContent = ppArtifact.publishPromptContent {
            // Publish Prompt card
            currentPublishPromptArtifact = ppArtifact
            publishPromptCardView.configure(with: ppContent)
            publishPromptCardView.isHidden = false
            publishScriptCardView.isHidden = true
            currentPublishScriptArtifact = nil
            publishScriptCardView.onPublishTapped = nil
            publishScriptCardView.onOpenVersionTapped = nil
            publishWorkflowCardView.isHidden = true
            currentPublishWorkflowArtifact = nil
            publishWorkflowCardView.onPublishTapped = nil
            configureBottomJoinedCard(isUser: isUser, bottomCard: publishPromptCardView)
            publishPromptCardView.onPublishTapped = { [weak self] in
                guard let self, let artifact = self.currentPublishPromptArtifact else { return }
                self.onPublishPromptTapped?(artifact)
            }
            publishPromptCardView.onOpenVersionTapped = { [weak self] in
                guard let self, let artifact = self.currentPublishPromptArtifact else { return }
                self.onOpenPromptVersionTapped?(artifact)
            }
        } else {
            // No publish card — hide all three, clear state
            publishScriptCardView.isHidden = true
            publishWorkflowCardView.isHidden = true
            publishPromptCardView.isHidden = true
            currentPublishScriptArtifact = nil
            currentPublishWorkflowArtifact = nil
            currentPublishPromptArtifact = nil
            publishScriptCardView.onPublishTapped = nil
            publishScriptCardView.onOpenVersionTapped = nil
            publishWorkflowCardView.onPublishTapped = nil
            publishPromptCardView.onPublishTapped = nil
            publishPromptCardView.onOpenVersionTapped = nil
            // Only restore default bubble geometry when there's also no PR card.
            // If a PR card is present it already called configureBottomJoinedCard above.
            if message.artifacts.first(where: { $0.isPullRequest }) == nil {
                restoreDefaultBubbleGeometry()
            }
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

        // --- Suggestion chips ---
        let showChips = !message.isUserMessage && !suggestions.isEmpty
        if showChips {
            suggestionChipsView.configure(with: suggestions)
            timestampBottomConstraint.isActive  = false
            chipsTopConstraint.isActive         = true
            chipsLeadingConstraint.isActive     = true
            chipsTrailingConstraint.isActive    = true
            chipsBottomConstraint.isActive      = true
        } else {
            suggestionChipsView.clear()
            chipsTopConstraint.isActive         = false
            chipsLeadingConstraint.isActive     = false
            chipsTrailingConstraint.isActive    = false
            chipsBottomConstraint.isActive      = false
            timestampBottomConstraint.isActive  = true
        }
        onHeightChanged?()
    }

    // MARK: - Segmented content rendering

    /// Splits `rawText` into text/table segments and renders each in order into the bubble stack.
    private func renderSegmentedContent(_ rawText: String) {
        let segments = MarkdownContentSplitter.split(rawText)

        // Insert all segments in order directly before prCardView.
        // The first .text segment reuses the existing messageTextView (position 0 in stack).
        // Every subsequent segment — whether text or table — is a new view inserted after
        // the previous one, preserving exact document order.

        let prCardIndex = bubbleStack.arrangedSubviews.firstIndex(of: prCardView) ?? bubbleStack.arrangedSubviews.count
        // We'll track where the *next* new view should be inserted (just before prCardView initially)
        var nextInsertIndex = prCardIndex

        var usedMessageTextView = false

        for segment in segments {
            switch segment {
            case .text(let txt):
                let rendered = FeatureChatMessageCell.markdownRenderer.render(txt)
                let mutable = NSMutableAttributedString(attributedString: rendered)
                mutable.enumerateAttribute(.foregroundColor, in: NSRange(location: 0, length: mutable.length)) { value, range, _ in
                    if let color = value as? UIColor, color == UIColor.Sphinx.Text {
                        mutable.addAttribute(.foregroundColor, value: UIColor.Sphinx.TextMessages, range: range)
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
                    // No text segment came before this table — hide the messageTextView
                    messageTextView.isHidden = true
                    usedMessageTextView = true
                }
                let tableView = MarkdownTableView()
                tableView.configure(headers: headers, rows: rows)
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

    // MARK: - Bottom-joined card geometry helpers

    /// Applies the shared bubble layout for any bottom-joined card (PR, Publish Script, Publish Workflow).
    /// Expands bubble to 60%, disables masksToBounds on bubbleView, moves colour to textBackgroundView
    /// (top-corners only), and rounds only the bottom corners of the given card view.
    private func configureBottomJoinedCard(isUser: Bool, bottomCard: UIView) {
        bubbleWidthConstraint.isActive = false
        bubbleWidthConstraint = bubbleView.widthAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: 0.60)
        bubbleWidthConstraint.isActive = true

        bubbleView.layer.cornerRadius = 18
        bubbleView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        bubbleView.layer.masksToBounds = false
        bubbleView.backgroundColor = .clear

        let roleColour: UIColor = isUser ? UIColor.Sphinx.SentMsgBG : UIColor.Sphinx.ReceivedMsgBG
        textBackgroundView.backgroundColor = roleColour
        textBackgroundView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        textBackgroundView.layer.masksToBounds = true

        bottomCard.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        bottomCard.layer.masksToBounds = true
    }

    /// Restores the default bubble geometry (no bottom-joined card present).
    private func restoreDefaultBubbleGeometry() {
        bubbleWidthConstraint.isActive = false
        bubbleWidthConstraint = bubbleView.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: 0.85)
        bubbleWidthConstraint.isActive = true

        bubbleView.layer.maskedCorners = [
            .layerMinXMinYCorner, .layerMaxXMinYCorner,
            .layerMinXMaxYCorner, .layerMaxXMaxYCorner
        ]
        bubbleView.layer.masksToBounds = true
        textBackgroundView.backgroundColor = .clear
    }

    // MARK: - Publish Script helpers

    /// Flips the publish script card to the "Published ✓" state in-place without a full reload.
    func flipPublishScriptToPublished() {
        publishScriptCardView.setPublished(true)
    }

    // MARK: - Publish Workflow helpers

    /// Flips the publish workflow card to the "Published ✓" state in-place without a full reload.
    func flipPublishWorkflowToPublished() {
        publishWorkflowCardView.setPublished(true)
    }

    // MARK: - Publish Prompt helpers

    /// Flips the publish prompt card to the "Published ✓" state in-place without a full reload.
    func flipPublishPromptToPublished() {
        publishPromptCardView.setPublished(true)
    }

    // MARK: - Test seams (DEBUG only)
    #if DEBUG
    var _publishPromptCardViewIsHidden: Bool { publishPromptCardView.isHidden }
    var _publishScriptCardViewIsHidden: Bool { publishScriptCardView.isHidden }
    var _publishWorkflowCardViewIsHidden: Bool { publishWorkflowCardView.isHidden }
    var _currentPublishPromptArtifact: HiveChatMessageArtifact? { currentPublishPromptArtifact }
    var _publishPromptCardView: PublishPromptCardView { publishPromptCardView }
    #endif

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
        publishScriptCardView.isHidden = true
        publishScriptCardView.onPublishTapped = nil
        publishScriptCardView.onOpenVersionTapped = nil
        publishScriptCardView.layer.maskedCorners = [
            .layerMinXMinYCorner, .layerMaxXMinYCorner,
            .layerMinXMaxYCorner, .layerMaxXMaxYCorner
        ]
        publishScriptCardView.layer.masksToBounds = true
        currentPublishScriptArtifact = nil
        onPublishScriptTapped = nil
        onOpenScriptVersionTapped = nil
        publishWorkflowCardView.isHidden = true
        publishWorkflowCardView.onPublishTapped = nil
        publishWorkflowCardView.layer.maskedCorners = [
            .layerMinXMinYCorner, .layerMaxXMinYCorner,
            .layerMinXMaxYCorner, .layerMaxXMaxYCorner
        ]
        publishWorkflowCardView.layer.masksToBounds = true
        currentPublishWorkflowArtifact = nil
        onPublishWorkflowTapped = nil
        publishPromptCardView.isHidden = true
        publishPromptCardView.onPublishTapped = nil
        publishPromptCardView.onOpenVersionTapped = nil
        publishPromptCardView.layer.maskedCorners = [
            .layerMinXMinYCorner, .layerMaxXMinYCorner,
            .layerMinXMaxYCorner, .layerMaxXMaxYCorner
        ]
        publishPromptCardView.layer.masksToBounds = true
        currentPublishPromptArtifact = nil
        onPublishPromptTapped = nil
        onOpenPromptVersionTapped = nil
        suggestionChipsView.clear()
        chipsTopConstraint.isActive         = false
        chipsLeadingConstraint.isActive     = false
        chipsTrailingConstraint.isActive    = false
        chipsBottomConstraint.isActive      = false
        timestampBottomConstraint.isActive  = true
        onSuggestionTapped = nil
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
