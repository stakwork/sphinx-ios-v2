//
//  NewChatViewController+AgentExtension.swift
//  sphinx
//
//  Created for AI Agent feature.
//  Copyright © 2024 sphinx. All rights reserved.
//

import UIKit
import CoreData

extension NewChatViewController {
    
    func handleAgentMessage(text: String, completion: @escaping (Bool, String?) -> ()) {
        guard let chat = self.chat, let owner = self.owner else {
            completion(false, nil)
            return
        }

        // Dismiss any pending proposal card when the user sends a new message
        removeProposalCard()

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
    
    // MARK: - Proposal Card Observers

    func setupProposalCardObservers() {
        guard isAgentChat else { return }

        NotificationCenter.default.addObserver(
            forName: .aiAgentProposalDetected,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let proposal = notification.userInfo?["proposal"] as? AIAgentManager.PendingProposal
            else { return }
            self.showProposalCard(proposal)
        }

        NotificationCenter.default.addObserver(
            forName: .aiAgentProposalActioned,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            if let result = notification.userInfo?["result"] as? AIAgentManager.ApprovalResult {
                self.handleProposalActioned(result: result, error: nil)
            } else if let errorMsg = notification.userInfo?["error"] as? String {
                self.handleProposalActioned(result: nil, error: errorMsg)
            }
        }
    }

    // MARK: - Proposal Card Lifecycle

    func showProposalCard(_ proposal: AIAgentManager.PendingProposal) {
        bottomView.showProposalCard(
            proposal,
            onApprove: { [weak self] proposalId in
                guard let self = self else { return }
                self.bottomView.proposalCard?.showLoading()
                Task {
                    await AIAgentManager.sharedInstance.executeApproveProposal(proposalId: proposalId)
                }
                self.scrollToBottomAfterSend()
            },
            onReject: { [weak self] proposalId in
                guard let self = self else { return }
                self.bottomView.proposalCard?.showLoading()
                Task {
                    await AIAgentManager.sharedInstance.executeRejectProposal(proposalId: proposalId)
                }
                self.scrollToBottomAfterSend()
            },
            onDismiss: { [weak self] in
                self?.bottomView.hideProposalCard()
            }
        )
    }

    func handleProposalActioned(result: AIAgentManager.ApprovalResult?, error: String?) {
        bottomView.handleProposalActioned(result: result, error: error)

        if let result = result, let summaryText = result.summaryText, !summaryText.isEmpty {
            insertAgentReply(summaryText)
        }
    }

    func removeProposalCard() {
        bottomView.hideProposalCard()
    }

    func restoreProposalCardIfNeeded() {
        guard isAgentChat else { return }

        guard let proposal = AIAgentManager.sharedInstance.loadPersistedPendingProposal() else { return }

        // If the proposal was already actioned (approve/reject result exists in manager state),
        // do not restore the card.
        if AIAgentManager.sharedInstance.pendingProposal == nil {
            // Proposal was cleared (actioned) — skip restore
            return
        }

        // Ensure the manager's in-memory state is in sync
        AIAgentManager.sharedInstance.pendingProposal = proposal

        showProposalCard(proposal)
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
