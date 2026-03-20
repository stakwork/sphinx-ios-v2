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
    private var parsedAnswers: [(selectedOptions: [String], additionalText: String?)] = []

    // MARK: - Dynamic Layout Constraints

    /// Active state: container's bottom is tied to actionButton
    private var activeContainerBottomConstraint: NSLayoutConstraint!
    /// Answered state: container's bottom is tied to navigationStackView
    private var answeredContainerBottomConstraint: NSLayoutConstraint!
    /// Active state: actionButton's top is tied to additionalContextTextView's bottom
    private var actionButtonTopConstraint: NSLayoutConstraint!
    /// Answered state, no extra text: navStack's top is tied to optionsStackView's bottom
    private var navTopFromOptionsConstraint: NSLayoutConstraint!
    /// Answered state, with extra text: navStack's top is tied to additionalContextLabel's bottom
    private var navTopFromLabelConstraint: NSLayoutConstraint!

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

    private let additionalContextLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.font = UIFont(name: "Roboto-Regular", size: 14) ?? UIFont.systemFont(ofSize: 14)
        l.textColor = UIColor.Sphinx.SecondaryText
        l.numberOfLines = 0
        l.isHidden = true
        return l
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

    private let prevButton: UIButton = {
        let b = UIButton(type: .system)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.setTitle("← Prev", for: .normal)
        b.titleLabel?.font = UIFont(name: "Roboto-Medium", size: 14) ?? UIFont.boldSystemFont(ofSize: 14)
        b.setTitleColor(.white, for: .normal)
        b.setTitleColor(UIColor.white.withAlphaComponent(0.4), for: .disabled)
        b.backgroundColor = UIColor.Sphinx.PrimaryBlue
        b.layer.cornerRadius = 10
        b.layer.masksToBounds = true
        b.contentEdgeInsets = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
        return b
    }()

    private let nextButton: UIButton = {
        let b = UIButton(type: .system)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.setTitle("Next →", for: .normal)
        b.titleLabel?.font = UIFont(name: "Roboto-Medium", size: 14) ?? UIFont.boldSystemFont(ofSize: 14)
        b.setTitleColor(.white, for: .normal)
        b.setTitleColor(UIColor.white.withAlphaComponent(0.4), for: .disabled)
        b.backgroundColor = UIColor.Sphinx.PrimaryBlue
        b.layer.cornerRadius = 10
        b.layer.masksToBounds = true
        b.contentEdgeInsets = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
        return b
    }()

    private let navigationStackView: UIStackView = {
        let sv = UIStackView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        sv.axis = .horizontal
        sv.spacing = 8
        sv.isHidden = true
        return sv
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
        containerView.addSubview(additionalContextLabel)
        navigationStackView.addArrangedSubview(prevButton)
        navigationStackView.addArrangedSubview(nextButton)
        containerView.addSubview(navigationStackView)
        containerView.addSubview(actionButton)

        additionalContextTextView.delegate = self
        actionButton.addTarget(self, action: #selector(actionButtonTapped), for: .touchUpInside)
        prevButton.addTarget(self, action: #selector(prevTapped), for: .touchUpInside)
        nextButton.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)

        // Dynamic constraints — created here but activated/deactivated at runtime
        actionButtonTopConstraint = actionButton.topAnchor.constraint(
            equalTo: additionalContextTextView.bottomAnchor, constant: 12
        )
        activeContainerBottomConstraint = actionButton.bottomAnchor.constraint(
            equalTo: containerView.bottomAnchor, constant: -12
        )
        answeredContainerBottomConstraint = navigationStackView.bottomAnchor.constraint(
            equalTo: containerView.bottomAnchor, constant: -12
        )
        navTopFromOptionsConstraint = navigationStackView.topAnchor.constraint(
            equalTo: optionsStackView.bottomAnchor, constant: 12
        )
        navTopFromLabelConstraint = navigationStackView.topAnchor.constraint(
            equalTo: additionalContextLabel.bottomAnchor, constant: 12
        )

        NSLayoutConstraint.activate([
            // Container fills the view
            containerView.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),

            // Counter label
            counterLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            counterLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            counterLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),

            // Question label
            questionLabel.topAnchor.constraint(equalTo: counterLabel.bottomAnchor, constant: 6),
            questionLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            questionLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),

            // Options stack
            optionsStackView.topAnchor.constraint(equalTo: questionLabel.bottomAnchor, constant: 12),
            optionsStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            optionsStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),

            // Additional context text view (active state)
            additionalContextTextView.topAnchor.constraint(equalTo: optionsStackView.bottomAnchor, constant: 12),
            additionalContextTextView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            additionalContextTextView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            additionalContextTextView.heightAnchor.constraint(greaterThanOrEqualToConstant: 60),
            additionalContextTextView.heightAnchor.constraint(lessThanOrEqualToConstant: 100),

            // Placeholder inside text view
            placeholderLabel.topAnchor.constraint(equalTo: additionalContextTextView.topAnchor, constant: 8),
            placeholderLabel.leadingAnchor.constraint(equalTo: additionalContextTextView.leadingAnchor, constant: 12),
            placeholderLabel.trailingAnchor.constraint(equalTo: additionalContextTextView.trailingAnchor, constant: -12),

            // Additional context label (answered state) — same leading/trailing as other content
            additionalContextLabel.topAnchor.constraint(equalTo: optionsStackView.bottomAnchor, constant: 12),
            additionalContextLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            additionalContextLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),

            // Action button (active state) — right-aligned, height fixed
            actionButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            actionButton.heightAnchor.constraint(equalToConstant: 36),
            actionButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 90),

            // Navigation stack (answered state) — right-aligned, height fixed
            navigationStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            navigationStackView.leadingAnchor.constraint(greaterThanOrEqualTo: containerView.leadingAnchor, constant: 12),
            navigationStackView.heightAnchor.constraint(equalToConstant: 36),
        ])

        // Activate active-state dynamic constraints by default
        actionButtonTopConstraint.isActive = true
        activeContainerBottomConstraint.isActive = true
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

    /// Configure the view in answered/read-only state, reconstructing selections from the reply message.
    func configureAnswered(questions: [ClarifyingQuestion], answerText: String) {
        self.questions = questions
        self.currentIndex = 0
        // Keep the whole view interactive so Prev/Next buttons respond to taps
        isUserInteractionEnabled = true
        alpha = 1.0
        self.parsedAnswers = parseAnswers(from: answerText, questions: questions)
        showAnsweredQuestion(at: 0)
    }

    /// Lock the view after submission — dims it and disables interaction.
    func lock() {
        isUserInteractionEnabled = false
        alpha = 0.5
    }

    /// Reset to initial blank state (used in `prepareForReuse`).
    func reset() {
        questions = []
        currentIndex = 0
        selectedIndices = []
        collectedAnswers = []
        parsedAnswers = []
        counterLabel.text = nil
        questionLabel.text = nil
        additionalContextTextView.text = ""
        additionalContextTextView.isHidden = false
        placeholderLabel.isHidden = false
        additionalContextLabel.text = nil
        additionalContextLabel.isHidden = true
        navigationStackView.isHidden = true
        actionButton.isHidden = false
        optionsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        isUserInteractionEnabled = true
        alpha = 1.0
        activateActiveStateConstraints()
    }

    // MARK: - Private: Constraint Management

    private func activateActiveStateConstraints() {
        answeredContainerBottomConstraint.isActive = false
        navTopFromOptionsConstraint.isActive = false
        navTopFromLabelConstraint.isActive = false
        actionButtonTopConstraint.isActive = true
        activeContainerBottomConstraint.isActive = true
    }

    private func activateAnsweredStateConstraints(hasAdditionalText: Bool) {
        activeContainerBottomConstraint.isActive = false
        actionButtonTopConstraint.isActive = false
        if hasAdditionalText {
            navTopFromOptionsConstraint.isActive = false
            navTopFromLabelConstraint.isActive = true
        } else {
            navTopFromLabelConstraint.isActive = false
            navTopFromOptionsConstraint.isActive = true
        }
        answeredContainerBottomConstraint.isActive = true
    }

    // MARK: - Private: Rendering

    private func showQuestion(at index: Int) {
        guard index < questions.count else { return }
        let q = questions[index]

        counterLabel.text = "\(index + 1) of \(questions.count)"
        questionLabel.text = q.question
        selectedIndices = []
        additionalContextTextView.text = ""
        additionalContextTextView.isHidden = false
        additionalContextLabel.isHidden = true
        placeholderLabel.isHidden = false
        actionButton.isHidden = false
        navigationStackView.isHidden = true

        // Rebuild option pills
        optionsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (i, option) in q.options.enumerated() {
            let optionView = makeOptionView(title: option, tag: i)
            optionsStackView.addArrangedSubview(optionView)
        }

        activateActiveStateConstraints()
        updateActionButton()
        invalidateIntrinsicContentSize()
        onHeightChanged?()
    }

    private func showAnsweredQuestion(at index: Int) {
        guard index < questions.count else { return }
        let q = questions[index]
        let parsed = index < parsedAnswers.count ? parsedAnswers[index] : (selectedOptions: [String](), additionalText: nil)

        counterLabel.text = "\(index + 1) of \(questions.count)"
        questionLabel.text = q.question

        // Rebuild option pills — non-interactive, apply selected/unselected style
        optionsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (i, option) in q.options.enumerated() {
            let optionView = makeOptionView(title: option, tag: i)
            optionView.isUserInteractionEnabled = false
            let normalisedOption = normaliseForComparison(option)
            let isSelected = parsed.selectedOptions.contains {
                normaliseForComparison($0) == normalisedOption
            }
            isSelected ? applySelectedStyle(to: optionView) : applyUnselectedStyle(to: optionView)
            optionsStackView.addArrangedSubview(optionView)
        }

        // Hide active-state views
        additionalContextTextView.isHidden = true
        placeholderLabel.isHidden = true
        actionButton.isHidden = true

        // Show additional text label only when content is present
        let hasAdditionalText: Bool
        if let extra = parsed.additionalText, !extra.isEmpty {
            additionalContextLabel.text = extra
            additionalContextLabel.isHidden = false
            hasAdditionalText = true
        } else {
            additionalContextLabel.isHidden = true
            hasAdditionalText = false
        }

        // Show navigation buttons
        navigationStackView.isHidden = false
        prevButton.isEnabled = index > 0
        nextButton.isEnabled = index < questions.count - 1

        activateAnsweredStateConstraints(hasAdditionalText: hasAdditionalText)
        invalidateIntrinsicContentSize()
        onHeightChanged?()
    }

    private func makeOptionView(title: String, tag: Int) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.tag = tag
        container.layer.cornerRadius = 16
        container.layer.masksToBounds = true
        container.layer.borderWidth = 1
        container.isUserInteractionEnabled = true

        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = title
        label.font = UIFont(name: "Roboto-Regular", size: 14) ?? UIFont.systemFont(ofSize: 14)
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        container.addSubview(label)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(optionTapped(_:)))
        container.addGestureRecognizer(tap)

        applyUnselectedStyle(to: container)
        return container
    }

    private func applyUnselectedStyle(to view: UIView) {
        view.backgroundColor = UIColor.Sphinx.Body
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.Sphinx.LightDivider.cgColor
        if let label = view.subviews.first(where: { $0 is UILabel }) as? UILabel {
            label.textColor = UIColor.Sphinx.Text
        }
    }

    private func applySelectedStyle(to view: UIView) {
        view.backgroundColor = UIColor.Sphinx.PrimaryBlue
        view.layer.borderWidth = 0
        view.layer.borderColor = UIColor.clear.cgColor
        if let label = view.subviews.first(where: { $0 is UILabel }) as? UILabel {
            label.textColor = .white
        }
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

    // MARK: - Private: String helpers

    /// Normalises a string for comparison by keeping only alphanumeric characters and spaces,
    /// collapsing runs of whitespace. This removes any dash/punctuation variant regardless of
    /// Unicode code point, so "Option — subtitle" and "Option  subtitle" compare equal.
    private func normaliseForComparison(_ string: String) -> String {
        return string
            .unicodeScalars
            .map { scalar -> Character in
                let c = Character(scalar)
                return (c.isLetter || c.isNumber) ? c : " "
            }
            .reduce("") { $0 + String($1) }
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .lowercased()
    }

    // MARK: - Private: Parse answered state

    private func parseAnswers(from answerText: String, questions: [ClarifyingQuestion]) -> [(selectedOptions: [String], additionalText: String?)] {
        let blocks = answerText.components(separatedBy: "\n\n")
        var result: [(selectedOptions: [String], additionalText: String?)] = []

        for (qIndex, block) in blocks.enumerated() {
            guard qIndex < questions.count else { break }
            let question = questions[qIndex]

            // Split on "\nA: " to get answer portion
            let parts = block.components(separatedBy: "\nA: ")
            guard parts.count >= 2 else {
                result.append((selectedOptions: [], additionalText: nil))
                continue
            }
            let answerPortion = parts[1]
            let tokens = answerPortion.components(separatedBy: ", ")

            var selectedOptions: [String] = []
            var additionalTokens: [String] = []

            for token in tokens {
                let normToken = normaliseForComparison(token)
                let matchesOption = question.options.contains { opt in
                    let normOpt = normaliseForComparison(opt)
                    return normToken == normOpt
                }
                if matchesOption {
                    selectedOptions.append(token.trimmingCharacters(in: .whitespaces))
                } else if !normToken.isEmpty {
                    additionalTokens.append(token.trimmingCharacters(in: .whitespaces))
                }
            }

            let additionalText = additionalTokens.isEmpty ? nil : additionalTokens.joined(separator: ", ")
            result.append((selectedOptions: selectedOptions, additionalText: additionalText))
        }

        return result
    }

    // MARK: - Private: Actions

    @objc private func optionTapped(_ sender: UITapGestureRecognizer) {
        guard currentIndex < questions.count, let tappedView = sender.view else { return }
        let q = questions[currentIndex]
        let tappedIndex = tappedView.tag

        if q.type == "single_choice" {
            // Toggle: deselect if already selected, otherwise select tapped
            let alreadySelected = selectedIndices.contains(tappedIndex)
            selectedIndices = alreadySelected ? [] : [tappedIndex]
            optionsStackView.arrangedSubviews.compactMap { $0 as? UIView }.forEach { view in
                if !alreadySelected && view.tag == tappedIndex {
                    applySelectedStyle(to: view)
                } else {
                    applyUnselectedStyle(to: view)
                }
            }
        } else {
            // multiple_choice: toggle
            if selectedIndices.contains(tappedIndex) {
                selectedIndices.remove(tappedIndex)
                applyUnselectedStyle(to: tappedView)
            } else {
                selectedIndices.insert(tappedIndex)
                applySelectedStyle(to: tappedView)
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

        var answerString = "Q: \(q.question)\nA: \(selectedLabels.joined(separator: ", "))"
        if !contextText.isEmpty {
            if !selectedLabels.isEmpty {
                answerString = "Q: \(q.question)\nA: \(selectedLabels.joined(separator: ", ")), \(contextText)"
            } else {
                answerString = "Q: \(q.question)\nA: \(contextText)"
            }
        }
        collectedAnswers.append(answerString)

        if currentIndex == questions.count - 1 {
            onSubmit?(collectedAnswers)
        } else {
            currentIndex += 1
            showQuestion(at: currentIndex)
        }
    }

    @objc private func prevTapped() {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
        showAnsweredQuestion(at: currentIndex)
    }

    @objc private func nextTapped() {
        guard currentIndex < questions.count - 1 else { return }
        currentIndex += 1
        showAnsweredQuestion(at: currentIndex)
    }
}

// MARK: - Testing Support (internal access for unit tests)

extension ClarifyingQuestionsView {

    var optionsStackViewForTesting: UIStackView { optionsStackView }
    var additionalContextLabelForTesting: UILabel? { additionalContextLabel }
    var additionalContextTextViewForTesting: UITextView? { additionalContextTextView }
    var actionButtonForTesting: UIButton? { actionButton }
    var prevButtonForTesting: UIButton? { prevButton }
    var nextButtonForTesting: UIButton? { nextButton }
    var counterLabelForTesting: UILabel? { counterLabel }
    var navigationStackViewForTesting: UIStackView? { navigationStackView }

    /// Direct option selection for unit tests — fires the tap gesture on the option view at the given index.
    func selectOptionForTesting(at index: Int) {
        let views = optionsStackView.arrangedSubviews
        guard index < views.count else { return }
        let optionView = views[index]
        let fakeTap = UITapGestureRecognizer(target: self, action: #selector(optionTapped(_:)))
        optionView.addGestureRecognizer(fakeTap)
        optionTapped(fakeTap)
        optionView.removeGestureRecognizer(fakeTap)
    }
}

// MARK: - UITextViewDelegate

extension ClarifyingQuestionsView: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        placeholderLabel.isHidden = !textView.text.isEmpty
        updateActionButton()
    }
}
