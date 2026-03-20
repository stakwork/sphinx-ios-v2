//
//  ClarifyingQuestionMessageCell.swift
//  sphinx
//
//  Created on 2026-03-20.
//  Copyright © 2026 sphinx. All rights reserved.
//

import UIKit

class ClarifyingQuestionMessageCell: UITableViewCell {

    static let reuseIdentifier = "ClarifyingQuestionMessageCell"

    // MARK: - UI Components

    private let clarifyingQuestionsView: ClarifyingQuestionsView = {
        let v = ClarifyingQuestionsView()
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let timestampLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont(name: "Roboto-Regular", size: 11)
        label.textColor = UIColor.Sphinx.SecondaryText
        label.textAlignment = .left
        return label
    }()

    // MARK: - Callbacks

    var onClarifyingAnswerSubmit: ((_ answers: [String], _ replyId: String) -> Void)?
    var onHeightChanged: (() -> Void)?

    // MARK: - Init

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    // MARK: - Layout

    private func setupUI() {
        backgroundColor = .Sphinx.Body
        contentView.backgroundColor = .Sphinx.Body
        selectionStyle = .none

        contentView.addSubview(clarifyingQuestionsView)
        contentView.addSubview(timestampLabel)

        NSLayoutConstraint.activate([
            clarifyingQuestionsView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            clarifyingQuestionsView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            clarifyingQuestionsView.widthAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: 0.8),

            timestampLabel.topAnchor.constraint(equalTo: clarifyingQuestionsView.bottomAnchor, constant: 4),
            timestampLabel.leadingAnchor.constraint(equalTo: clarifyingQuestionsView.leadingAnchor),
            timestampLabel.trailingAnchor.constraint(equalTo: clarifyingQuestionsView.trailingAnchor),
            timestampLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
        ])
    }

    // MARK: - Configure

    func configure(with message: HiveChatMessage, isLastMessage: Bool, answerMessage: HiveChatMessage? = nil) {
        guard let cqArtifact = message.artifacts.first(where: { $0.isClarifyingQuestions }),
              let questions = cqArtifact.clarifyingQuestions, !questions.isEmpty else { return }

        clarifyingQuestionsView.configure(with: questions)

        if !isLastMessage {
            if let answerMsg = answerMessage,
               !answerMsg.message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                clarifyingQuestionsView.configureAnswered(questions: questions, answerText: answerMsg.message)
            } else {
                clarifyingQuestionsView.lock()
            }
        }

        clarifyingQuestionsView.onSubmit = { [weak self] answers in
            self?.onClarifyingAnswerSubmit?(answers, message.id)
        }

        clarifyingQuestionsView.onHeightChanged = { [weak self] in
            self?.onHeightChanged?()
        }

        if let ts = message.createdAt {
            timestampLabel.text = formatTimestamp(ts)
            timestampLabel.isHidden = false
        } else {
            timestampLabel.isHidden = true
        }
    }

    // MARK: - Lock

    func lockClarifyingQuestionsView() {
        clarifyingQuestionsView.lock()
    }

    // MARK: - Reuse

    override func prepareForReuse() {
        super.prepareForReuse()
        clarifyingQuestionsView.reset()
        onClarifyingAnswerSubmit = nil
        onHeightChanged = nil
        timestampLabel.text = nil
    }

    // MARK: - Helpers

    private func formatTimestamp(_ timestamp: String) -> String {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = iso.date(from: timestamp)
        if date == nil {
            iso.formatOptions = [.withInternetDateTime]
            date = iso.date(from: timestamp)
        }
        guard let d = date else { return timestamp }
        let fmt = DateFormatter()
        fmt.dateFormat = "h:mm a"
        return fmt.string(from: d)
    }
}
