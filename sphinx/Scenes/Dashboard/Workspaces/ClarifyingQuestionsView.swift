//
//  ClarifyingQuestionsView.swift
//  sphinx
//
//  Created on 2025-03-04.
//  Copyright © 2025 sphinx. All rights reserved.
//

import UIKit

// MARK: - OptionPillView
// Replaces UIButton for option items.
// UIButton.intrinsicContentSize doesn't account for multiline titleLabel text — any attempt
// to override intrinsicContentSize causes layoutSubviews to re-fire, which changes the cell
// height mid-scroll and causes UITableView contentOffset jump-corrections.
// A UIView + UILabel with standard Auto Layout constraints has perfectly stable sizing from
// the very first layout pass — no feedback loops.
private final class OptionPillView: UIView {

    let label: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.font = UIFont(name: "Roboto-Regular", size: 14) ?? UIFont.systemFont(ofSize: 14)
        l.textColor = UIColor.Sphinx.Text
        l.numberOfLines = 0
        l.lineBreakMode = .byWordWrapping
        return l
    }()

    // Exposed so ClarifyingQuestionsView can read/write
    var isSelected: Bool = false {
        didSet { applyStyle() }
    }

    /// Called when the pill is tapped (set by ClarifyingQuestionsView)
    var onTap: ((OptionPillView) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) { super.init(coder: coder); setup() }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerRadius = 16
        layer.masksToBounds = true
        layer.borderWidth = 1

        addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
            // Minimum tap-target height
            heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
        ])

        applyStyle()

        let tap = UITapGestureRecognizer(target: self, action: #selector(tapped))
        addGestureRecognizer(tap)
    }

    @objc private func tapped() { onTap?(self) }

    func applySelectedStyle() {
        isSelected = true
    }

    func applyUnselectedStyle() {
        isSelected = false
    }

    private func applyStyle() {
        if isSelected {
            backgroundColor = UIColor.Sphinx.PrimaryBlue
            label.textColor = .white
            layer.borderColor = UIColor.clear.cgColor
            layer.borderWidth = 0
        } else {
            backgroundColor = UIColor.Sphinx.Body
            label.textColor = UIColor.Sphinx.Text
            layer.borderColor = UIColor.Sphinx.LightDivider.cgColor
            layer.borderWidth = 1
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
    private var restoredAnswersByIndex: [Int: Set<Int>] = [:]
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

    /// Read-only label shown in review mode when the user added free-text context.
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

    // Constraint references
    private var actionButtonBottomConstraint: NSLayoutConstraint?
    private var contextViewTopConstraint: NSLayoutConstraint?
    private var optionsBottomToNavRowConstraint: NSLayoutConstraint?
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

    func lockWithAnswers(_ answersText: String) {
        restoredAnswersByIndex = [:]
        restoredContextByIndex = [:]

        let blocks = answersText.components(separatedBy: "\n\n")
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        for block in blocks {
            let lines = block.components(separatedBy: "\n")
            guard let qLine = lines.first(where: { $0.hasPrefix("Q: ") }),
                  let aLine = lines.first(where: { $0.hasPrefix("A: ") }) else { continue }

            let qText = String(qLine.dropFirst(3))
            let aValue = String(aLine.dropFirst(3))

            guard let qIdx = questions.firstIndex(where: { $0.question == qText }) else { continue }

            let (matched, context) = parseAnswerValue(aValue, options: questions[qIdx].options)
            restoredAnswersByIndex[qIdx] = matched
            if !context.isEmpty {
                restoredContextByIndex[qIdx] = context.joined(separator: ", ")
            }
        }

        isLockedForReview = true
        additionalContextTextView.isHidden = true
        placeholderLabel.isHidden = true
        actionButton.isHidden = true
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

        // Rebuild option pills using OptionPillView (stable sizing, no feedback loops)
        optionsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (i, option) in q.options.enumerated() {
            let pill = makeOptionPill(title: option, index: i)
            optionsStackView.addArrangedSubview(pill)
        }

        if isLockedForReview {
            let restored = restoredAnswersByIndex[index] ?? []
            optionsStackView.arrangedSubviews.compactMap { $0 as? OptionPillView }.forEach { pill in
                if restored.contains(pill.tag) {
                    pill.applySelectedStyle()
                }
                pill.isUserInteractionEnabled = false
            }

            // Context label below options
            if let ctx = restoredContextByIndex[index], !ctx.isEmpty {
                reviewContextLabel.text = "Additional: \(ctx)"
                reviewContextLabel.isHidden = false
                optionsBottomToNavRowConstraint?.isActive = false
                reviewContextTopConstraint?.isActive = true
                if let navRow = navRowStackView {
                    let ctxToNav = reviewContextLabel.bottomAnchor.constraint(
                        equalTo: navRow.topAnchor, constant: -8
                    )
                    ctxToNav.isActive = true
                    optionsBottomToNavRowConstraint = ctxToNav
                }
            } else {
                reviewContextLabel.isHidden = true
                reviewContextTopConstraint?.isActive = false
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

        if notifyHeightChange {
            onHeightChanged?()
        }
    }

    private func makeOptionPill(title: String, index: Int) -> OptionPillView {
        let pill = OptionPillView()
        pill.tag = index
        pill.label.text = title
        pill.onTap = { [weak self] tappedPill in
            self?.optionPillTapped(tappedPill)
        }
        return pill
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

    private func optionPillTapped(_ pill: OptionPillView) {
        guard currentIndex < questions.count else { return }
        let q = questions[currentIndex]
        let tappedIndex = pill.tag

        if q.type == "single_choice" {
            let alreadySelected = selectedIndices.contains(tappedIndex)
            selectedIndices = alreadySelected ? [] : [tappedIndex]
            optionsStackView.arrangedSubviews.compactMap { $0 as? OptionPillView }.forEach { p in
                if !alreadySelected && p.tag == tappedIndex {
                    p.applySelectedStyle()
                } else {
                    p.applyUnselectedStyle()
                }
            }
        } else {
            if selectedIndices.contains(tappedIndex) {
                selectedIndices.remove(tappedIndex)
                pill.applyUnselectedStyle()
            } else {
                selectedIndices.insert(tappedIndex)
                pill.applySelectedStyle()
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

    // MARK: - Test Hooks
    /// Simulate a tap on the option pill at the given index. Used in unit tests only.
    func simulateTapOptionPill(at index: Int) {
        let pills = optionsStackView.arrangedSubviews
            .compactMap { $0 as? OptionPillView }
            .sorted { $0.tag < $1.tag }
        guard index < pills.count else { return }
        optionPillTapped(pills[index])
    }
}



// MARK: - UITextViewDelegate

extension ClarifyingQuestionsView: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        placeholderLabel.isHidden = !textView.text.isEmpty
        updateActionButton()
    }
}

// MARK: - Helpers

private func normalizeForMatch(_ s: String) -> String {
    s.trimmingCharacters(in: .whitespacesAndNewlines)
     .replacingOccurrences(of: "\u{2014}", with: "-")
     .replacingOccurrences(of: "\u{2013}", with: "-")
     .replacingOccurrences(of: "\u{2012}", with: "-")
     .replacingOccurrences(of: "--",        with: "-")
}

private func parseAnswerValue(
    _ aValue: String,
    options: [String]
) -> (matched: Set<Int>, context: [String]) {
    let normOptions = options.map { normalizeForMatch($0) }
    var remaining = normalizeForMatch(aValue)
    var matchedIndices: Set<Int> = []
    var contextParts: [String] = []

    while !remaining.isEmpty {
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
