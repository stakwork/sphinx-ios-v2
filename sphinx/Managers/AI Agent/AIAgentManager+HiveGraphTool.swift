//
//  AIAgentManager+HiveGraphTool.swift
//  sphinx
//
//  Created for Sphinx Agent Graph Chat integration.
//  Copyright © 2026 sphinx. All rights reserved.
//

import Foundation
import SwiftAISDK

// MARK: - Notification Names

extension Notification.Name {
    static let aiAgentProposalDetected = Notification.Name("aiAgentProposalDetected")
    static let aiAgentProposalActioned = Notification.Name("aiAgentProposalActioned")
}

// MARK: - Codable Models

extension AIAgentManager {

    struct CanvasChatMessage: Codable {
        let role: String          // "user" or "assistant"
        let content: String
        var toolCalls: [ToolCall]?
        var approvalResult: ApprovalResult?
    }

    struct ToolCall: Codable {
        let toolName: String
        var input: [String: String]?
        var output: [String: String]?
    }

    struct ProposalOutput: Codable {
        let proposalId: String
        let kind: String
        let title: String
        let description: String?
    }

    struct ApprovalIntent: Codable {
        let proposalId: String
        let currentRef: String?
    }

    struct RejectionIntent: Codable {
        let proposalId: String
    }

    struct ApprovalResult: Codable {
        let approved: Bool
        let proposalId: String
        let message: String?
    }

    // Transient — never persisted, rebuilt from canvasChatHistory on each finish
    struct PendingProposal {
        let proposalId: String
        let kind: String
        let title: String
        let description: String?
    }
}

// MARK: - HiveGraphBridge

/// Bridges GraphChatSSEDelegate callbacks to a CheckedContinuation<String, Never>.
private class HiveGraphBridge: GraphChatSSEDelegate {

    var continuation: CheckedContinuation<String, Never>?
    var sseManager: GraphChatSSEManager?
    var buffer: String = ""
    var resumed: Bool = false
    var capturedToolCalls: [AIAgentManager.ToolCall] = []

    func onTextDelta(_ delta: String) {
        buffer += delta
    }

    func onFinish() {
        guard !resumed else { return }
        resumed = true
        let result = buffer.isEmpty ? "No response." : buffer
        print("AIAgent [HiveGraph] finished, buffer length: \(buffer.count)")
        sseManager?.stopOrgStream()
        continuation?.resume(returning: result)
    }

    func onError(_ text: String) {
        guard !resumed else { return }
        resumed = true
        print("AIAgent [HiveGraph] error: \(text)")
        sseManager?.stopOrgStream()
        continuation?.resume(returning: "Hive graph error: \(text)")
    }

    func onToolInputAvailable(toolName: String) {}

    func onToolCall(toolName: String, input: [String: Any]?) {
        let stringInput = input?.compactMapValues { "\($0)" }
        capturedToolCalls.append(AIAgentManager.ToolCall(toolName: toolName, input: stringInput, output: nil))
    }

    func onToolOutputAvailable(toolName: String, output: [String: Any]?) {
        let stringOutput = output?.compactMapValues { "\($0)" }
        if let idx = capturedToolCalls.indices.last(where: { capturedToolCalls[$0].toolName == toolName }) {
            capturedToolCalls[idx] = AIAgentManager.ToolCall(
                toolName: capturedToolCalls[idx].toolName,
                input: capturedToolCalls[idx].input,
                output: stringOutput
            )
        }
    }
}

// MARK: - AIAgentManager + Canvas History

extension AIAgentManager {

    var canvasChatHistory: [CanvasChatMessage] {
        get { _canvasChatHistory }
        set { _canvasChatHistory = newValue }
    }

    func loadCanvasHistory(orgId: String) {
        guard let data: Data = UserDefaults.Keys.hiveCanvasChatHistoryByOrg.get(),
              let dict = try? JSONDecoder().decode([String: [CanvasChatMessage]].self, from: data)
        else { return }
        _canvasChatHistory = dict[orgId] ?? []
    }

    func persistCanvasHistory(orgId: String) {
        var dict: [String: [CanvasChatMessage]] = [:]
        if let data: Data = UserDefaults.Keys.hiveCanvasChatHistoryByOrg.get(),
           let existing = try? JSONDecoder().decode([String: [CanvasChatMessage]].self, from: data) {
            dict = existing
        }
        dict[orgId] = _canvasChatHistory
        if let encoded = try? JSONEncoder().encode(dict) {
            UserDefaults.Keys.hiveCanvasChatHistoryByOrg.set(encoded)
            print("AIAgent [HiveGraph] canvas history persisted — \(_canvasChatHistory.count) messages")
        }
    }
}

