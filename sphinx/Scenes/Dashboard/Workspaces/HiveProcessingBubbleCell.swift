//
//  HiveProcessingBubbleCell.swift
//  sphinx
//
//  Created on 2026-03-05.
//  Copyright © 2026 sphinx. All rights reserved.
//

import UIKit

class HiveProcessingBubbleCell: UITableViewCell {

    // MARK: - UI Elements

    private let bubbleView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.Sphinx.ReceivedMsgBG
        view.layer.cornerRadius = 18
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let hiveLabel: UILabel = {
        let label = UILabel()
        label.text = "Hive"
        label.font = UIFont(name: "Roboto-Medium", size: 12) ?? UIFont.systemFont(ofSize: 12, weight: .medium)
        label.textColor = UIColor.Sphinx.PrimaryBlue
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let stepTextLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: "Roboto-Regular", size: 15) ?? UIFont.systemFont(ofSize: 15)
        label.textColor = UIColor.Sphinx.TextMessages
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let processingLabel: UILabel = {
        let label = UILabel()
        label.text = "Processing..."
        label.font = UIFont(name: "Roboto-Regular", size: 12) ?? UIFont.systemFont(ofSize: 12)
        label.textColor = UIColor.Sphinx.SecondaryText
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let stackView: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.spacing = 4
        sv.alignment = .leading
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    // MARK: - Init

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    // MARK: - Setup

    private func setupViews() {
        backgroundColor = UIColor.Sphinx.Body
        selectionStyle = .none

        stackView.addArrangedSubview(hiveLabel)
        stackView.addArrangedSubview(stepTextLabel)
        stackView.addArrangedSubview(processingLabel)

        bubbleView.addSubview(stackView)
        contentView.addSubview(bubbleView)

        NSLayoutConstraint.activate([
            // Stack inside bubble
            stackView.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 12),
            stackView.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 14),
            stackView.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -14),
            stackView.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -12),

            // Bubble pinned leading, capped trailing at 85% of contentView
            bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            bubbleView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            bubbleView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
            bubbleView.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor,
                                                  constant: -contentView.bounds.width * 0.15)
        ])

        // Additional width cap using multiplier
        let widthConstraint = bubbleView.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor,
                                                                 multiplier: 0.85)
        widthConstraint.isActive = true
    }

    // MARK: - Configuration

    func configure(stepText: String) {
        stepTextLabel.text = stepText
        startAnimation()
    }

    // MARK: - Animation

    func startAnimation() {
        let anim = CABasicAnimation(keyPath: "opacity")
        anim.fromValue = 0.4
        anim.toValue = 1.0
        anim.duration = 0.8
        anim.repeatCount = .infinity
        anim.autoreverses = true
        processingLabel.layer.add(anim, forKey: "pulse")
    }

    func stopAnimation() {
        processingLabel.layer.removeAnimation(forKey: "pulse")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        stopAnimation()
    }
}
