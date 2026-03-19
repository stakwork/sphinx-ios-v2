//
//  ClarifyingQuestionsView.swift
//  sphinx
//
//  Created on 2025-03-04.
//  Copyright © 2025 sphinx. All rights reserved.
//

import UIKit

// MARK: - MultilineTitleButton
// UIButton doesn't grow its intrinsicContentSize for multiline titleLabel text.
// This subclass overrides intrinsicContentSize so Auto Layout can grow button height.
private final class MultilineTitleButton: UIButton {
    private var lastKnownWidth: CGFloat = 0

    override var intrinsicContentSize: CGSize {
        guard let titleLabel = titleLabel else { return super.intrinsicContentSize }
        let insets = contentEdgeInsets
        let containerWidth = superview?.bounds.width ?? (UIScreen.main.bounds.width - 48)
        let availableWidth = containerWidth - insets.left - insets.right
        guard availableWidth > 0 else { return super.intrinsicContentSize }
        let titleSize = titleLabel.sizeThatFits(
            CGSize(width: availableWidth, height: .greatestFiniteMagnitude)
        )
        let height = max(titleSize.height + insets.top + insets.bottom, 44)
        return CGSize(width: super.intrinsicContentSize.width, height: height)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Only invalidate when width actually changes — calling unconditionally
        // on every layout pass triggers table view height recalculation loops
        // that cause contentOffset jumps while the user is scrolling.
        let w = bounds.width
        if w != lastKnownWidth {
            lastKnownWidth = w
            invalidateIntrinsicContentSize()
        }
    }
}

// MARK: - ClarifyingQuestionsView

/// Self-contained paginated view for presenting AI clarifying questions.
/// Embed below the bubble stack in `FeatureChatMessageCell`.
final class ClarifyingQuestionsView: UIView {

    // MARK: - Public API

    var onSubmit: (([String]) -> Void)?
    var onHeightChanged: (() -> Void)?

    // MARK: - Private State

    private var questions: [ClarifyingQuestion] = []
    private var currentIndex: Int = 0
    private var selectedIndices: Set<Int> = []
    private var collectedAnswers: [String] = []

    // Review-mode state
    private var isLockedForReview: Bool = false
    /// Maps question index → set of selected option indices (restored from answer text)
    private var restoredAnswersByIndex: [Int: Set<Int>] = [:]
    /// Maps question index → free-text context the user typed (not matching any option label)
    private var restoredContextByIndex: [Int: String] = [:]

    // MARK: - UI Components

