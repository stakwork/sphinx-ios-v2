//
//  ActiveCallBannerView.swift
//  sphinx
//
//  Created for the live-call banner stack feature.
//  Copyright © 2024 sphinx. All rights reserved.
//

import UIKit

// MARK: - Delegate

@MainActor
protocol ActiveCallBannerDelegate: AnyObject {
    func didTapJoin(callLink: String)
    func didTapOpen(callLink: String)
}

// MARK: - ActiveCallBannerView

/// A single banner row representing one active call. Shows live participant avatars
/// and a "Join" or "Open" action button.
///
/// Embed multiple instances in `NewChatHeaderView.liveCallBannerStack`.
final class ActiveCallBannerView: UIView {

    // MARK: - Constants

    private enum Layout {
        static let participantBoxWidth: CGFloat  = 42
        static let participantBoxHeight: CGFloat = 54
        static let bannerHeight: CGFloat         = 66
        static let horizontalPadding: CGFloat    = 12
        static let interItemSpacing: CGFloat     = 6
        static let buttonWidth: CGFloat          = 64
        static let buttonHeight: CGFloat         = 32
        static let liveIndicatorSize: CGFloat    = 8
    }

    // MARK: - Public State

    private(set) var callLink: String = ""
    private(set) var isAlreadyInCall: Bool = false
    private weak var delegate: ActiveCallBannerDelegate?

    // MARK: - Subviews

    /// Horizontal scrollable row of `ParticipantBoxView` items.
    private let participantsScrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsHorizontalScrollIndicator = false
        sv.showsVerticalScrollIndicator = false
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let participantsStackView: UIStackView = {
        let sv = UIStackView()
        sv.axis = .horizontal
        sv.alignment = .center
        sv.spacing = Layout.interItemSpacing
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let liveDot: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.Sphinx.PrimaryRed
        v.layer.cornerRadius = Layout.liveIndicatorSize / 2
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let liveTitleLabel: UILabel = {
        let l = UILabel()
        l.text = "live.call".localized
        l.font = UIFont(name: "Roboto-Bold", size: 11) ?? UIFont.systemFont(ofSize: 11, weight: .bold)
        l.textColor = UIColor.Sphinx.Text
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let actionButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.layer.cornerRadius = 6
        btn.clipsToBounds = true
        btn.titleLabel?.font = UIFont(name: "Roboto-Bold", size: 12) ?? UIFont.systemFont(ofSize: 12, weight: .bold)
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()

    private let separatorLine: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.Sphinx.Text.withAlphaComponent(0.1)
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    // MARK: - Setup

    private func setupViews() {
        backgroundColor = UIColor.Sphinx.Body

        // Separator at bottom
        addSubview(separatorLine)
        NSLayoutConstraint.activate([
            separatorLine.leadingAnchor.constraint(equalTo: leadingAnchor),
            separatorLine.trailingAnchor.constraint(equalTo: trailingAnchor),
            separatorLine.bottomAnchor.constraint(equalTo: bottomAnchor),
            separatorLine.heightAnchor.constraint(equalToConstant: 1),
        ])

        // Live dot + title (left side)
        addSubview(liveDot)
        addSubview(liveTitleLabel)
        NSLayoutConstraint.activate([
            liveDot.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Layout.horizontalPadding),
            liveDot.centerYAnchor.constraint(equalTo: centerYAnchor),
            liveDot.widthAnchor.constraint(equalToConstant: Layout.liveIndicatorSize),
            liveDot.heightAnchor.constraint(equalToConstant: Layout.liveIndicatorSize),

            liveTitleLabel.leadingAnchor.constraint(equalTo: liveDot.trailingAnchor, constant: 4),
            liveTitleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        // Action button (right side)
        addSubview(actionButton)
        NSLayoutConstraint.activate([
            actionButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Layout.horizontalPadding),
            actionButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            actionButton.widthAnchor.constraint(equalToConstant: Layout.buttonWidth),
            actionButton.heightAnchor.constraint(equalToConstant: Layout.buttonHeight),
        ])
        actionButton.addTarget(self, action: #selector(actionButtonTapped), for: .touchUpInside)

        // Participants scroll view (fills space between title label and button)
        addSubview(participantsScrollView)
        participantsScrollView.addSubview(participantsStackView)

        NSLayoutConstraint.activate([
            participantsScrollView.leadingAnchor.constraint(equalTo: liveTitleLabel.trailingAnchor, constant: 8),
            participantsScrollView.trailingAnchor.constraint(equalTo: actionButton.leadingAnchor, constant: -8),
            participantsScrollView.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            participantsScrollView.bottomAnchor.constraint(equalTo: separatorLine.topAnchor, constant: -6),

            participantsStackView.leadingAnchor.constraint(equalTo: participantsScrollView.contentLayoutGuide.leadingAnchor),
            participantsStackView.trailingAnchor.constraint(equalTo: participantsScrollView.contentLayoutGuide.trailingAnchor),
            participantsStackView.topAnchor.constraint(equalTo: participantsScrollView.contentLayoutGuide.topAnchor),
            participantsStackView.bottomAnchor.constraint(equalTo: participantsScrollView.contentLayoutGuide.bottomAnchor),
            participantsStackView.heightAnchor.constraint(equalTo: participantsScrollView.frameLayoutGuide.heightAnchor),
        ])

        // Fixed banner height
        heightAnchor.constraint(equalToConstant: Layout.bannerHeight).isActive = true
    }

    // MARK: - Configuration

    /// Configure the banner with the current participants, call link, and in-call state.
    ///
    /// - Parameters:
    ///   - participants: Live participants currently in the call.
    ///   - callLink: The call URL used for Join/Open actions.
    ///   - isAlreadyInCall: `true` shows "Open", `false` shows "Join".
    ///   - delegate: Receives tap callbacks.
    func configureWith(
        participants: [BubbleMessageLayoutState.CallParticipantInfo],
        callLink: String,
        isAlreadyInCall: Bool,
        delegate: ActiveCallBannerDelegate
    ) {
        self.callLink = callLink
        self.isAlreadyInCall = isAlreadyInCall
        self.delegate = delegate

        rebuildParticipantRow(participants: participants)
        updateActionButton(isAlreadyInCall: isAlreadyInCall)

        // The owning stack manages show/hide; hide participants row if empty.
        participantsScrollView.isHidden = participants.isEmpty
        liveDot.isHidden = participants.isEmpty
    }

    // MARK: - Private Helpers

    private func rebuildParticipantRow(participants: [BubbleMessageLayoutState.CallParticipantInfo]) {
        participantsStackView.arrangedSubviews.forEach {
            participantsStackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        for participant in participants {
            let box = ParticipantBoxView()
            box.configure(with: participant)
            box.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                box.widthAnchor.constraint(equalToConstant: Layout.participantBoxWidth),
                box.heightAnchor.constraint(equalToConstant: Layout.participantBoxHeight),
            ])
            participantsStackView.addArrangedSubview(box)
        }
    }

    private func updateActionButton(isAlreadyInCall: Bool) {
        let title = isAlreadyInCall
            ? "open.call".localized
            : "join.call.short".localized
        actionButton.setTitle(title, for: .normal)
        actionButton.backgroundColor = UIColor.Sphinx.PrimaryBlue
        actionButton.setTitleColor(.white, for: .normal)
    }

    // MARK: - Actions

    @objc private func actionButtonTapped() {
        if isAlreadyInCall {
            delegate?.didTapOpen(callLink: callLink)
        } else {
            delegate?.didTapJoin(callLink: callLink)
        }
    }
}
