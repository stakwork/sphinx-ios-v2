//
//  WorkflowDiffView.swift
//  sphinx
//
//  Created on 2025.
//  Copyright © 2025 sphinx. All rights reserved.
//

import UIKit

final class WorkflowDiffView: UIView {

    // MARK: - Subviews

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        sv.alwaysBounceVertical = true
        return sv
    }()

    private let stackView: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.spacing = 0
        sv.alignment = .fill
        sv.distribution = .fill
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    // MARK: - State

    private var diffLines: [DiffLine] = []
    
    var hasDiffLines: Bool {
        !diffLines.isEmpty
    }

    /// True when the current diff contains at least one added or removed line.
    var hasDiffContent: Bool {
        diffLines.contains(where: { $0.type == .added || $0.type == .removed })
    }

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayout()
    }

    // MARK: - Layout

    private func setupLayout() {
        backgroundColor = .clear

        addSubview(scrollView)
        scrollView.addSubview(stackView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),

            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            stackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])
    }

    // MARK: - Public API

    /// Apply pre-computed diff lines directly. Must be called on the main thread.
    func applyDiffLines(_ lines: [DiffLine]) {
        diffLines = lines
        rebuildRows()
    }

    /// Cleans both JSON strings, computes the diff, and rebuilds the row views.
    func configure(original: String, updated: String) {
        let cleanedOriginal = cleanJsonForDiff(original) ?? original
        let cleanedUpdated  = cleanJsonForDiff(updated)  ?? updated

        diffLines = computeDiff(original: cleanedOriginal, updated: cleanedUpdated)
        rebuildRows()
    }

    // MARK: - Private helpers

    private func rebuildRows() {
        // Remove old rows
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        for line in diffLines {
            let row = makeRow(for: line)
            stackView.addArrangedSubview(row)
        }
    }

    private func makeRow(for line: DiffLine) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        // Colors
        let fg: UIColor
        let bg: UIColor
        switch line.type {
        case .added:
            fg = UIColor.Sphinx.PrimaryGreen
            bg = UIColor.Sphinx.PrimaryGreen.withAlphaComponent(0.1)
        case .removed:
            fg = UIColor.Sphinx.PrimaryRed
            bg = UIColor.Sphinx.PrimaryRed.withAlphaComponent(0.1)
        case .unchanged:
            fg = UIColor.Sphinx.Text
            bg = .clear
        }
        container.backgroundColor = bg

        let font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)

        // Prefix label (fixed width)
        let prefixLabel = UILabel()
        prefixLabel.translatesAutoresizingMaskIntoConstraints = false
        prefixLabel.font = font
        prefixLabel.textColor = fg
        prefixLabel.text = line.prefix
        prefixLabel.setContentHuggingPriority(.required, for: .horizontal)
        prefixLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        // Content label
        let contentLabel = UILabel()
        contentLabel.translatesAutoresizingMaskIntoConstraints = false
        contentLabel.font = font
        contentLabel.textColor = fg
        contentLabel.text = line.content
        contentLabel.numberOfLines = 0
        contentLabel.lineBreakMode = .byWordWrapping

        container.addSubview(prefixLabel)
        container.addSubview(contentLabel)

        NSLayoutConstraint.activate([
            prefixLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 4),
            prefixLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 1),
            prefixLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -1),
            prefixLabel.widthAnchor.constraint(equalToConstant: 14),

            contentLabel.leadingAnchor.constraint(equalTo: prefixLabel.trailingAnchor, constant: 4),
            contentLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -4),
            contentLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 1),
            contentLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -1)
        ])

        return container
    }
}
