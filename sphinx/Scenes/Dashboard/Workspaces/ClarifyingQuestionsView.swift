//
//  ClarifyingQuestionsView.swift
//  sphinx
//
//  Created on 2025-03-04.
//  Copyright © 2025 sphinx. All rights reserved.
//

import UIKit

/// Self-contained paginated view for presenting AI clarifying questions.
/// Embed below the bubble stack in `FeatureChatMessageCell`.
final class ClarifyingQuestionsView: UIView {

    // MARK: - Public API

    /// Called with all collected answer strings when the user taps Submit on the final question.
    var onSubmit: (([String]) -> Void)?

    /// Called after `showQuestion(at:)` rebuilds the options stack so the host cell
    /// can ask the table view to recalculate its row height.
    var onHeightChanged: (() -> Void)?

    // MARK: - Private State

    private var questions: [ClarifyingQuestion] = []
    private var currentIndex: Int = 0
    private var selectedIndices: Set<Int> = []
    private var collectedAnswers: [String] = []

    // Review-mode state
    private var isLockedForReview: Bool = false
    private var restoredAnswersByIndex: [Int: Set<Int>] = [:]

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

    // Placeholder handling
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
    private var navRowBottomConstraint: NSLayoutConstraint?
    private var optionsBottomToActionConstraint: NSLayoutConstraint?
    private var optionsBottomToNavRowConstraint: NSLayoutConstraint?

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

    // Stores actionButton-bottom constraint so we can deactivate it when switching to nav mode
    private var actionButtonBottomConstraint: NSLayoutConstraint?

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
        containerView.addSubview(additionalContextTextView)
        additionalContextTextView.addSubview(placeholderLabel)
        containerView.addSubview(actionButton)