    private let containerView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = UIColor.Sphinx.Body
        v.layer.cornerRadius = 12
        v.layer.borderWidth = 1
        v.layer.borderColor = UIColor.Sphinx.LightDivider.cgColor
        return v
    }()

    private let counterLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.font = UIFont(name: "Roboto-Regular", size: 12) ?? UIFont.systemFont(ofSize: 12)
        l.textColor = UIColor.Sphinx.SecondaryText
        l.textAlignment = .left
        return l
    }()

    private let questionLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.font = UIFont(name: "Roboto-Medium", size: 14) ?? UIFont.boldSystemFont(ofSize: 14)
        l.textColor = UIColor.Sphinx.Text
        l.numberOfLines = 0
        return l
    }()

    private let optionsStackView: UIStackView = {
        let sv = UIStackView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        sv.axis = .vertical
        sv.spacing = 8
        return sv
    }()

    /// Read-only label shown below options in review mode when the user added free-text context.
    private let reviewContextLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.font = UIFont(name: "Roboto-Regular", size: 13) ?? UIFont.systemFont(ofSize: 13)
        l.textColor = UIColor.Sphinx.SecondaryText
        l.numberOfLines = 0
        l.isHidden = true
        return l
    }()

    private let additionalContextTextView: UITextView = {
        let tv = UITextView()
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.font = UIFont(name: "Roboto-Regular", size: 14) ?? UIFont.systemFont(ofSize: 14)
        tv.textColor = UIColor.Sphinx.Text
        tv.backgroundColor = UIColor.Sphinx.Body
        tv.layer.cornerRadius = 8
        tv.layer.borderWidth = 1
        tv.layer.borderColor = UIColor.Sphinx.LightDivider.cgColor
        tv.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        tv.isScrollEnabled = true
        return tv
    }()

    private let actionButton: UIButton = {
        let b = UIButton(type: .system)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.titleLabel?.font = UIFont(name: "Roboto-Medium", size: 14) ?? UIFont.boldSystemFont(ofSize: 14)
        b.setTitleColor(.white, for: .normal)
        b.backgroundColor = UIColor.Sphinx.PrimaryBlue
        b.layer.cornerRadius = 10
        b.layer.masksToBounds = true
        return b
    }()

    private let placeholderLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.text = "Add additional context…"
        l.font = UIFont(name: "Roboto-Regular", size: 14) ?? UIFont.systemFont(ofSize: 14)
        l.textColor = UIColor.Sphinx.PlaceholderText
        return l
    }()

    // Navigation row (review mode only)
    private var navRowStackView: UIStackView?

    private lazy var prevButton: UIButton = {
        let b = UIButton(type: .system)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.setTitle("← Prev", for: .normal)
        b.titleLabel?.font = UIFont(name: "Roboto-Regular", size: 13) ?? UIFont.systemFont(ofSize: 13)
        b.setTitleColor(UIColor.Sphinx.PrimaryBlue, for: .normal)
        b.setTitleColor(UIColor.Sphinx.SecondaryText, for: .disabled)
        b.addTarget(self, action: #selector(showPrev), for: .touchUpInside)
        return b
    }()

    private lazy var nextButton: UIButton = {
        let b = UIButton(type: .system)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.setTitle("Next →", for: .normal)
        b.titleLabel?.font = UIFont(name: "Roboto-Regular", size: 13) ?? UIFont.systemFont(ofSize: 13)
        b.setTitleColor(UIColor.Sphinx.PrimaryBlue, for: .normal)
        b.setTitleColor(UIColor.Sphinx.SecondaryText, for: .disabled)
        b.addTarget(self, action: #selector(showNext), for: .touchUpInside)
        return b
    }()

    // Constraint references for toggling between normal and review layout
    private var actionButtonBottomConstraint: NSLayoutConstraint?
    private var contextViewTopConstraint: NSLayoutConstraint?
    private var optionsBottomToNavRowConstraint: NSLayoutConstraint?
    // reviewContextLabel anchors (added once, hidden/shown as needed)
    private var reviewContextTopConstraint: NSLayoutConstraint?

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    // MARK: - Layout

    private func setupUI() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear

        addSubview(containerView)
        containerView.addSubview(counterLabel)
        containerView.addSubview(questionLabel)
        containerView.addSubview(optionsStackView)
        containerView.addSubview(reviewContextLabel)
        containerView.addSubview(additionalContextTextView)
        additionalContextTextView.addSubview(placeholderLabel)
        containerView.addSubview(actionButton)

        additionalContextTextView.delegate = self
        actionButton.addTarget(self, action: #selector(actionButtonTapped), for: .touchUpInside)

        let contextTop = additionalContextTextView.topAnchor.constraint(
            equalTo: optionsStackView.bottomAnchor, constant: 12
        )
        contextViewTopConstraint = contextTop

        let actionBottom = actionButton.bottomAnchor.constraint(
            equalTo: containerView.bottomAnchor, constant: -12
        )
        actionButtonBottomConstraint = actionBottom

        // reviewContextLabel: anchored below optionsStack, hidden by default
        let reviewCtxTop = reviewContextLabel.topAnchor.constraint(
            equalTo: optionsStackView.bottomAnchor, constant: 8
        )
        reviewContextTopConstraint = reviewCtxTop

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),

            counterLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            counterLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            counterLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),

            questionLabel.topAnchor.constraint(equalTo: counterLabel.bottomAnchor, constant: 6),
            questionLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            questionLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),

            optionsStackView.topAnchor.constraint(equalTo: questionLabel.bottomAnchor, constant: 12),
            optionsStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            optionsStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),

            // reviewContextLabel (hidden until review mode)
            reviewCtxTop,
            reviewContextLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            reviewContextLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),

            contextTop,
            additionalContextTextView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            additionalContextTextView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            additionalContextTextView.heightAnchor.constraint(greaterThanOrEqualToConstant: 60),
            additionalContextTextView.heightAnchor.constraint(lessThanOrEqualToConstant: 100),

            placeholderLabel.topAnchor.constraint(equalTo: additionalContextTextView.topAnchor, constant: 8),
            placeholderLabel.leadingAnchor.constraint(equalTo: additionalContextTextView.leadingAnchor, constant: 12),
            placeholderLabel.trailingAnchor.constraint(equalTo: additionalContextTextView.trailingAnchor, constant: -12),

            actionButton.topAnchor.constraint(equalTo: additionalContextTextView.bottomAnchor, constant: 12),
            actionButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            actionBottom,
            actionButton.heightAnchor.constraint(equalToConstant: 36),
            actionButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 90),
        ])
    }

    // MARK: - Public Methods

    func configure(with questions: [ClarifyingQuestion]) {
        guard !questions.isEmpty else { return }
        self.questions = questions
        self.currentIndex = 0
        self.collectedAnswers = []
        self.selectedIndices = []
        additionalContextTextView.text = ""
        placeholderLabel.isHidden = false
        isUserInteractionEnabled = true
        alpha = 1.0
        showQuestion(at: 0)
    }

    func lock() {
        isUserInteractionEnabled = false
        alpha = 0.5
    }

    /// Lock in read-only review mode. Parses `answersText` to restore selections and free-text context.
    func lockWithAnswers(_ answersText: String) {
        restoredAnswersByIndex = [:]
        restoredContextByIndex = [:]

        // Split into Q/A blocks
        let blocks = answersText.components(separatedBy: "\n\n").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        for block in blocks {
            let lines = block.components(separatedBy: "\n")
            // Match block to question by Q: line
            guard let qLine = lines.first(where: { $0.hasPrefix("Q: ") }),
                  let aLine = lines.first(where: { $0.hasPrefix("A: ") }) else { continue }

            let qText = String(qLine.dropFirst(3))
            let aValue = String(aLine.dropFirst(3))

            // Find which question this block belongs to
            guard let qIdx = questions.firstIndex(where: { $0.question == qText }) else { continue }

            let (selectedIndices, contextParts) = parseAnswerValue(
                aValue,
                options: questions[qIdx].options
            )
            restoredAnswersByIndex[qIdx] = selectedIndices
            if !contextParts.isEmpty {
                restoredContextByIndex[qIdx] = contextParts.joined(separator: ", ")
            }
        }

        isLockedForReview = true

        // Hide interactive-only elements
        additionalContextTextView.isHidden = true
        placeholderLabel.isHidden = true
        actionButton.isHidden = true

        // Swap constraint chain: options → navRow → bottom  (not options → textView → actionBtn → bottom)
        contextViewTopConstraint?.isActive = false
        actionButtonBottomConstraint?.isActive = false

        addNavRowIfNeeded()
        showQuestion(at: 0)
    }

    func reset() {
        questions = []
        currentIndex = 0
        selectedIndices = []
        collectedAnswers = []
        isLockedForReview = false
        restoredAnswersByIndex = [:]
        restoredContextByIndex = [:]
        counterLabel.text = nil
        questionLabel.text = nil
        reviewContextLabel.text = nil
        reviewContextLabel.isHidden = true
        additionalContextTextView.text = ""
        additionalContextTextView.isHidden = false
        placeholderLabel.isHidden = false
        actionButton.isHidden = false
        optionsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        optionsBottomToNavRowConstraint?.isActive = false
        optionsBottomToNavRowConstraint = nil
        navRowStackView?.removeFromSuperview()
        navRowStackView = nil
        contextViewTopConstraint?.isActive = true
        actionButtonBottomConstraint?.isActive = true

        isUserInteractionEnabled = true
        alpha = 1.0
    }

    // MARK: - Private: Nav Row

    private func addNavRowIfNeeded() {
        guard navRowStackView == nil else { return }

        // Only prevButton + nextButton — counterLabel stays in containerView so its
        // constraints (which questionLabel depends on) are never disturbed.
        let navRow = UIStackView(arrangedSubviews: [prevButton, nextButton])
        navRow.translatesAutoresizingMaskIntoConstraints = false
        navRow.axis = .horizontal
        navRow.distribution = .equalSpacing
        navRow.alignment = .center
        containerView.addSubview(navRow)
        navRowStackView = navRow

        let optToNav = optionsStackView.bottomAnchor.constraint(
            equalTo: navRow.topAnchor, constant: -12
        )
        optionsBottomToNavRowConstraint = optToNav

        NSLayoutConstraint.activate([
            navRow.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            navRow.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            navRow.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -12),
            navRow.heightAnchor.constraint(equalToConstant: 36),
            optToNav,
        ])
    }

    // MARK: - Private: Rendering

    private func showQuestion(at index: Int, notifyHeightChange: Bool = false) {
        guard index < questions.count else { return }
        let q = questions[index]

        counterLabel.text = "\(index + 1) of \(questions.count)"
        questionLabel.text = q.question
        selectedIndices = []

        if !isLockedForReview {
            additionalContextTextView.text = ""
            placeholderLabel.isHidden = false
            reviewContextLabel.isHidden = true
        }

        // Rebuild option pills
        optionsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (i, option) in q.options.enumerated() {
            let btn = makeOptionButton(title: option, tag: i)
            optionsStackView.addArrangedSubview(btn)
        }

        if isLockedForReview {
            let restored = restoredAnswersByIndex[index] ?? []
            optionsStackView.arrangedSubviews.compactMap { $0 as? UIButton }.forEach { btn in
                if restored.contains(btn.tag) {
                    applySelectedStyle(to: btn)
                }
                btn.isUserInteractionEnabled = false
            }

            // Show free-text context if present for this question
            if let ctx = restoredContextByIndex[index], !ctx.isEmpty {
                reviewContextLabel.text = "Additional: \(ctx)"
                reviewContextLabel.isHidden = false
                // Repin the navRow constraint below the context label
                optionsBottomToNavRowConstraint?.isActive = false
                reviewContextTopConstraint?.isActive = true
                if let navRow = navRowStackView {
                    let ctxToNav = reviewContextLabel.bottomAnchor.constraint(
                        equalTo: navRow.topAnchor, constant: -8
                    )
                    ctxToNav.isActive = true
                    // Store so we can remove/replace on next call
                    optionsBottomToNavRowConstraint = ctxToNav
                }
            } else {
                reviewContextLabel.isHidden = true
                reviewContextTopConstraint?.isActive = false
                // Re-pin options directly to navRow
                optionsBottomToNavRowConstraint?.isActive = false
                if let navRow = navRowStackView {
                    let optToNav = optionsStackView.bottomAnchor.constraint(
                        equalTo: navRow.topAnchor, constant: -12
                    )
                    optToNav.isActive = true
                    optionsBottomToNavRowConstraint = optToNav
                }
            }

            prevButton.isEnabled = index > 0
            nextButton.isEnabled = index < questions.count - 1
        } else {
            updateActionButton()
        }

        invalidateIntrinsicContentSize()
        if notifyHeightChange {
            onHeightChanged?()
        }
    }

    private func makeOptionButton(title: String, tag: Int) -> UIButton {
        let btn = MultilineTitleButton(type: .system)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.tag = tag
        btn.setTitle(title, for: .normal)
        btn.titleLabel?.font = UIFont(name: "Roboto-Regular", size: 14) ?? UIFont.systemFont(ofSize: 14)
        btn.titleLabel?.numberOfLines = 0
        btn.titleLabel?.lineBreakMode = .byWordWrapping
        btn.contentHorizontalAlignment = .left
        btn.contentEdgeInsets = UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16)
        btn.layer.cornerRadius = 16
        btn.layer.masksToBounds = true
        btn.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        btn.addTarget(self, action: #selector(optionTapped(_:)), for: .touchUpInside)
        applyUnselectedStyle(to: btn)
        return btn
    }

    private func applyUnselectedStyle(to button: UIButton) {
        button.backgroundColor = UIColor.Sphinx.Body
        button.setTitleColor(UIColor.Sphinx.Text, for: .normal)
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.Sphinx.LightDivider.cgColor
    }

    private func applySelectedStyle(to button: UIButton) {
        button.backgroundColor = UIColor.Sphinx.PrimaryBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.borderWidth = 0
        button.layer.borderColor = UIColor.clear.cgColor
    }

    private func updateActionButton() {
        let hasSelection = !selectedIndices.isEmpty
        let hasContext = !(additionalContextTextView.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        let enabled = hasSelection || hasContext
        actionButton.isEnabled = enabled
        actionButton.alpha = enabled ? 1.0 : 0.5
        let isLast = currentIndex == questions.count - 1
        actionButton.setTitle(isLast ? "Submit" : "Next →", for: .normal)
    }

    // MARK: - Private: Actions

    @objc private func optionTapped(_ sender: UIButton) {
        guard currentIndex < questions.count else { return }
        let q = questions[currentIndex]
        let tappedIndex = sender.tag

        if q.type == "single_choice" {
            let alreadySelected = selectedIndices.contains(tappedIndex)
            selectedIndices = alreadySelected ? [] : [tappedIndex]
            optionsStackView.arrangedSubviews.compactMap { $0 as? UIButton }.forEach { btn in
                if !alreadySelected && btn.tag == tappedIndex {
                    applySelectedStyle(to: btn)
                } else {
                    applyUnselectedStyle(to: btn)
                }
            }
        } else {
            if selectedIndices.contains(tappedIndex) {
                selectedIndices.remove(tappedIndex)
                applyUnselectedStyle(to: sender)
            } else {
                selectedIndices.insert(tappedIndex)
                applySelectedStyle(to: sender)
            }
        }

        updateActionButton()
    }

    @objc private func actionButtonTapped() {
        guard currentIndex < questions.count else { return }
        let q = questions[currentIndex]

        let selectedLabels = q.options.enumerated()
            .filter { selectedIndices.contains($0.offset) }
            .map { $0.element }

        let contextText = additionalContextTextView.text
            .trimmingCharacters(in: .whitespacesAndNewlines)

        var parts = selectedLabels
        if !contextText.isEmpty { parts.append(contextText) }
        let answerString = "Q: \(q.question)\nA: \(parts.joined(separator: ", "))"
        collectedAnswers.append(answerString)

        if currentIndex == questions.count - 1 {
            onSubmit?(collectedAnswers)
        } else {
            currentIndex += 1
            showQuestion(at: currentIndex, notifyHeightChange: true)
        }
    }

    @objc private func showPrev() {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
        showQuestion(at: currentIndex, notifyHeightChange: true)
    }

    @objc private func showNext() {
        guard currentIndex < questions.count - 1 else { return }
        currentIndex += 1
        showQuestion(at: currentIndex, notifyHeightChange: true)
    }
}

