//
//  NewChatViewController+AgentExtension.swift
//  sphinx
//
//  Created for AI Agent feature.
//  Copyright © 2024 sphinx. All rights reserved.
//

import UIKit
import CoreData

// MARK: - Stored association key for proposal card
private var proposalCardKey: UInt8 = 0

extension NewChatViewController {

    // MARK: - Proposal card (associated object, since extensions can't add stored props)

    var proposalCard: ProposalApprovalCardView? {
        get { objc_getAssociatedObject(self, &proposalCardKey) as? ProposalApprovalCardView }
        set { objc_setAssociatedObject(self, &proposalCardKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    // MARK: - Proposal card lifecycle

    func setupProposalCardObservers() {
        guard isAgentChat else { return }

        NotificationCenter.default.addObserver(
            forName: .aiAgentProposalDetected,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let proposal = note.object as? AIAgentManager.PendingProposal else { return }
            self?.showProposalCard(proposal)
        }

        NotificationCenter.default.addObserver(
            forName: .aiAgentProposalActioned,
            object: nil,
            queue: .main
        ) { [weak self] note in
            self?.handleProposalActioned(note.object as? AIAgentManager.ApprovalResult)
        }

        // Restore card on relaunch if there's an unactioned pending proposal
        restoreProposalCardIfNeeded()
    }

    func showProposalCard(_ proposal: AIAgentManager.PendingProposal) {
        removeProposalCard()
        let card = ProposalApprovalCardView(proposal: proposal)
        card.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(card)
        NSLayoutConstraint.activate([
            card.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            card.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            card.bottomAnchor.constraint(equalTo: bottomView.topAnchor, constant: -8)
        ])
        card.alpha = 0
        UIView.animate(withDuration: 0.25) { card.alpha = 1 }

        card.onApprove = { [weak self] pid in
            Task {
                let _ = await AIAgentManager.sharedInstance.executeApproveProposal(proposalId: pid)
            }
        }
        card.onReject = { [weak self] pid in
            Task {
                let _ = await AIAgentManager.sharedInstance.executeRejectProposal(proposalId: pid)
            }
        }
        proposalCard = card
    }

    func handleProposalActioned(_ result: AIAgentManager.ApprovalResult?) {
        guard let card = proposalCard else { return }
        if let result = result {
            card.showStamp(approved: result.approved)
            // nil out after card auto-dismisses (2s + animation)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
                self?.proposalCard = nil
            }
        } else {
            // POST failed — revert to actionable + show toast
            card.resetToActionable()
            showProposalErrorToast()
        }
    }

    func removeProposalCard() {
        proposalCard?.removeFromSuperview()
        proposalCard = nil
    }

    private func showProposalErrorToast() {
        // Reuse existing generic error pattern
        let alert = UIAlertController(
            title: "Action Failed",
            message: "Could not complete the request. Please try again.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func restoreProposalCardIfNeeded() {
        guard let pending = AIAgentManager.sharedInstance.pendingProposal else { return }
        // Check if it was already actioned in canvas history
        let proposalNames: Set<String> = ["propose_feature", "propose_initiative", "propose_milestone"]
        let alreadyActioned = AIAgentManager.sharedInstance.canvasChatHistory.contains(where: {
            $0.toolCalls?.contains(where: {
                proposalNames.contains($0.toolName) &&
                ($0.output?["proposalId"] == pending.proposalId || $0.input?["proposalId"] == pending.proposalId)
            }) == true && $0.approvalResult != nil
        })
        if !alreadyActioned {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.showProposalCard(pending)
            }
        }
    }

    // MARK: - Agent message handling

    func handleAgentMessage(text: String, completion: @escaping (Bool, String?) -> ()) {
        guard let chat = self.chat, let owner = self.owner else {
            completion(false, nil)
            return
        }
        
        bottomView.resetReplyView()
        ChatTrackingHandler.shared.deleteReplyableMessage(with: chat.id)
        
        let outgoing = TransactionMessage(context: CoreDataManager.sharedManager.persistentContainer.viewContext)
        outgoing.id = SphinxOnionManager.sharedInstance.uniqueIntHashFromString(stringInput: UUID().uuidString)
        outgoing.type = TransactionMessage.TransactionMessageType.message.rawValue
        outgoing.status = TransactionMessage.TransactionMessageStatus.received.rawValue
        outgoing.senderId = owner.id
        outgoing.receiverId = AIAgentManager.agentLocalId
        outgoing.messageContent = text
        outgoing.date = Date()
        outgoing.seen = true
        outgoing.encrypted = false
        outgoing.push = false
        outgoing.chat = chat
        chat.setLastMessage(outgoing)
        CoreDataManager.sharedManager.saveContext()
        completion(true, nil)
        
//        showAgentProcessingBar()
        
        Task {
            let reply = await AIAgentManager.sharedInstance.chat(text)
            await MainActor.run { self.insertAgentReply(reply) }
        }
    }
    
    func insertAgentReply(_ text: String) {
        hideAgentProcessingBar()
        guard let chat = self.chat, let owner = self.owner else { return }
        
        let incoming = TransactionMessage(context: CoreDataManager.sharedManager.persistentContainer.viewContext)
        incoming.id = SphinxOnionManager.sharedInstance.uniqueIntHashFromString(stringInput: UUID().uuidString)
        incoming.type = TransactionMessage.TransactionMessageType.message.rawValue
        incoming.status = TransactionMessage.TransactionMessageStatus.received.rawValue
        incoming.senderId = AIAgentManager.agentLocalId
        incoming.receiverId = owner.id
        incoming.messageContent = text
        incoming.date = Date()
        incoming.seen = false
        incoming.encrypted = false
        incoming.push = false
        incoming.chat = chat
        chat.seen = false
        chat.setLastMessage(incoming)
        CoreDataManager.sharedManager.saveContext()
        NotificationCenter.default.post(name: .onContactsAndChatsChanged, object: nil)
    }
    
    func insertIntroMessageIfNeeded() {
        guard isAgentChat,
              let chat = self.chat,
              let owner = self.owner,
              chat.lastMessage == nil else { return }
        
        let introText: String
        if AIAgentManager.sharedInstance.isConfigured {
            introText = """
👋 Hi! I'm your Sphinx AI assistant. Here's what I can do:

• 📖 Read recent or unread messages from any contact or tribe
• 👥 List all your contacts and tribes
• 👤 View and update your profile (nickname, tip amount)
• ✅ Mark chats as read
• 🔗 Connect with new users
• 🏕️ Create new tribes
• 🔍 Search the web for current info
• 🪵 Read and analyze app logs (filter by time, level, or keyword)
• 🤖 Ask Jamie anything about your org — features, tasks, codebase, project status
• 🐝 Browse, search & manage Hive workspaces, features, and tasks
• ✅ Approve or reject Jamie proposals directly from chat
"""
        } else {
            introText = "👋 Welcome to Sphinx AI! To get started, go to Profile → Configure AI Agent and enter your Anthropic or OpenAI API key."
        }
        
        let intro = TransactionMessage(context: CoreDataManager.sharedManager.persistentContainer.viewContext)
        intro.id = SphinxOnionManager.sharedInstance.uniqueIntHashFromString(stringInput: UUID().uuidString)
        intro.type = TransactionMessage.TransactionMessageType.message.rawValue
        intro.status = TransactionMessage.TransactionMessageStatus.received.rawValue
        intro.senderId = AIAgentManager.agentLocalId
        intro.receiverId = owner.id
        intro.messageContent = introText
        intro.date = Date()
        intro.seen = false
        intro.encrypted = false
        intro.push = false
        intro.chat = chat
        chat.seen = false
        chat.setLastMessage(intro)
        CoreDataManager.sharedManager.saveContext()
        AIAgentManager.sharedInstance.appendAssistantMessage(introText)
    }
}