// MARK: - AIAgentManager + query_hive_graph tool

extension AIAgentManager {

    struct QueryHiveGraphInput: Codable, Sendable {
        let question: String
    }

    func buildQueryHiveGraphTool() -> TypedTool<QueryHiveGraphInput, JSONValue> {
        tool(
            description: "Query the Hive org knowledge graph via Jamie (the Hive AI agent). DEFAULT tool for any Hive question that is analytical, open-ended, or requires org-wide context — features, tasks, workspaces, codebase, architecture, team activity, or project status. Call this proactively WITHOUT waiting for the user to mention 'Jamie'. No workspace name needed. Only skip in favour of specific Hive CRUD tools when the user explicitly requests a targeted operation (list, detail, create, update, archive).",
            execute: { (input: QueryHiveGraphInput, _: ToolCallOptions) async throws -> ToolExecutionResult<JSONValue> in

                let question = input.question

                // 1. Ensure org slugs are cached (refresh if stale)
                var slugs = AIAgentManager.cachedOrgSlugs()
                if slugs == nil {
                    await AIAgentManager.fetchAndCacheOrgSlugs()
                    slugs = AIAgentManager.cachedOrgSlugs()
                }
                guard let orgSlugs = slugs, !orgSlugs.isEmpty else {
                    return .value(.string("Hive org not configured. Please check your Hive connection in settings."))
                }
                guard let orgId: String = UserDefaults.Keys.hiveOrgId.get(), !orgId.isEmpty else {
                    return .value(.string("Hive org ID not found. Please reconfigure your Hive connection."))
                }

                // 2. Load canvas history for this org
                self.loadCanvasHistory(orgId: orgId)

                // 3. Read persisted conversationId for this org (nil on first call).
                let conversationId: String? = {
                    guard let data: Data = UserDefaults.Keys.hiveConversationIdByOrg.get(),
                          let dict = try? JSONDecoder().decode([String: String].self, from: data) else { return nil }
                    return dict[orgId]
                }()

                // 4. Resolve auth token
                let token: String? = await withCheckedContinuation { cont in
                    API.sharedInstance.resolveHiveToken(
                        callback: { cont.resume(returning: $0) },
                        errorCallback: { cont.resume(returning: nil) }
                    )
                }
                guard let token = token else {
                    return .value(.string("Hive authentication failed. Please check your Hive configuration."))
                }

                // 5. Stream via org SSE
                let bridge = HiveGraphBridge()
                let sseManager = GraphChatSSEManager()
                bridge.sseManager = sseManager
                sseManager.delegate = bridge

                print("AIAgent [HiveGraph] querying org '\(orgId)' with \(orgSlugs.count) slug(s): \(question)")

                let result: String = await withCheckedContinuation { cont in
                    bridge.continuation = cont
                    sseManager.startOrgStream(
                        question: question,
                        orgSlugs: orgSlugs,
                        orgId: orgId,
                        conversationId: conversationId,
                        token: token,
                        onConversationId: { newCid in
                            // Persist conversationId keyed by orgId
                            var dict: [String: String] = [:]
                            if let data: Data = UserDefaults.Keys.hiveConversationIdByOrg.get(),
                               let existing = try? JSONDecoder().decode([String: String].self, from: data) {
                                dict = existing
                            }
                            dict[orgId] = newCid
                            if let encoded = try? JSONEncoder().encode(dict) {
                                UserDefaults.Keys.hiveConversationIdByOrg.set(encoded)
                            }
                        }
                    )
                }

                // 6. Append to canvas history
                self._canvasChatHistory.append(CanvasChatMessage(role: "user", content: question))

                let assistantMsg = CanvasChatMessage(
                    role: "assistant",
                    content: result,
                    toolCalls: bridge.capturedToolCalls.isEmpty ? nil : bridge.capturedToolCalls
                )
                self._canvasChatHistory.append(assistantMsg)
                self.persistCanvasHistory(orgId: orgId)
                print("AIAgent [HiveGraph] canvas history updated — \(self._canvasChatHistory.count) messages")

                // 7. Proposal detection
                let proposalNames: Set<String> = ["propose_feature", "propose_initiative", "propose_milestone"]
                if let tc = assistantMsg.toolCalls?.first(where: { proposalNames.contains($0.toolName) }),
                   let pid   = tc.output?["proposalId"] ?? tc.input?["proposalId"],
                   let kind  = tc.output?["kind"]       ?? tc.input?["kind"],
                   let title = tc.output?["title"]      ?? tc.input?["title"] {
                    let proposal = PendingProposal(
                        proposalId: pid, kind: kind, title: title,
                        description: tc.output?["description"] ?? tc.input?["description"]
                    )
                    self._pendingProposal = proposal
                    print("AIAgent [HiveGraph] proposal detected — id: \(pid), kind: \(kind)")
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .aiAgentProposalDetected, object: proposal)
                    }
                }

                return .value(.string(result))
            }
        )
    }
}

