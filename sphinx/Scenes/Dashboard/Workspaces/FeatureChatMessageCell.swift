//
//  FeatureChatMessageCell.swift
//  sphinx
//
//  Created on 2025-02-26.
//  Copyright © 2025 sphinx. All rights reserved.
//

import UIKit

class FeatureChatMessageCell: UITableViewCell {
    
    // MARK: - UI Components
    private let bubbleView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = 18
        view.clipsToBounds = true
        return view
    }()
    
    private let messageLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.font = UIFont(name: "Roboto-Regular", size: 15)
        return label
    }()
    
    private let timestampLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont(name: "Roboto-Regular", size: 11)
        label.textColor = UIColor.Sphinx.SecondaryText
        return label
    }()
    
    // MARK: - Constraints
    private var bubbleLeadingConstraint: NSLayoutConstraint!
    private var bubbleTrailingConstraint: NSLayoutConstraint!
    
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
        backgroundColor = .clear
        selectionStyle = .none
        
        contentView.addSubview(bubbleView)
        bubbleView.addSubview(messageLabel)
        contentView.addSubview(timestampLabel)
        
        bubbleLeadingConstraint = bubbleView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16)
        bubbleTrailingConstraint = bubbleView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        
        NSLayoutConstraint.activate([
            bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            bubbleView.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: 0.75),
            
            messageLabel.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 10),
            messageLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 12),
            messageLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -12),
            messageLabel.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -10),
            
            timestampLabel.topAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: 4),
            timestampLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4)
        ])
    }
    
    // MARK: - Configuration
    func configure(with message: HiveChatMessage) {
        messageLabel.text = message.message
        
        if let timestamp = message.timestamp {
            timestampLabel.text = formatTimestamp(timestamp)
            timestampLabel.isHidden = false
        } else {
            timestampLabel.isHidden = true
        }
        
        if message.role == "user" {
            // User message: right-aligned, sent message styling
            bubbleView.backgroundColor = UIColor.Sphinx.SentMsgBG
            messageLabel.textColor = UIColor.Sphinx.TextMessages
            timestampLabel.textColor = UIColor.Sphinx.SecondaryTextSent
            
            bubbleLeadingConstraint.isActive = false
            bubbleTrailingConstraint.isActive = true
            
            timestampLabel.textAlignment = .right
            timestampLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor).isActive = true
        } else {
            // Assistant message: left-aligned, received message styling
            bubbleView.backgroundColor = UIColor.Sphinx.ReceivedMsgBG
            messageLabel.textColor = UIColor.Sphinx.TextMessages
            timestampLabel.textColor = UIColor.Sphinx.SecondaryText
            
            bubbleTrailingConstraint.isActive = false
            bubbleLeadingConstraint.isActive = true
            
            timestampLabel.textAlignment = .left
            timestampLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor).isActive = true
        }
    }
    
    // MARK: - Helper Methods
    private func formatTimestamp(_ timestamp: String) -> String {
        // Simple timestamp formatting
        // Expected format: ISO8601 string
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        
        guard let date = dateFormatter.date(from: timestamp) else {
            return timestamp
        }
        
        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "h:mm a"
        
        return outputFormatter.string(from: date)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        messageLabel.text = nil
        timestampLabel.text = nil
        timestampLabel.isHidden = false
    }
}