        additionalContextTextView.delegate = self
        actionButton.addTarget(self, action: #selector(actionButtonTapped), for: .touchUpInside)

        let actionBottom = actionButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -12)
        actionButtonBottomConstraint = actionBottom

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 0),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: 0),
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

            additionalContextTextView.topAnchor.constraint(equalTo: optionsStackView.bottomAnchor, constant: 12),
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

    /// Configure the view with a set of clarifying questions and show the first one.
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

    /// Lock the view after submission — dims it and disables interaction.
    func lock() {
        isUserInteractionEnabled = false
        alpha = 0.5
    }

    /// Lock the view in read-only review mode, restoring selected answers parsed from `answersText`.
    /// Navigation (prev/next) remains active; option buttons and action button are disabled.
    func lockWithAnswers(_ answersText: String) {
        // Parse answersText: blocks separated by "\n\n", each block has a line "A: ..."
        let blocks = answersText.components(separatedBy: "\n\n")
        restoredAnswersByIndex = [:]

        for (i, block) in blocks.enumerated() {
            guard i < questions.count else { break }
            let lines = block.components(separatedBy: "\n")
            let aLine = lines.first(where: { $0.hasPrefix("A: ") })
            guard let aLine = aLine else { continue }
            let aValue = String(aLine.dropFirst(3)) // strip "A: "
            let selectedLabels = aValue.components(separatedBy: ", ")
            var indices: Set<Int> = []
            for label in selectedLabels {
                if let idx = questions[i].options.firstIndex(of: label) {
                    indices.insert(idx)
                }
            }
            restoredAnswersByIndex[i] = indices
        }

        isLockedForReview = true

        // Hide interactive elements
        additionalContextTextView.isHidden = true
        placeholderLabel.isHidden = true
        actionButton.isHidden = true
        actionButtonBottomConstraint?.isActive = false

        // Build and show nav row
        addNavRowIfNeeded()

        showQuestion(at: 0)
    }

    /// Reset to initial blank state (used in `prepareForReuse`).
    func reset() {
        questions = []
        currentIndex = 0
        selectedIndices = []
        collectedAnswers = []
        isLockedForReview = false
        restoredAnswersByIndex = [:]
        counterLabel.text = nil
        questionLabel.text = nil
        additionalContextTextView.text = ""
        additionalContextTextView.isHidden = false
        placeholderLabel.isHidden = false
        actionButton.isHidden = false
        actionButtonBottomConstraint?.isActive = true
        optionsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        navRowStackView?.removeFromSuperview()
        navRowStackView = nil
        navRowBottomConstraint = nil
        optionsBottomToNavRowConstraint?.isActive = false
        optionsBottomToNavRowConstraint = nil
        isUserInteractionEnabled = true
        alpha = 1.0
    }

    // MARK: - Private: Nav Row

    private func addNavRowIfNeeded() {
        guard navRowStackView == nil else { return }

        let navRow = UIStackView(arrangedSubviews: [prevButton, counterLabel, nextButton])
        navRow.translatesAutoresizingMaskIntoConstraints = false
        navRow.axis = .horizontal
        navRow.distribution = .equalSpacing
        navRow.alignment = .center
        containerView.addSubview(navRow)
        navRowStackView = navRow

        // counterLabel was previously constrained to containerView top — detach it conceptually
        // by moving it into the stackView (it's still in containerView's subviews but the
        // stackView now manages its position).
        // We need to deactivate the old counterLabel top/leading/trailing constraints first.
        counterLabel.removeFromSuperview()
        navRow.insertArrangedSubview(counterLabel, at: 1)

        let bottom = navRow.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -12)
        navRowBottomConstraint = bottom

        NSLayoutConstraint.activate([
            navRow.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            navRow.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            bottom,
            navRow.heightAnchor.constraint(equalToConstant: 36),
        ])

        // Pin options stack bottom to nav row top instead of additionalContextTextView
        let optToNav = optionsStackView.bottomAnchor.constraint(equalTo: navRow.topAnchor, constant: -12)
        optionsBottomToNavRowConstraint = optToNav
        optToNav.isActive = true
    }

    // MARK: - Private: Rendering

    private func showQuestion(at index: Int) {
        guard index < questions.count else { return }
        let q = questions[index]

        if !isLockedForReview {
            counterLabel.text = "\(index + 1) of \(questions.count)"
        } else {
            counterLabel.text = "\(index + 1) / \(questions.count)"
        }

        questionLabel.text = q.question
        selectedIndices = []
        if !isLockedForReview {
            additionalContextTextView.text = ""
            placeholderLabel.isHidden = false
        }

        // Rebuild option pills
        optionsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (i, option) in q.options.enumerated() {
            let btn = makeOptionButton(title: option, tag: i)
            optionsStackView.addArrangedSubview(btn)
        }

        if isLockedForReview {
            // Restore selections and disable interaction on all option buttons
            let restored = restoredAnswersByIndex[index] ?? []
            optionsStackView.arrangedSubviews.compactMap { $0 as? UIButton }.forEach { btn in
                if restored.contains(btn.tag) {
                    applySelectedStyle(to: btn)
                }
                btn.isUserInteractionEnabled = false
            }
            // Update nav button states
            prevButton.isEnabled = index > 0
            nextButton.isEnabled = index < questions.count - 1
        } else {
            updateActionButton()
        }

        invalidateIntrinsicContentSize()
        onHeightChanged?()
    }

    private func makeOptionButton(title: String, tag: Int) -> UIButton {
        let btn = UIButton(type: .system)
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
            // Toggle: deselect if already selected, otherwise select tapped
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
            // multiple_choice: toggle
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

        // Collect selected labels
        let selectedLabels = q.options.enumerated()
            .filter { selectedIndices.contains($0.offset) }
            .map { $0.element }

        // Capture context BEFORE showQuestion(at:) clears the text view
        let contextText = additionalContextTextView.text
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // New format: "Q: {question}\nA: {answer1}, {answer2}, {context}"
        var parts = selectedLabels
        if !contextText.isEmpty { parts.append(contextText) }
        let answerString = "Q: \(q.question)\nA: \(parts.joined(separator: ", "))"
        collectedAnswers.append(answerString)

        if currentIndex == questions.count - 1 {
            onSubmit?(collectedAnswers)
        } else {
            currentIndex += 1
            showQuestion(at: currentIndex)
        }
    }

    @objc private func showPrev() {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
        showQuestion(at: currentIndex)
    }

    @objc private func showNext() {
        guard currentIndex < questions.count - 1 else { return }
        currentIndex += 1
        showQuestion(at: currentIndex)
    }
}

// MARK: - UITextViewDelegate

extension ClarifyingQuestionsView: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        placeholderLabel.isHidden = !textView.text.isEmpty
        updateActionButton()
    }
}
