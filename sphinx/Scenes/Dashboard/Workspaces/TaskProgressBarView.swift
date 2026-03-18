//
//  TaskProgressBarView.swift
//  sphinx
//
//  Created on 2025-03-05.
//  Copyright © 2025 sphinx. All rights reserved.
//

import UIKit

class TaskProgressBarView: UIView {

    // MARK: - Subviews

    private let trackView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = UIColor.systemGray5
        v.layer.cornerRadius = 3
        v.clipsToBounds = true
        return v
    }()

    private let doneBar: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = UIColor.Sphinx.PrimaryGreen
        return v
    }()

    private let inProgressBar: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = UIColor.Sphinx.SphinxOrange
        return v
    }()

    private let percentLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.font = UIFont(name: "Roboto-Regular", size: 12) ?? UIFont.systemFont(ofSize: 12)
        l.textColor = UIColor.Sphinx.SecondaryText
        l.textAlignment = .left
        return l
    }()

    // MARK: - Constraints (updated on each configure call)

    private var doneBarWidthConstraint: NSLayoutConstraint!
    private var inProgressBarWidthConstraint: NSLayoutConstraint!

    // MARK: - State

    private var currentProgress: TaskProgress = TaskProgress(tasks: [])

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        backgroundColor = .clear
        translatesAutoresizingMaskIntoConstraints = false

        addSubview(trackView)
        trackView.addSubview(doneBar)
        trackView.addSubview(inProgressBar)
        addSubview(percentLabel)

        // doneBar: leading-anchored, full height, width driven by constraint
        doneBarWidthConstraint = doneBar.widthAnchor.constraint(equalToConstant: 0)
        // inProgressBar: immediately after doneBar
        inProgressBarWidthConstraint = inProgressBar.widthAnchor.constraint(equalToConstant: 0)

        NSLayoutConstraint.activate([
            // Track
            trackView.topAnchor.constraint(equalTo: topAnchor),
            trackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            trackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            trackView.heightAnchor.constraint(equalToConstant: 6),

            // Done bar
            doneBar.leadingAnchor.constraint(equalTo: trackView.leadingAnchor),
            doneBar.topAnchor.constraint(equalTo: trackView.topAnchor),
            doneBar.bottomAnchor.constraint(equalTo: trackView.bottomAnchor),
            doneBarWidthConstraint,

            // In-progress bar (anchored after doneBar)
            inProgressBar.leadingAnchor.constraint(equalTo: doneBar.trailingAnchor),
            inProgressBar.topAnchor.constraint(equalTo: trackView.topAnchor),
            inProgressBar.bottomAnchor.constraint(equalTo: trackView.bottomAnchor),
            inProgressBarWidthConstraint,

            // Percent label
            percentLabel.topAnchor.constraint(equalTo: trackView.bottomAnchor, constant: 4),
            percentLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            percentLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            percentLabel.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor)
        ])
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        applyProgress(currentProgress)
    }

    // MARK: - Public API

    func configure(with progress: TaskProgress) {
        currentProgress = progress
        percentLabel.text = "\(progress.completePercent)% complete"
        setNeedsLayout()
    }

    func setDisabled(_ disabled: Bool) {
        if disabled {
            alpha = 0.4
            doneBar.isHidden = true
            inProgressBar.isHidden = true
            percentLabel.text = "0% complete"
        } else {
            alpha = 1.0
            doneBar.isHidden = false
            inProgressBar.isHidden = false
            percentLabel.text = "\(currentProgress.completePercent)% complete"
        }
    }

    // MARK: - Private

    private func applyProgress(_ progress: TaskProgress) {
        let totalWidth = trackView.bounds.width
        guard totalWidth > 0 else { return }

        doneBarWidthConstraint.constant = totalWidth * progress.doneSegmentWidth
        inProgressBarWidthConstraint.constant = totalWidth * progress.inProgressSegmentWidth
    }
}
