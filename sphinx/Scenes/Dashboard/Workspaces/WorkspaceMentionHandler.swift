//
//  WorkspaceMentionHandler.swift
//  sphinx
//
//  Created on 2026-06-09.
//  Copyright © 2026 sphinx. All rights reserved.
//

import UIKit

// MARK: - WorkspaceMentionHandler

/// Composable helper that owns all `@workspace` autocomplete state and UI.
/// Callers add `container` to their own view hierarchy and set its constraints.
final class WorkspaceMentionHandler {

    // MARK: - Shared regex

    static let mentionRegex = try? NSRegularExpression(pattern: "@\\S+")

    // MARK: - State

    var availableWorkspaces: [Workspace] = []
    private(set) var filteredWorkspaces: [Workspace] = []
    private(set) var atTriggerNSRange: NSRange?

    // MARK: - UI

    /// Add this to your view hierarchy; set constraints yourself (layouts differ per VC).
    let container: UIView
    let heightConstraint: NSLayoutConstraint

    private let scrollView: UIScrollView
    private let stack: UIStackView

    // MARK: - Callback

    /// Called when the user taps a workspace row. The VC handles text insertion.
    var onWorkspaceSelected: ((Workspace, NSRange) -> Void)?

    // MARK: - Init

    init() {
        // Container
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.backgroundColor = UIColor.Sphinx.HeaderBG
        containerView.isHidden = true
        containerView.clipsToBounds = true

        // Scroll view
        let sv = UIScrollView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        sv.showsVerticalScrollIndicator = false
        containerView.addSubview(sv)
        NSLayoutConstraint.activate([
            sv.topAnchor.constraint(equalTo: containerView.topAnchor),
            sv.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            sv.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            sv.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])

        // Stack inside scroll view
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 0
        stackView.distribution = .fill
        sv.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: sv.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: sv.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: sv.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: sv.bottomAnchor),
            stackView.widthAnchor.constraint(equalTo: sv.widthAnchor)
        ])

        // Height constraint (starts at 0 = hidden)
        let hc = containerView.heightAnchor.constraint(equalToConstant: 0)
        hc.isActive = true

        self.container = containerView
        self.scrollView = sv
        self.stack = stackView
        self.heightConstraint = hc
    }

    // MARK: - Public API

    /// Call from `textViewDidChange` — detects `@`, filters workspaces, shows/hides dropdown.
    func processTextChange(in textView: UITextView) {
        let text = textView.text ?? ""
        let cursor = textView.selectedRange
        let cursorPos = cursor.location
        guard cursorPos <= (text as NSString).length else { hide(); return }

        let upToCursor = (text as NSString).substring(to: cursorPos)
        if let atRange = upToCursor.range(of: "@", options: .backwards),
           (atRange.lowerBound == upToCursor.startIndex ||
            upToCursor[upToCursor.index(before: atRange.lowerBound)].isWhitespace) {
            let query = String(upToCursor[atRange.upperBound...])
            if query.contains(" ") || query.contains("\n") {
                hide()
                return
            }
            let atNSIdx = upToCursor.distance(from: upToCursor.startIndex, to: atRange.lowerBound)
            atTriggerNSRange = NSRange(location: atNSIdx, length: cursorPos - atNSIdx)
            filteredWorkspaces = availableWorkspaces.filter {
                query.isEmpty ||
                $0.name.localizedCaseInsensitiveContains(query) ||
                ($0.slug ?? "").localizedCaseInsensitiveContains(query)
            }
            show()
        } else {
            hide()
        }
    }

    /// Colors `@\S+` matches `PrimaryBlue`; resets everything else to `Sphinx.Text`.
    /// Restores cursor position after updating `attributedText`.
    func applyMentionColoring(to textView: UITextView, preservingCursor cursor: NSRange, font: UIFont) {
        let text = textView.text ?? ""
        let attr = NSMutableAttributedString(
            string: text,
            attributes: [.foregroundColor: UIColor.Sphinx.Text, .font: font]
        )
        if let regex = WorkspaceMentionHandler.mentionRegex {
            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            for match in matches {
                attr.addAttribute(.foregroundColor, value: UIColor.Sphinx.PrimaryBlue, range: match.range)
            }
        }
        textView.attributedText = attr
        textView.selectedRange = cursor
        textView.typingAttributes = [.foregroundColor: UIColor.Sphinx.Text, .font: font]
    }

    // MARK: - Private

    private func show() {
        guard !filteredWorkspaces.isEmpty else { hide(); return }

        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (i, ws) in filteredWorkspaces.enumerated() {
            let row = UIView()
            row.backgroundColor = UIColor.Sphinx.HeaderBG

            let nameLabel = UILabel()
            nameLabel.text = ws.name
            nameLabel.textColor = UIColor.Sphinx.Text
            nameLabel.font = UIFont(name: "Roboto-Medium", size: 14) ?? .systemFont(ofSize: 14, weight: .medium)

            let slugLabel = UILabel()
            slugLabel.text = ws.slug
            slugLabel.textColor = UIColor.Sphinx.SecondaryText
            slugLabel.font = UIFont(name: "Roboto-Regular", size: 12) ?? .systemFont(ofSize: 12)

            let labelStack = UIStackView(arrangedSubviews: [nameLabel, slugLabel])
            labelStack.axis = .vertical
            labelStack.spacing = 2
            labelStack.translatesAutoresizingMaskIntoConstraints = false
            row.addSubview(labelStack)
            NSLayoutConstraint.activate([
                labelStack.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 16),
                labelStack.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -16),
                labelStack.centerYAnchor.constraint(equalTo: row.centerYAnchor)
            ])

            let btn = UIButton(type: .system)
            btn.translatesAutoresizingMaskIntoConstraints = false
            btn.backgroundColor = .clear
            btn.tag = i
            btn.addTarget(self, action: #selector(handleRowTap(_:)), for: .touchUpInside)
            row.addSubview(btn)
            NSLayoutConstraint.activate([
                btn.topAnchor.constraint(equalTo: row.topAnchor),
                btn.leadingAnchor.constraint(equalTo: row.leadingAnchor),
                btn.trailingAnchor.constraint(equalTo: row.trailingAnchor),
                btn.bottomAnchor.constraint(equalTo: row.bottomAnchor)
            ])

            row.heightAnchor.constraint(equalToConstant: 52).isActive = true
            stack.addArrangedSubview(row)

            if i < filteredWorkspaces.count - 1 {
                let divider = UIView()
                divider.backgroundColor = UIColor.Sphinx.LightDivider
                divider.translatesAutoresizingMaskIntoConstraints = false
                divider.heightAnchor.constraint(equalToConstant: 1).isActive = true
                stack.addArrangedSubview(divider)
            }
        }

        let maxRows = min(filteredWorkspaces.count, 4)
        let dividerCount = max(0, maxRows - 1)
        let visibleHeight = CGFloat(maxRows) * 52 + CGFloat(dividerCount)
        heightConstraint.constant = visibleHeight
        container.isHidden = false
        container.superview?.layoutIfNeeded()
    }

    func hide() {
        container.isHidden = true
        heightConstraint.constant = 0
        atTriggerNSRange = nil
    }

    @objc private func handleRowTap(_ sender: UIButton) {
        guard sender.tag < filteredWorkspaces.count,
              let triggerRange = atTriggerNSRange else { hide(); return }
        let ws = filteredWorkspaces[sender.tag]
        onWorkspaceSelected?(ws, triggerRange)
        hide()
    }
}
