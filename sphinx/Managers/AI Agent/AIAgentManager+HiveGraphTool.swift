//
//  AIAgentManager+HiveGraphTool.swift
//  sphinx
//
//  Created for Sphinx Agent Graph Chat integration.
//  Copyright © 2026 sphinx. All rights reserved.
//

import Foundation
import SwiftAISDK

// MARK: - HiveGraphBridge

/// Bridges GraphChatSSEDelegate callbacks to a CheckedContinuation<String, Never>.
private class HiveGraphBridge: GraphChatSSEDelegate {

    var continuation: CheckedContinuation<String, Never>?
    var sseManager: GraphChatSSEManager?
    var buffer: String = ""
    var resumed: Bool = false

    /// Captured propose_* tool calls from the SSE stream.
    var capturedToolCalls: [(name: String, toolCallId: String, inputStr: String)] = []

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

    func onToolInputAvailable(toolName: String) {
        // Capture propose_* tool inputs as they arrive
        let proposalPrefixes = ["propose_feature", "propose_initiative", "propose_milestone"]
        guard proposalPrefixes.contains(where: { toolName.hasPrefix($0) }) else { return }
        if !capturedToolCalls.contains(where: { $0.name == toolName }) {
            capturedToolCalls.append((name: toolName, toolCallId: "", inputStr: ""))
        }
    }

    func onToolCall(toolName: String, input: [String: Any]?) {
        let proposalPrefixes = ["propose_feature", "propose_initiative", "propose_milestone"]
        guard proposalPrefixes.contains(where: { toolName.hasPrefix($0) }) else { return }
        let inputStr: String
        if let input = input,
           let data = try? JSONSerialization.data(withJSONObject: input),
           let str = String(data: data, encoding: .utf8) {
            inputStr = str
        } else {
            inputStr = ""
        }
        if let idx = capturedToolCalls.indices.last(where: { capturedToolCalls[$0].name == toolName && capturedToolCalls[$0].inputStr.isEmpty }) {
            capturedToolCalls[idx] = (name: toolName, toolCallId: capturedToolCalls[idx].toolCallId, inputStr: inputStr)
        } else {
            capturedToolCalls.append((name: toolName, toolCallId: "", inputStr: inputStr))
        }
    }

    func onToolOutputAvailable() {}
}

// MARK: - AIAgentManager + Proposal Models

extension AIAgentManager {

    // MARK: - PendingProposal

    struct PendingProposal: Codable, Sendable {
        let proposalId: String
        let kind: String       // "feature" | "initiative" | "milestone"
        let title: String
        let description: String?
        /// Tool call context – optional fields carried through for approve/reject
        let turnId: String?
        let conversationId: String?
        let orgId: String?
        let workspaceSlugs: [String]?
        let workspaceSlug: String?
        let orgGithubLogin: String?
    }

    // MARK: - ApprovalResult

    struct ApprovalResult: Codable, Sendable {
        let proposalId: String
        let approved: Bool
        let featureUrl: String?
        let summaryText: String?

        // Allow flexible server response decoding
        enum CodingKeys: String, CodingKey {
            case proposalId
            case approved
            case status
            case featureUrl
            case summaryText
            case message
        }

