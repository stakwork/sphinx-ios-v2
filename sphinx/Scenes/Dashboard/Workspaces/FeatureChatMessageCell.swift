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
        tv.backgroundColor = .clear
        tv.textContainerInset = UIEdgeInsets(top: 10, left: 8, bottom: 10, right: 8)
        tv.textContainer.lineFragmentPadding = 0
        return tv
    }()

    /// PR artifact card — only shown when a PULL_REQUEST artifact is present.
    private let prCardView: PRArtifactCardView = {
        let v = PRArtifactCardView()
        v.isHidden = true
        return v
    }()

    /// Clarifying questions view — only shown when a PLAN/ask_clarifying_questions artifact is present.
    private let clarifyingQuestionsView: ClarifyingQuestionsView = {
        let v = ClarifyingQuestionsView()
        v.isHidden = true
        return v
    }()

    // MARK: - Callbacks

    /// Set by the view controller; called when the user submits clarifying answers.
    var onClarifyingAnswerSubmit: ((_ answers: [String], _ replyId: String) -> Void)?

    /// Called when the clarifying questions view changes its content height
    /// (e.g. navigating between questions) so the host table view can recalculate row height.
    var onHeightChanged: (() -> Void)?

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
        iv.layer.cornerRadius = 16
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

        // Vertical stack inside bubble: text + optional PR card + optional clarifying questions
        let bubbleStack = UIStackView(arrangedSubviews: [messageTextView, prCardView, clarifyingQuestionsView])
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
        bubbleTrailingConstraintSent = bubbleView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -56)

        timestampLeadingConstraint  = timestampLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor)
        timestampTrailingConstraint = timestampLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor)

        bubbleWidthConstraint = bubbleView.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: 0.85)

        NSLayoutConstraint.activate([
            senderAvatarImageView.widthAnchor.constraint(equalToConstant: 32),
            senderAvatarImageView.heightAnchor.constraint(equalToConstant: 32),
            senderAvatarImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            senderAvatarImageView.centerYAnchor.constraint(equalTo: bubbleView.centerYAnchor),
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
    func configure(with message: HiveChatMessage, isLastMessage: Bool = false) {
        let isUser = message.isUserMessage

        // --- Text content ---
        if isUser {
            let rendered = FeatureChatMessageCell.markdownRenderer.render(message.resolvedDisplayText)
            let mutable  = NSMutableAttributedString(attributedString: rendered)
            mutable.enumerateAttribute(.foregroundColor, in: NSRange(location: 0, length: mutable.length)) { value, range, _ in
                if let color = value as? UIColor, color == UIColor.Sphinx.Text {
                    mutable.addAttribute(.foregroundColor, value: UIColor.Sphinx.TextMessages, range: range)
                }
            }
            messageTextView.attributedText = mutable
            // Fix 3: hide text view when message body is blank
            let hasText = !message.resolvedDisplayText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            messageTextView.isHidden = !hasText
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
            let rendered = FeatureChatMessageCell.markdownRenderer.render(message.resolvedDisplayText)
            let mutable  = NSMutableAttributedString(attributedString: rendered)
            // Swap base text colour to match the bubble's text style
            mutable.enumerateAttribute(.foregroundColor, in: NSRange(location: 0, length: mutable.length)) { value, range, _ in
                if let color = value as? UIColor, color == UIColor.Sphinx.Text {
                    mutable.addAttribute(.foregroundColor, value: UIColor.Sphinx.TextMessages, range: range)
                }
            }
            messageTextView.attributedText = mutable
            // Fix 3: hide text view when message body is blank
            let hasText = !message.resolvedDisplayText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            messageTextView.isHidden = !hasText
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

        // --- Clarifying questions ---
        if let cqArtifact = message.artifacts.first(where: { $0.isClarifyingQuestions }),
           let questions = cqArtifact.clarifyingQuestions, !questions.isEmpty {
            clarifyingQuestionsView.configure(with: questions)
            if isLastMessage {
                clarifyingQuestionsView.isUserInteractionEnabled = true
                clarifyingQuestionsView.alpha = 1.0
            } else {
                clarifyingQuestionsView.lock()
            }
            clarifyingQuestionsView.isHidden = false
            clarifyingQuestionsView.onSubmit = { [weak self] answers in
                self?.onClarifyingAnswerSubmit?(answers, message.id)
            }
            clarifyingQuestionsView.onHeightChanged = { [weak self] in
                self?.onHeightChanged?()
            }
            // Hide the text bubble entirely — no text to show, and we don't want
            // its top/bottom insets bleeding as empty space above/below the card.
            messageTextView.isHidden = true
            messageTextView.textContainerInset = .zero
            bubbleView.backgroundColor = .clear
            bubbleView.layer.cornerRadius = 0
        } else {
            clarifyingQuestionsView.isHidden = true
            // Derive hasText the same way Fix 3 does — don't override its decision
            let hasText: Bool
            if isUser {
                hasText = !message.resolvedDisplayText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            } else {
                hasText = !message.resolvedDisplayText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            messageTextView.isHidden = !hasText
            messageTextView.textContainerInset = hasText
                ? UIEdgeInsets(top: 10, left: 8, bottom: 10, right: 8)
                : .zero
        }

        // --- Timestamp ---
        if let ts = message.createdAt {
            timestampLabel.text    = formatTimestamp(ts)
            timestampLabel.isHidden = false
        } else {
            timestampLabel.isHidden = true
        }
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

    /// Lock the clarifying questions view after successful submission.
    func lockClarifyingQuestionsView() {
        clarifyingQuestionsView.lock()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        
        messageTextView.attributedText = nil
        messageTextView.isHidden = false
        messageTextView.textContainerInset = UIEdgeInsets(top: 10, left: 8, bottom: 10, right: 8)
        prCardView.isHidden = true
        clarifyingQuestionsView.reset()
        clarifyingQuestionsView.isHidden = true
        onClarifyingAnswerSubmit = nil
        onHeightChanged = nil
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
