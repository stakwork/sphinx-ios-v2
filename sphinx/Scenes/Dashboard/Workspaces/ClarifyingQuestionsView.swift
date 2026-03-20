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
            actionButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -12),
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

    /// Reset to initial blank state (used in `prepareForReuse`).
    func reset() {
        questions = []
        currentIndex = 0
        selectedIndices = []
        collectedAnswers = []
        counterLabel.text = nil
        questionLabel.text = nil
        additionalContextTextView.text = ""
        placeholderLabel.isHidden = false
        optionsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        isUserInteractionEnabled = true
        alpha = 1.0
    }

    // MARK: - Private: Rendering

    private func showQuestion(at index: Int) {
        guard index < questions.count else { return }
        let q = questions[index]

        counterLabel.text = "\(index + 1) of \(questions.count)"
        questionLabel.text = q.question
        selectedIndices = []
        additionalContextTextView.text = ""
        placeholderLabel.isHidden = false

        // Rebuild option pills
        optionsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (i, option) in q.options.enumerated() {
            let btn = makeOptionButton(title: option, tag: i)
            optionsStackView.addArrangedSubview(btn)
        }

        updateActionButton()
        invalidateIntrinsicContentSize()
        onHeightChanged?()
    }

    private func makeOptionButton(title: String, tag: Int) -> UIButton {
        let btn = UIButton(type: .system)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.tag = tag

        var config = UIButton.Configuration.plain()
        config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attrs in
            var updated = attrs
            updated.font = UIFont(name: "Roboto-Regular", size: 14) ?? UIFont.systemFont(ofSize: 14)
            return updated
        }
        config.title = title
        btn.configuration = config

        // Multiline + font auto-scaling
        btn.titleLabel?.numberOfLines = 0
        btn.titleLabel?.lineBreakMode = .byWordWrapping
        btn.titleLabel?.adjustsFontSizeToFitWidth = true
        btn.titleLabel?.minimumScaleFactor = 0.75

        btn.layer.cornerRadius = 12
        btn.layer.masksToBounds = true
        btn.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        btn.addTarget(self, action: #selector(optionTapped(_:)), for: .touchUpInside)
        applyUnselectedStyle(to: btn)
        return btn
    }

    private func applyUnselectedStyle(to button: UIButton) {
        button.configuration?.background.backgroundColor = UIColor.Sphinx.Body
        button.configuration?.baseForegroundColor = UIColor.Sphinx.Text
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.Sphinx.LightDivider.cgColor
    }

    private func applySelectedStyle(to button: UIButton) {
        button.configuration?.background.backgroundColor = UIColor.Sphinx.PrimaryBlue
        button.configuration?.baseForegroundColor = .white
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

        var answerString = "Q\(currentIndex + 1): \(selectedLabels.joined(separator: ", "))"
        if !contextText.isEmpty {
            answerString += " | Additional: \(contextText)"
        }
        collectedAnswers.append(answerString)

        if currentIndex == questions.count - 1 {
            onSubmit?(collectedAnswers)
        } else {
            currentIndex += 1
            showQuestion(at: currentIndex)
        }
    }
}

// MARK: - UITextViewDelegate

extension ClarifyingQuestionsView: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        placeholderLabel.isHidden = !textView.text.isEmpty
        updateActionButton()
    }
}
