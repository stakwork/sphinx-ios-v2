//
//  NewChatAccessoryView.swift
//  sphinx
//
//  Created by Tomas Timinskas on 11/05/2023.
//  Copyright © 2023 sphinx. All rights reserved.
//

import UIKit


class NewChatAccessoryView: UIView {
    
    weak var searchDelegate: ChatSearchResultsBarDelegate?

    @IBOutlet var contentView: UIView!
    
    @IBOutlet weak var normalModeStackView: UIStackView!
    @IBOutlet weak var podcastPlayerView: PodcastSmallPlayer!
    @IBOutlet weak var messageReplyView: MessageReplyView!
    @IBOutlet weak var messageFieldView: ChatMessageTextFieldView!
    @IBOutlet weak var chatSearchView: ChatSearchResultsBar!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    
    private func setup() {
        Bundle.main.loadNibNamed("NewChatAccessoryView", owner: self, options: nil)
        addSubview(contentView)
        
        contentView.frame = self.bounds
        contentView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        
        autoresizingMask = [.flexibleHeight, .flexibleWidth]
    }
}

//Field View
extension NewChatAccessoryView {
    func updateFieldStateFrom(_ chat: Chat?) {
        messageFieldView.updateFieldStateFrom(chat)
    }
    
    func configureForAgentChat() {
        messageFieldView.configureForAgentChat()
    }
    
    func setDelegates(
        messageFieldDelegate: ChatMessageTextFieldViewDelegate,
        searchDelegate: ChatSearchResultsBarDelegate? = nil
    ) {
        messageFieldView.delegate = messageFieldDelegate
        
        self.searchDelegate = searchDelegate
    }
    
    func populateMentionAutocomplete(
        mention: String
    ) {
        messageFieldView.populateMentionAutocomplete(mention: mention)
    }
    
    func setupForAttachments(
        with text: String?,
        andDelegate messageFieldDelegate: ChatMessageTextFieldViewDelegate
    ) {
        messageFieldView.delegate = messageFieldDelegate
        messageFieldView.setupForAttachments(with: text)
    }
    
    func setupForThreads(
        with delegate: ChatMessageTextFieldViewDelegate
    ) {
        messageFieldView.delegate = delegate
    }
    
    func getMessage() -> String {
        messageFieldView.getMessage()
    }
    
    func clearMessage() {
        messageFieldView.clearMessage()
    }
}

//Audio Recorder
extension NewChatAccessoryView {
    func toggleAudioRecording(show: Bool) {
        messageFieldView.toggleAudioRecording(show: show)
    }
    
    func updateRecordingAudio(minutes: String, seconds: String) {
        messageFieldView.updateRecordingAudio(minutes: minutes, seconds: seconds)
    }
}

//Podcast Player
extension NewChatAccessoryView {
    func configurePlayerWith(
        podcastId: String,
        delegate: PodcastPlayerVCDelegate,
        andKey playerDelegateKey: String
    ) {
        podcastPlayerView.configureWith(
            podcastId: podcastId,
            delegate: delegate,
            andKey: playerDelegateKey
        )
    }
}

//Message Reply View
extension NewChatAccessoryView {
    func configureReplyViewFor(
        message: TransactionMessage? = nil,
        podcastComment: PodcastComment? = nil,
        withDelegate delegate: MessageReplyViewDelegate
    ) {
        if let message = message {
            messageReplyView.configureForKeyboard(
                with: message,
                delegate: delegate
            )
            messageFieldView.textView.becomeFirstResponder()
        } else if let podcastComment = podcastComment {
            messageReplyView.configureForKeyboard(
                with: podcastComment,
                and: delegate
            )
            messageFieldView.textView.becomeFirstResponder()
        }
    }
    
    func resetReplyView() {
        messageReplyView.resetAndHideView()
    }
}

//Search Mode
extension NewChatAccessoryView {
    func configureSearchWith(
        active: Bool,
        loading: Bool,
        matchesCount: Int? = nil,
        matchIndex: Int = 0
    ) {
        normalModeStackView.isHidden = active
        chatSearchView.isHidden = !active
        
        chatSearchView.configureWith(
            matchesCount: matchesCount,
            matchIndex: matchIndex,
            loading: loading,
            delegate: self
        )
    }
    
    func shouldToggleSearchLoadingWheel(active: Bool) {
        chatSearchView.toggleLoadingWheel(active: active)
    }
}

extension NewChatAccessoryView : ChatSearchResultsBarDelegate {
    func didTapNavigateArrowButton(button: ChatSearchResultsBar.NavigateArrowButton) {
        searchDelegate?.didTapNavigateArrowButton(button: button)
    }
}

// MARK: - Proposal Card Management

extension NewChatAccessoryView {

    private(set) var proposalCard: ProposalApprovalCardView? {
        get { objc_getAssociatedObject(self, &AssociatedKeys.proposalCard) as? ProposalApprovalCardView }
        set { objc_setAssociatedObject(self, &AssociatedKeys.proposalCard, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    var hasProposalCard: Bool { proposalCard != nil }

    func showProposalCard(
        _ proposal: AIAgentManager.PendingProposal,
        onApprove: @escaping (String) -> Void,
        onReject:  @escaping (String) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        hideProposalCard()

        let card = ProposalApprovalCardView(proposal: proposal)
        card.translatesAutoresizingMaskIntoConstraints = false
        card.alpha = 0

        card.onApprove = onApprove
        card.onReject  = onReject
        card.onDismiss = { [weak self] in
            self?.hideProposalCard()
            onDismiss()
        }

        normalModeStackView.insertArrangedSubview(card, at: 0)

        // Pin width to stack minus 32pt padding (16 each side)
        NSLayoutConstraint.activate([
            card.widthAnchor.constraint(
                equalTo: normalModeStackView.widthAnchor,
                constant: -32
            )
        ])

        proposalCard = card

        UIView.animate(withDuration: 0.2) {
            card.alpha = 1
        }
    }

    func hideProposalCard() {
        guard let card = proposalCard else { return }
        proposalCard = nil
        UIView.animate(withDuration: 0.2, animations: {
            card.alpha = 0
        }, completion: { _ in
            card.removeFromSuperview()
        })
    }

    func handleProposalActioned(
        result: AIAgentManager.ApprovalResult?,
        error: String?
    ) {
        guard let card = proposalCard else { return }
        if let result = result {
            card.showStamp(approved: result.approved)
        } else if let error = error {
            card.showError(error)
        }
    }
}

// MARK: - Associated Object Keys

private enum AssociatedKeys {
    static var proposalCard: UInt8 = 0
}