        init(proposalId: String, approved: Bool, featureUrl: String? = nil, summaryText: String? = nil) {
            self.proposalId = proposalId
            self.approved = approved
            self.featureUrl = featureUrl
            self.summaryText = summaryText
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            proposalId = (try? c.decode(String.self, forKey: .proposalId)) ?? ""
            // Server may return "approved" bool or "status" string
            if let bool = try? c.decode(Bool.self, forKey: .approved) {
                approved = bool
            } else if let status = try? c.decode(String.self, forKey: .status) {
                approved = (status == "approved")
            } else {
                approved = false
            }
            featureUrl = try? c.decode(String.self, forKey: .featureUrl)
            summaryText = (try? c.decode(String.self, forKey: .summaryText))
                ?? (try? c.decode(String.self, forKey: .message))
        }

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(proposalId, forKey: .proposalId)
            try c.encode(approved, forKey: .approved)
            try? c.encode(featureUrl, forKey: .featureUrl)
            try? c.encode(summaryText, forKey: .summaryText)
        }
    }

    // MARK: - RejectionIntent / RejectProposalInput

    struct RejectionIntent: Codable, Sendable {
        let proposalId: String
    }

    struct RejectProposalInput: Codable, Sendable {
        let proposal_id: String
    }

    struct ApproveProposalInput: Codable, Sendable {
        let proposal_id: String
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
            execute: { [weak self] (input: QueryHiveGraphInput, _: ToolCallOptions) async throws -> ToolExecutionResult<JSONValue> in
                guard let self = self else { return .value(.string("Agent unavailable.")) }
                let result = await self.executeQueryHiveGraph(question: input.question)
                return .value(.string(result))
            }
        )
    }

    func executeQueryHiveGraph(question: String) async -> String {

        // 1. Ensure org slugs are cached (refresh if stale)
        var slugs = AIAgentManager.cachedOrgSlugs()
        if slugs == nil {
            await AIAgentManager.fetchAndCacheOrgSlugs()
            slugs = AIAgentManager.cachedOrgSlugs()
        }
        guard let orgSlugs = slugs, !orgSlugs.isEmpty else {
            return "Hive org not configured. Please check your Hive connection in settings."
        }
        guard let orgId: String = UserDefaults.Keys.hiveOrgId.get(), !orgId.isEmpty else {
            return "Hive org ID not found. Please reconfigure your Hive connection."
        }

        // 2. Read persisted conversationId for this org (nil on first call).
        let conversationId: String? = {
            guard let data: Data = UserDefaults.Keys.hiveConversationIdByOrg.get(),
                  let dict = try? JSONDecoder().decode([String: String].self, from: data) else { return nil }
            return dict[orgId]
        }()

        // 3. Resolve auth token
        let token: String? = await withCheckedContinuation { cont in
            API.sharedInstance.resolveHiveToken(
                callback: { cont.resume(returning: $0) },
                errorCallback: { cont.resume(returning: nil) }
            )
        }
        guard let token = token else {
            return "Hive authentication failed. Please check your Hive configuration."
        }

        // 4. Stream via org SSE
        let bridge = HiveGraphBridge()
        let sseManager = GraphChatSSEManager()
        bridge.sseManager = sseManager
        sseManager.delegate = bridge

        print("AIAgent [HiveGraph] querying org '\(orgId)' with \(orgSlugs.count) slug(s): \(question)")

        let newTurnId = UUID().uuidString

        let result: String = await withCheckedContinuation { cont in
            bridge.continuation = cont
            sseManager.startOrgStream(
                question: question,
                orgSlugs: orgSlugs,
                orgId: orgId,
                conversationId: conversationId,
                token: token,
                onConversationId: { newCid in
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

        // 5. Proposal detection — surface card in chat
        let proposalPrefixSet = ["propose_feature", "propose_initiative", "propose_milestone"]
        if let tc = bridge.capturedToolCalls.first(where: { captured in
            proposalPrefixSet.contains(where: { captured.name.hasPrefix($0) })
        }) {
            // Parse proposal fields from tool input
            let inputDict = parseJsonStringToDict(tc.inputStr)
            let proposalId = inputDict?["proposalId"] ?? inputDict?["proposal_id"] ?? UUID().uuidString
            let title       = inputDict?["title"] ?? "Proposal"
            let description = inputDict?["description"]
            let kind: String = {
                if tc.name.contains("initiative") { return "initiative" }
                if tc.name.contains("milestone")  { return "milestone" }
                return "feature"
            }()

            // Build context for approve/reject calls
            let resolvedConvId: String? = {
                guard let data: Data = UserDefaults.Keys.hiveConversationIdByOrg.get(),
                      let dict = try? JSONDecoder().decode([String: String].self, from: data) else { return nil }
                return dict[orgId]
            }()
            let githubLogin: String? = UserDefaults.Keys.hiveGithubLogin.get()

            let proposal = PendingProposal(
                proposalId: proposalId,
                kind: kind,
                title: title,
                description: description,
                turnId: newTurnId,
                conversationId: resolvedConvId,
                orgId: orgId,
                workspaceSlugs: orgSlugs,
                workspaceSlug: orgSlugs.first,
                orgGithubLogin: githubLogin
            )

            print("AIAgent [HiveGraph] proposal detected — kind: \(kind), title: \(title), id: \(proposalId)")

            // Persist + broadcast on main actor
            await MainActor.run {
                self.pendingProposal = proposal
                self.persistPendingProposal(proposal)
                NotificationCenter.default.post(
                    name: .aiAgentProposalDetected,
                    object: nil,
                    userInfo: ["proposal": proposal]
                )
            }
        }

        return result
    }

    // MARK: - Approve Proposal Tool

    func buildApproveProposalTool() -> TypedTool<ApproveProposalInput, JSONValue> {
        tool(
            description: "Approve a Jamie proposal (feature, initiative, or milestone) that was previously surfaced in the chat. Provide the proposal_id from the pending proposal. Only use this when the user explicitly approves a proposal.",
            execute: { [weak self] (input: ApproveProposalInput, _: ToolCallOptions) async throws -> ToolExecutionResult<JSONValue> in
                guard let self = self else { return .value(.string("Agent unavailable.")) }
                let resultText = await self.executeApproveProposal(proposalId: input.proposal_id)
                return .value(.string(resultText))
            }
        )
    }

    func executeApproveProposal(proposalId: String) async -> String {
        // IDOR Guard: atomically verify proposalId matches pendingProposal AND retrieve it.
        // A single MainActor.run prevents a TOCTOU race where pendingProposal is swapped
        // between a separate check and fetch, which would let a caller-supplied ID act on
        // a different proposal's org/conversation context.
        guard let proposal = await MainActor.run(body: {
            guard pendingProposal?.proposalId == proposalId else { return nil as PendingProposal? }
            return pendingProposal
        }) else {
            print("AIAgent [HiveGraph] proposal-not-found: unknown proposalId '\(proposalId)' — rejecting approve")
            await MainActor.run {
                NotificationCenter.default.post(
                    name: .aiAgentProposalActioned,
                    object: nil,
                    userInfo: ["error": "Proposal not found or already actioned."]
                )
            }
            return "Error: proposal not found or already actioned."
        }

        // Org context validation
        guard let orgId = proposal.orgId ?? UserDefaults.Keys.hiveOrgId.get(), !orgId.isEmpty else {
            print("AIAgent [HiveGraph] missing-org: no orgId available for proposal '\(proposalId)'")
            await MainActor.run {
                NotificationCenter.default.post(
                    name: .aiAgentProposalActioned,
                    object: nil,
                    userInfo: ["error": "Hive org not configured."]
                )
            }
            return "Error: Hive org not configured."
        }

        let convId = proposal.conversationId ?? {
            guard let data: Data = UserDefaults.Keys.hiveConversationIdByOrg.get(),
                  let dict = try? JSONDecoder().decode([String: String].self, from: data) else { return nil }
            return dict[orgId]
        }()

        // Resolve auth token
        let token: String? = await withCheckedContinuation { cont in
            API.sharedInstance.resolveHiveToken(
                callback: { cont.resume(returning: $0) },
                errorCallback: { cont.resume(returning: nil) }
            )
        }
        guard let token = token else {
            print("AIAgent [HiveGraph] auth-failed: could not resolve Hive token for proposal approve '\(proposalId)'")
            await MainActor.run {
                NotificationCenter.default.post(
                    name: .aiAgentProposalActioned,
                    object: nil,
                    userInfo: ["error": "Hive authentication failed."]
                )
            }
            return "Error: Hive authentication failed."
        }

        // POST approval
        let turnId = proposal.turnId ?? UUID().uuidString
        let workspaceSlugs = proposal.workspaceSlugs ?? AIAgentManager.cachedOrgSlugs() ?? []
        let workspaceSlug = proposal.workspaceSlug ?? workspaceSlugs.first ?? ""
        let orgGithubLogin = proposal.orgGithubLogin ?? UserDefaults.Keys.hiveGithubLogin.get() ?? ""

        let apiResult: Result<ApprovalResult, String> = await withCheckedContinuation { cont in
            API.sharedInstance.sendApprovalIntent(
                orgId: orgId,
                conversationId: convId ?? "",
                turnId: turnId,
                proposalId: proposalId,
                workspaceSlugs: workspaceSlugs,
                workspaceSlug: workspaceSlug,
                orgGithubLogin: orgGithubLogin,
                token: token,
                callback: { result in cont.resume(returning: .success(result)) },
                errorCallback: { err in cont.resume(returning: .failure(err)) }
            )
        }

        switch apiResult {
        case .success(let approvalResult):
            print("AIAgent [HiveGraph] approve POST success — proposalId: \(proposalId), featureUrl: \(approvalResult.featureUrl ?? "nil")")
            await MainActor.run {
                self.pendingProposal = nil
                self.clearPersistedPendingProposal()
                NotificationCenter.default.post(
                    name: .aiAgentProposalActioned,
                    object: nil,
                    userInfo: ["result": approvalResult]
                )
            }
            let summary = approvalResult.summaryText ?? "Proposal approved successfully."
            return summary

        case .failure(let errMsg):
            print("AIAgent [HiveGraph] approve POST failure — proposalId: \(proposalId), error: \(errMsg)")
            await MainActor.run {
                NotificationCenter.default.post(
                    name: .aiAgentProposalActioned,
                    object: nil,
                    userInfo: ["error": errMsg]
                )
            }
            return "Error approving proposal: \(errMsg)"
        }
    }

    // MARK: - Reject Proposal Tool

    func buildRejectProposalTool() -> TypedTool<RejectProposalInput, JSONValue> {
        tool(
            description: "Reject a Jamie proposal (feature, initiative, or milestone) that was previously surfaced in the chat. Provide the proposal_id from the pending proposal. Only use this when the user explicitly rejects a proposal.",
            execute: { [weak self] (input: RejectProposalInput, _: ToolCallOptions) async throws -> ToolExecutionResult<JSONValue> in
                guard let self = self else { return .value(.string("Agent unavailable.")) }
                let resultText = await self.executeRejectProposal(proposalId: input.proposal_id)
                return .value(.string(resultText))
            }
        )
    }

    func executeRejectProposal(proposalId: String) async -> String {
        // IDOR Guard: atomically verify proposalId matches pendingProposal AND retrieve it.
        guard let proposal = await MainActor.run(body: {
            guard pendingProposal?.proposalId == proposalId else { return nil as PendingProposal? }
            return pendingProposal
        }) else {
            print("AIAgent [HiveGraph] proposal-not-found: unknown proposalId '\(proposalId)' — rejecting reject")
            await MainActor.run {
                NotificationCenter.default.post(
                    name: .aiAgentProposalActioned,
                    object: nil,
                    userInfo: ["error": "Proposal not found or already actioned."]
                )
            }
            return "Error: proposal not found or already actioned."
        }

        guard let orgId = proposal.orgId ?? UserDefaults.Keys.hiveOrgId.get(), !orgId.isEmpty else {
            print("AIAgent [HiveGraph] missing-org: no orgId available for proposal rejection '\(proposalId)'")
            await MainActor.run {
                NotificationCenter.default.post(
                    name: .aiAgentProposalActioned,
                    object: nil,
                    userInfo: ["error": "Hive org not configured."]
                )
            }
            return "Error: Hive org not configured."
        }

        let convId = proposal.conversationId ?? {
            guard let data: Data = UserDefaults.Keys.hiveConversationIdByOrg.get(),
                  let dict = try? JSONDecoder().decode([String: String].self, from: data) else { return nil }
            return dict[orgId]
        }()

        let token: String? = await withCheckedContinuation { cont in
            API.sharedInstance.resolveHiveToken(
                callback: { cont.resume(returning: $0) },
                errorCallback: { cont.resume(returning: nil) }
            )
        }
        guard let token = token else {
            print("AIAgent [HiveGraph] auth-failed: could not resolve Hive token for proposal reject '\(proposalId)'")
            await MainActor.run {
                NotificationCenter.default.post(
                    name: .aiAgentProposalActioned,
                    object: nil,
                    userInfo: ["error": "Hive authentication failed."]
                )
            }
            return "Error: Hive authentication failed."
        }

        let turnId = proposal.turnId ?? UUID().uuidString
        let workspaceSlugs = proposal.workspaceSlugs ?? AIAgentManager.cachedOrgSlugs() ?? []

        let apiResult: Result<ApprovalResult, String> = await withCheckedContinuation { cont in
            API.sharedInstance.sendRejectionIntent(
                orgId: orgId,
                conversationId: convId ?? "",
                turnId: turnId,
                proposalId: proposalId,
                workspaceSlugs: workspaceSlugs,
                token: token,
                callback: { result in cont.resume(returning: .success(result)) },
                errorCallback: { err in cont.resume(returning: .failure(err)) }
            )
        }

        switch apiResult {
        case .success(let rejectionResult):
            print("AIAgent [HiveGraph] reject POST success — proposalId: \(proposalId)")
            await MainActor.run {
                self.pendingProposal = nil
                self.clearPersistedPendingProposal()
                NotificationCenter.default.post(
                    name: .aiAgentProposalActioned,
                    object: nil,
                    userInfo: ["result": rejectionResult]
                )
            }
            let summary = rejectionResult.summaryText ?? "Proposal rejected."
            return summary

        case .failure(let errMsg):
            print("AIAgent [HiveGraph] reject POST failure — proposalId: \(proposalId), error: \(errMsg)")
            await MainActor.run {
                NotificationCenter.default.post(
                    name: .aiAgentProposalActioned,
                    object: nil,
                    userInfo: ["error": errMsg]
                )
            }
            return "Error rejecting proposal: \(errMsg)"
        }
    }

    // MARK: - PendingProposal Persistence

    func persistPendingProposal(_ proposal: PendingProposal) {
        if let data = try? JSONEncoder().encode(proposal) {
            UserDefaults.Keys.pendingProposal.set(data)
        }
    }

    func loadPersistedPendingProposal() -> PendingProposal? {
        guard let data: Data = UserDefaults.Keys.pendingProposal.get() else { return nil }
        return try? JSONDecoder().decode(PendingProposal.self, from: data)
    }

    func clearPersistedPendingProposal() {
        UserDefaults.Keys.pendingProposal.removeValue()
    }

    // MARK: - Private JSON Helper

    private func parseJsonStringToDict(_ jsonStr: String) -> [String: String]? {
        guard !jsonStr.isEmpty,
              let data = jsonStr.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        var result: [String: String] = [:]
        for (key, value) in obj {
            if let str = value as? String {
                result[key] = str
            } else if let num = value as? NSNumber {
                result[key] = num.stringValue
            } else if let nested = try? JSONSerialization.data(withJSONObject: value),
                      let nestedStr = String(data: nested, encoding: .utf8) {
                result[key] = nestedStr
            }
        }
        return result.isEmpty ? nil : result
    }
}