// MARK: - AIAgentManager + approve_proposal / reject_proposal tools

extension AIAgentManager {

    struct ApproveProposalInput: Codable, Sendable {
        let proposalId: String
    }

    struct RejectProposalInput: Codable, Sendable {
        let proposalId: String
    }

    func buildApproveProposalTool() -> TypedTool<ApproveProposalInput, JSONValue> {
        tool(
            description: "Approve a proposal from Jamie. Only call this when the user confirms approval of a visible proposal card. Use the proposalId from the current canvasChatHistory — never fabricate one.",
            execute: { (input: ApproveProposalInput, _: ToolCallOptions) async throws -> ToolExecutionResult<JSONValue> in
                return await self.executeApproveProposal(proposalId: input.proposalId)
            }
        )
    }

    func buildRejectProposalTool() -> TypedTool<RejectProposalInput, JSONValue> {
        tool(
            description: "Reject a proposal from Jamie. Only call this when the user confirms rejection of a visible proposal card. Use the proposalId from the current canvasChatHistory — never fabricate one.",
            execute: { (input: RejectProposalInput, _: ToolCallOptions) async throws -> ToolExecutionResult<JSONValue> in
                return await self.executeRejectProposal(proposalId: input.proposalId)
            }
        )
    }

    func executeApproveProposal(proposalId: String) async -> ToolExecutionResult<JSONValue> {
        let proposalNames: Set<String> = ["propose_feature", "propose_initiative", "propose_milestone"]

        // IDOR guard: proposalId must exist in canvasChatHistory
        guard _canvasChatHistory.contains(where: {
            $0.toolCalls?.contains(where: {
                proposalNames.contains($0.toolName) &&
                ($0.output?["proposalId"] == proposalId || $0.input?["proposalId"] == proposalId)
            }) == true
        }) else {
            return .value(.string("Proposal not found in current conversation. Cannot approve."))
        }

        // Idempotency: check if already actioned
        if let idx = _canvasChatHistory.indices.last(where: {
            _canvasChatHistory[$0].toolCalls?.contains(where: {
                proposalNames.contains($0.toolName) &&
                ($0.output?["proposalId"] == proposalId || $0.input?["proposalId"] == proposalId)
            }) == true
        }), _canvasChatHistory[idx].approvalResult != nil {
            return .value(.string("This proposal has already been actioned."))
        }

        guard let orgId: String = UserDefaults.Keys.hiveOrgId.get(), !orgId.isEmpty,
              let data: Data = UserDefaults.Keys.hiveConversationIdByOrg.get(),
              let dict = try? JSONDecoder().decode([String: String].self, from: data),
              let conversationId = dict[orgId]
        else {
            return .value(.string("Missing org context. Cannot approve."))
        }

        let turnId = UUID().uuidString
        let token: String? = await withCheckedContinuation { cont in
            API.sharedInstance.resolveHiveToken(callback: { cont.resume(returning: $0) }, errorCallback: { cont.resume(returning: nil) })
        }
        guard let token = token else {
            return .value(.string("Authentication failed. Cannot approve."))
        }

        print("AIAgent [HiveGraph] approve_proposal firing — proposalId: \(proposalId), turnId: \(turnId)")

        // Serialise canvasChatHistory for the request body
        let messages = (try? JSONEncoder().encode(_canvasChatHistory)).flatMap {
            try? JSONSerialization.jsonObject(with: $0) as? [[String: Any]]
        } ?? []

        return await withCheckedContinuation { cont in
            API.sharedInstance.sendApprovalIntent(
                orgId: orgId,
                conversationId: conversationId,
                turnId: turnId,
                proposalId: proposalId,
                canvasChatMessages: messages,
                token: token
            ) { result in
                if let result = result {
                    // Stamp onto the assistant message in history
                    let proposalNamesLocal: Set<String> = ["propose_feature", "propose_initiative", "propose_milestone"]
                    if let idx = self._canvasChatHistory.indices.last(where: {
                        self._canvasChatHistory[$0].toolCalls?.contains(where: {
                            proposalNamesLocal.contains($0.toolName) &&
                            ($0.output?["proposalId"] == proposalId || $0.input?["proposalId"] == proposalId)
                        }) == true
                    }) {
                        let msg = self._canvasChatHistory[idx]
                        self._canvasChatHistory[idx] = CanvasChatMessage(
                            role: msg.role,
                            content: msg.content,
                            toolCalls: msg.toolCalls,
                            approvalResult: result
                        )
                        self.persistCanvasHistory(orgId: orgId)
                    }
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .aiAgentProposalActioned, object: result)
                    }
                    cont.resume(returning: .value(.string("Proposal approved successfully.")))
                } else {
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .aiAgentProposalActioned, object: nil)
                    }
                    cont.resume(returning: .value(.string("Approval failed. Please try again — the card is still actionable.")))
                }
            }
        }
    }

    func executeRejectProposal(proposalId: String) async -> ToolExecutionResult<JSONValue> {
        let proposalNames: Set<String> = ["propose_feature", "propose_initiative", "propose_milestone"]

        // IDOR guard
        guard _canvasChatHistory.contains(where: {
            $0.toolCalls?.contains(where: {
                proposalNames.contains($0.toolName) &&
                ($0.output?["proposalId"] == proposalId || $0.input?["proposalId"] == proposalId)
            }) == true
        }) else {
            return .value(.string("Proposal not found. Cannot reject."))
        }

        // Idempotency
        if let idx = _canvasChatHistory.indices.last(where: {
            _canvasChatHistory[$0].toolCalls?.contains(where: {
                proposalNames.contains($0.toolName) &&
                ($0.output?["proposalId"] == proposalId || $0.input?["proposalId"] == proposalId)
            }) == true
        }), _canvasChatHistory[idx].approvalResult != nil {
            return .value(.string("This proposal has already been actioned."))
        }

        guard let orgId: String = UserDefaults.Keys.hiveOrgId.get(), !orgId.isEmpty,
              let data: Data = UserDefaults.Keys.hiveConversationIdByOrg.get(),
              let dict = try? JSONDecoder().decode([String: String].self, from: data),
              let conversationId = dict[orgId]
        else {
            return .value(.string("Missing org context. Cannot reject."))
        }

        let turnId = UUID().uuidString
        let token: String? = await withCheckedContinuation { cont in
            API.sharedInstance.resolveHiveToken(callback: { cont.resume(returning: $0) }, errorCallback: { cont.resume(returning: nil) })
        }
        guard let token = token else {
            return .value(.string("Authentication failed. Cannot reject."))
        }

        print("AIAgent [HiveGraph] reject_proposal firing — proposalId: \(proposalId), turnId: \(turnId)")

        let messages = (try? JSONEncoder().encode(_canvasChatHistory)).flatMap {
            try? JSONSerialization.jsonObject(with: $0) as? [[String: Any]]
        } ?? []

        return await withCheckedContinuation { cont in
            API.sharedInstance.sendRejectionIntent(
                orgId: orgId,
                conversationId: conversationId,
                turnId: turnId,
                proposalId: proposalId,
                canvasChatMessages: messages,
                token: token
            ) { success in
                if success {
                    let rejectionResult = ApprovalResult(approved: false, proposalId: proposalId, message: nil)
                    let proposalNamesLocal: Set<String> = ["propose_feature", "propose_initiative", "propose_milestone"]
                    if let idx = self._canvasChatHistory.indices.last(where: {
                        self._canvasChatHistory[$0].toolCalls?.contains(where: {
                            proposalNamesLocal.contains($0.toolName) &&
                            ($0.output?["proposalId"] == proposalId || $0.input?["proposalId"] == proposalId)
                        }) == true
                    }) {
                        let msg = self._canvasChatHistory[idx]
                        self._canvasChatHistory[idx] = CanvasChatMessage(
                            role: msg.role,
                            content: msg.content,
                            toolCalls: msg.toolCalls,
                            approvalResult: rejectionResult
                        )
                        self.persistCanvasHistory(orgId: orgId)
                    }
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .aiAgentProposalActioned, object: rejectionResult)
                    }
                    cont.resume(returning: .value(.string("Proposal rejected.")))
                } else {
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .aiAgentProposalActioned, object: nil)
                    }
                    cont.resume(returning: .value(.string("Rejection failed. Please try again — the card is still actionable.")))
                }
            }
        }
    }

    // MARK: - Debug Mock Injector

    #if DEBUG
    func injectMockProposal(kind: String = "feature") {
        let mock = PendingProposal(
            proposalId: "mock-\(UUID().uuidString)",
            kind: kind,
            title: "[MOCK] Build \(kind) dashboard",
            description: "A mock proposal for UI development."
        )
        _pendingProposal = mock
        NotificationCenter.default.post(name: .aiAgentProposalDetected, object: mock)
    }
    #endif
}
