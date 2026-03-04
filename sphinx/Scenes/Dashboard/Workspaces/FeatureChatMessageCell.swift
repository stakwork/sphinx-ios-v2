//
//  FeatureChatMessageCell.swift
//  sphinx
//
//  Created on 2025-02-26.
//  Copyright © 2025 sphinx. All rights reserved.
//

import UIKit

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

    private let timestampLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont(name: "Roboto-Regular", size: 11)
        label.textColor = UIColor.Sphinx.SecondaryText
        return label
    }()

    // MARK: - Alignment constraints (toggled per message role)
    private var bubbleLeadingConstraint: NSLayoutConstraint!
    private var bubbleTrailingConstraint: NSLayoutConstraint!
    private var timestampLeadingConstraint: NSLayoutConstraint!
    private var timestampTrailingConstraint: NSLayoutConstraint!

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
        bubbleView.addSubview(bubbleStack)
        contentView.addSubview(timestampLabel)

        bubbleLeadingConstraint  = bubbleView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16)
        bubbleTrailingConstraint = bubbleView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)

        timestampLeadingConstraint  = timestampLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor)
        timestampTrailingConstraint = timestampLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor)

        NSLayoutConstraint.activate([
            bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            bubbleView.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: 0.85),
            bubbleStack.topAnchor.constraint(equalTo: bubbleView.topAnchor),
            bubbleStack.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor),
            bubbleStack.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor),
            bubbleStack.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor),
            timestampLabel.topAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: 4),
            timestampLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
        ])
    }

    // MARK: - Configure
    func configure(with message: HiveChatMessage) {
        let isUser = message.isUserMessage

        // --- Text content ---
        if isUser {
            let font = UIFont(name: "Roboto-Regular", size: 15) ?? UIFont.systemFont(ofSize: 15)
            messageTextView.attributedText = NSAttributedString(
                string: message.message,
                attributes: [.font: font, .foregroundColor: UIColor.Sphinx.TextMessages]
            )
            bubbleView.backgroundColor      = UIColor.Sphinx.SentMsgBG
            timestampLabel.textColor        = UIColor.Sphinx.SecondaryTextSent
            timestampLabel.textAlignment    = .right
            bubbleLeadingConstraint.isActive  = false

            bubbleTrailingConstraint.isActive = true
            timestampLeadingConstraint.isActive  = false
            timestampTrailingConstraint.isActive = true
        } else {
            let rendered = FeatureChatMessageCell.markdownRenderer.render(message.message)
            let mutable  = NSMutableAttributedString(attributedString: rendered)
            // Swap base text colour to match the bubble's text style
            mutable.enumerateAttribute(.foregroundColor, in: NSRange(location: 0, length: mutable.length)) { value, range, _ in
                if let color = value as? UIColor, color == UIColor.Sphinx.Text {
                    mutable.addAttribute(.foregroundColor, value: UIColor.Sphinx.TextMessages, range: range)
                }
            }
            messageTextView.attributedText = mutable
            bubbleView.backgroundColor      = UIColor.Sphinx.ReceivedMsgBG
            timestampLabel.textColor        = UIColor.Sphinx.SecondaryText
            timestampLabel.textAlignment    = .left
            bubbleTrailingConstraint.isActive = false
            bubbleLeadingConstraint.isActive  = true
            timestampTrailingConstraint.isActive = false
            timestampLeadingConstraint.isActive  = true
        }

        // --- PR artifact card ---
        if let prArtifact = message.artifacts.first(where: { $0.isPullRequest }),
           let prContent = prArtifact.prContent {
            prCardView.configure(with: prContent)
            prCardView.isHidden = false
            // Round only top corners of bubble when card is appended at bottom
            bubbleView.layer.cornerRadius = 18
        } else {
            prCardView.isHidden = true
        }

        // --- Clarifying questions ---
        if let cqArtifact = message.artifacts.first(where: { $0.isClarifyingQuestions }),
           let questions = cqArtifact.clarifyingQuestions, !questions.isEmpty {
            clarifyingQuestionsView.configure(with: questions)
            clarifyingQuestionsView.isHidden = false
            clarifyingQuestionsView.onSubmit = { [weak self] answers in
                self?.onClarifyingAnswerSubmit?(answers, message.id)
            }
            // Hide the text bubble entirely — no text to show, and we don't want
            // its top/bottom insets bleeding as empty space above/below the card.
            messageTextView.isHidden = true
            messageTextView.textContainerInset = .zero
            bubbleView.backgroundColor = .clear
            bubbleView.layer.cornerRadius = 0
        } else {
            clarifyingQuestionsView.isHidden = true
            messageTextView.isHidden = false
            messageTextView.textContainerInset = UIEdgeInsets(top: 10, left: 8, bottom: 10, right: 8)
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
        bubbleView.layer.cornerRadius = 18
        timestampLabel.text    = nil
        timestampLabel.isHidden = false
        bubbleLeadingConstraint.isActive  = false
        bubbleTrailingConstraint.isActive = false
        timestampLeadingConstraint.isActive  = false
        timestampTrailingConstraint.isActive = false
    }
}