// MARK: - Helpers

/// Normalises dash variants and trims whitespace for fuzzy option matching.
private func normalizeForMatch(_ s: String) -> String {
    s.trimmingCharacters(in: .whitespacesAndNewlines)
     .replacingOccurrences(of: "\u{2014}", with: "-")  // em-dash
     .replacingOccurrences(of: "\u{2013}", with: "-")  // en-dash
     .replacingOccurrences(of: "\u{2012}", with: "-")  // figure dash
     .replacingOccurrences(of: "--",        with: "-")
}

/// Greedily parses an A: value string back into matched option indices and leftover context.
///
/// Problem with naive split(", "): option labels often contain commas (e.g.
/// "Reuse FEATURE_UPDATED — fires multiple times, each time with more fields populated"),
/// which would be shredded by a simple separator split. Instead we work in normalised
/// space and scan left-to-right, consuming the longest matching option at each step.
private func parseAnswerValue(
    _ aValue: String,
    options: [String]
) -> (matched: Set<Int>, context: [String]) {
    let normOptions = options.map { normalizeForMatch($0) }
    // Work entirely in normalised space — we only need indices + leftover text.
    var remaining = normalizeForMatch(aValue)
    var matchedIndices: Set<Int> = []
    var contextParts: [String] = []

    while !remaining.isEmpty {
        // Find the longest option that the remaining string starts with,
        // confirmed by being followed by ", " or end-of-string.
        var bestIdx: Int? = nil
        var bestLen = 0

        for (i, normOpt) in normOptions.enumerated() {
            guard normOpt.count > bestLen else { continue }
            if remaining.hasPrefix(normOpt) {
                let after = remaining.dropFirst(normOpt.count)
                if after.isEmpty || after.hasPrefix(", ") {
                    bestIdx = i
                    bestLen = normOpt.count
                }
            }
        }

        if let idx = bestIdx {
            matchedIndices.insert(idx)
            remaining = String(remaining.dropFirst(bestLen))
            if remaining.hasPrefix(", ") { remaining = String(remaining.dropFirst(2)) }
        } else {
            // No option matched — consume up to the next ", " as free-text context.
            if let sepRange = remaining.range(of: ", ") {
                contextParts.append(String(remaining[..<sepRange.lowerBound]))
                remaining = String(remaining[sepRange.upperBound...])
            } else {
                contextParts.append(remaining)
                remaining = ""
            }
        }
    }

    return (matchedIndices, contextParts)
}

// MARK: - UITextViewDelegate

extension ClarifyingQuestionsView: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        placeholderLabel.isHidden = !textView.text.isEmpty
        updateActionButton()
    }
}
