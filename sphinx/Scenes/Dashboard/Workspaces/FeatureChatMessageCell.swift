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
        view.clipsToBounds = true
        return view
    }()

    /// UITextView replaces UILabel so NSAttributedString (markdown) renders correctly,
    /// including code blocks with background colour, bold, italic, links, etc.
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

    private let timestampLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont(name: "Roboto-Regular", size: 11)
        label.textColor = UIColor.Sphinx.SecondaryText
        return label
    }()

    // MARK: - Constraints (toggled per alignment)
    private var bubbleLeadingConstraint: NSLayoutConstraint!
    private var bubbleTrailingConstraint: NSLayoutConstraint!
    private var timestampLeadingConstraint: NSLayoutConstraint!
    private var timestampTrailingConstraint: NSLayoutConstraint!

    // MARK: - Initialization
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup
    private func setupUI() {
        backgroundColor = .Sphinx.Body
        contentView.backgroundColor = .Sphinx.Body
        selectionStyle = .none

        contentView.addSubview(bubbleView)
        bubbleView.addSubview(messageTextView)
        contentView.addSubview(timestampLabel)

        bubbleLeadingConstraint  = bubbleView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16)
        bubbleTrailingConstraint = bubbleView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)

        timestampLeadingConstraint  = timestampLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor)
        timestampTrailingConstraint = timestampLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor)

        NSLayoutConstraint.activate([
            bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            bubbleView.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: 0.80),

            messageTextView.topAnchor.constraint(equalTo: bubbleView.topAnchor),
            messageTextView.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 4),
            messageTextView.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -4),
            messageTextView.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor),

            timestampLabel.topAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: 4),
            timestampLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
        ])
    }

    // MARK: - Configuration
    func configure(with message: HiveChatMessage) {
        let isUser = message.isUserMessage

        if isUser {
            // User messages: plain text (no markdown needed), white text on blue bubble
            let font = UIFont(name: "Roboto-Regular", size: 15) ?? UIFont.systemFont(ofSize: 15)
            messageTextView.attributedText = NSAttributedString(
                string: message.message,
                attributes: [
                    .font: font,
                    .foregroundColor: UIColor.Sphinx.TextMessages
                ]
            )
            bubbleView.backgroundColor = UIColor.Sphinx.SentMsgBG
            timestampLabel.textColor    = UIColor.Sphinx.SecondaryTextSent
            timestampLabel.textAlignment = .right

            bubbleLeadingConstraint.isActive  = false
            bubbleTrailingConstraint.isActive = true
            timestampLeadingConstraint.isActive  = false
            timestampTrailingConstraint.isActive = true
        } else {
            // Assistant / Agent messages: render markdown
            let rendered = FeatureChatMessageCell.markdownRenderer.render(message.message)
            // Override foreground colour so it matches bubble text colour
            let mutable = NSMutableAttributedString(attributedString: rendered)
            mutable.enumerateAttribute(.foregroundColor, in: NSRange(location: 0, length: mutable.length)) { value, range, _ in
                // Only replace the base text colour (leave code-block colours untouched)
                if let color = value as? UIColor, color == UIColor.Sphinx.Text {
                    mutable.addAttribute(.foregroundColor, value: UIColor.Sphinx.TextMessages, range: range)
                }
            }
            messageTextView.attributedText = mutable
            bubbleView.backgroundColor = UIColor.Sphinx.ReceivedMsgBG
            timestampLabel.textColor    = UIColor.Sphinx.SecondaryText
            timestampLabel.textAlignment = .left

            bubbleTrailingConstraint.isActive = false
            bubbleLeadingConstraint.isActive  = true
            timestampTrailingConstraint.isActive = false
            timestampLeadingConstraint.isActive  = true
        }

        // Timestamp
        if let createdAt = message.createdAt {
            timestampLabel.text = formatTimestamp(createdAt)
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

    override func prepareForReuse() {
        super.prepareForReuse()
        messageTextView.attributedText = nil
        timestampLabel.text = nil
        timestampLabel.isHidden = false
        bubbleLeadingConstraint.isActive  = false
        bubbleTrailingConstraint.isActive = false
        timestampLeadingConstraint.isActive  = false
        timestampTrailingConstraint.isActive = false
    }
}
