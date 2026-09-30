//
//  AIAgentManager+HivePlanTools.swift
//  sphinx
//
//  Plan read / plan chat / send-to-planner tools for the Sphinx Agent.
//  NOTE: answer_planner_form is intentionally NOT implemented: the FORM-answer
//  route could not be confirmed from captured fixtures.
//

import Foundation
import SwiftAISDK

// MARK: - Pure helpers

enum HivePlanFormatter {
    static let notWritten = "(not yet written)"

    static func section(_ text: String?) -> String {
        guard let t = text?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else {
            return notWritten
        }
        return t
    }

    static func formatPlan(_ f: HiveFeature) -> String {
        let stories: String
        if let s = f.userStories, !s.isEmpty {
            stories = s.map { "- \($0)" }.joined(separator: "\n")
        } else {
            stories = notWritten
        }
        let planner = f.workflowStatus == "IN_PROGRESS"
            ? "Planner is currently working (workflowStatus: IN_PROGRESS)."
            : "Planner is idle (workflowStatus: \(f.workflowStatus ?? "none"))."
        return [
            "Feature: \(f.title) (id: \(f.id))",
            "Status: \(f.status ?? "unknown")",
            planner,
            "\nBrief:\n\(section(f.brief))",
            "\nUser stories:\n\(stories)",
            "\nRequirements:\n\(section(f.requirements))",
            "\nArchitecture:\n\(section(f.architecture))"
        ].joined(separator: "\n")
    }

    static func formatChat(_ messages: [HiveChatMessage], limit: Int = 20) -> String {
        if messages.isEmpty { return "No plan chat messages yet." }
        let recent = messages.suffix(limit)
        var lines = ["Plan chat (last \(recent.count) of \(messages.count) messages):"]
        for m in recent {
            let who = m.createdBy?.name ?? (m.isUserMessage ? "User" : "Planner")
            lines.append("\n[\(m.role)] \(who) @ \(m.createdAt ?? "unknown time"):")
            let text = m.resolvedDisplayText
            if !text.isEmpty { lines.append(text) }
            for a in m.artifacts where a.type == "PLAN" || a.type == "FORM" {
                lines.append(contentsOf: formatArtifact(a))
            }
        }
        return lines.joined(separator: "\n")
    }

    static func formatArtifact(_ a: HiveChatMessageArtifact) -> [String] {
        var out: [String] = []
        if let qs = a.clarifyingQuestions, !qs.isEmpty {
            out.append("  Clarifying questions (answered status unknown):")
            for (i, q) in qs.enumerated() {
                out.append("  \(i + 1). \(q.question) [\(q.type)]")
                for o in q.options { out.append("     - \(o)") }
            }
        } else if a.type == "FORM" {
            // FORM structure is unverified (no fixture) - report only what is certain.
            out.append("  FORM artifact (id: \(a.id ?? "unknown"); answered status unknown; "
                       + "answering forms is not supported yet)")
        }
        return out
    }

    static func sendFailureMessage(_ r: FeatureChatSendResult) -> String {
        switch r {
        case .sent: return "Message sent to the planner."
        case .plannerBusy: return "Planner is still running - try again shortly."
        case .notFound: return "Feature not found (404). Nothing was sent."
        case .forbidden: return "You don't have access to this feature (403). Nothing was sent."
        case .failed: return "Failed to send the message. It may not have been delivered; "
            + "check the plan chat before retrying so nothing is sent twice."
        }
    }

    static func createReply(
        title: String, workspace: String, result: HiveCreateFeatureResult,
        seed: FeatureChatSendResult?
    ) -> String {
        switch result {
        case .created(let f):
            guard let seed = seed else { return "Feature created (id: \(f.id)) in '\(workspace)'." }
            if case .sent = seed {
                return "Feature created (id: \(f.id)) in '\(workspace)' and the planner was started with the opening message."
            }
            return "Feature WAS created (id: \(f.id)) in '\(workspace)', but the opening plan-chat message "
                + "was not delivered. Do not recreate it; use send_to_planner to start planning."
        case .createdUnparseable:
            return "Hive accepted the feature but didn't return its ID - check the workspace before retrying, "
                + "so you don't create a duplicate."
        case .failed(let status):
            return "Failed to create feature in workspace '\(workspace)'\(status.map { " (HTTP \($0))" } ?? "")."
        }
    }
}

enum HivePlanResolver {
    enum OrgResolution: Equatable {
        case login(String)
        case error(String)
    }

    /// Pure org resolution. `slugsByLogin` is only consulted when there are several orgs.
    static func resolveOrgLogin(
        workspaceSlug: String, logins: [String], slugsByLogin: [String: [String]]
    ) -> OrgResolution {
        if logins.count == 1 { return .login(logins[0]) }
        if logins.isEmpty { return .error("No Hive orgs found for this account.") }
        let matches = logins.filter { slugsByLogin[$0]?.contains(workspaceSlug) == true }
        if matches.count == 1 { return .login(matches[0]) }
        return .error("Could not determine which Hive org owns workspace '\(workspaceSlug)'.")
    }

    static let maxFeaturePages = 10

    /// Pages through features until `matcher` finds a match, pages run out, or the cap is hit.
    static func findFeature(
        fetchPage: (Int) async -> ([HiveFeature], PaginationInfo)?,
        matcher: ([HiveFeature]) -> HiveFeature?
    ) async -> HiveFeature? {
        var all: [HiveFeature] = []
        for page in 1...maxFeaturePages {
            guard let (features, pagination) = await fetchPage(page) else { return nil }
            all.append(contentsOf: features)
            if let m = matcher(all) { return m }
            if !pagination.hasMore { return nil }
        }
        return nil
    }
}

// MARK: - Feature resolution + tools

extension AIAgentManager {

    struct SendToPlannerInput: Codable, Sendable {
        let workspace_name: String
        let feature_name: String
        let message: String
    }

    enum FeatureResolution {
        case found(workspace: Workspace, feature: HiveFeature)
        case error(String)
    }

    /// Resolves the workspace from the user's own workspace list, then pages
    /// through that workspace's features (cap 10 pages) for a match.
    func resolveFeature(workspaceName: String, featureName: String) async -> FeatureResolution {
        guard let workspaces = await fetchWorkspacesAsync() else {
            return .error("Failed to fetch Hive workspaces. Make sure your Hive token is configured.")
        }
        let (ws, candidates) = AIAgentManager.resolveWorkspace(query: workspaceName, from: workspaces)
        guard let workspace = ws else {
            if candidates.isEmpty {
                return .error("No workspace found matching '\(workspaceName)'. Available: "
                              + workspaces.map { $0.name }.joined(separator: ", ") + ".")
            }
            return .error("Multiple workspaces match '\(workspaceName)': \(candidates.joined(separator: ", ")). Please be more specific.")
        }
        var ambiguous: [String] = []
        let match = await HivePlanResolver.findFeature(
            fetchPage: { page in
                await withCheckedContinuation { continuation in
                    API.sharedInstance.fetchFeaturesWithAuth(
                        workspaceId: workspace.id,
                        page: page,
                        callback: { f, p in continuation.resume(returning: (f, p)) },
                        errorCallback: { continuation.resume(returning: nil) }
                    )
                }
            },
            matcher: { features in
                let (m, c) = AIAgentManager.resolveHiveItem(query: featureName, items: features, name: { $0.title })
                ambiguous = c
                return m
            }
        )
        if let feature = match { return .found(workspace: workspace, feature: feature) }
        if !ambiguous.isEmpty {
            return .error("Multiple features match '\(featureName)': \(ambiguous.joined(separator: ", ")). Please be more specific.")
        }
        return .error("No feature named '\(featureName)' found in workspace '\(workspace.name)'.")
    }

    // MARK: get_feature_plan

    func buildGetFeaturePlanTool() -> TypedTool<FeatureNameInput, JSONValue> {
        tool(
            description: "Read a feature's plan: brief, user stories, requirements, architecture, status, and whether the planner is working. Use this (not query_hive_graph) for questions about a feature's plan.",
            execute: { (input: FeatureNameInput, _: ToolCallOptions) async throws -> ToolExecutionResult<JSONValue> in
                print("[AIAgent] get_feature_plan: workspace=\(input.workspace_name)")
                switch await self.resolveFeature(workspaceName: input.workspace_name, featureName: input.feature_name) {
                case .error(let msg):
                    print("[AIAgent] get_feature_plan: resolve failed")
                    return .value(.string(msg))
                case .found(_, let stub):
                    let (detail, status) = await API.sharedInstance.fetchFeatureDetailResult(featureId: stub.id)
                    guard let feature = detail else {
                        print("[HiveAPI] get_feature_plan detail failed status=\(status ?? -1) feature=\(stub.id)")
                        if status == 404 { return .value(.string("Feature not found (404).")) }
                        if status == 403 { return .value(.string("You don't have access to this feature (403).")) }
                        return .value(.string("Failed to fetch the plan for this feature."))
                    }
                    guard feature.id == stub.id else {
                        print("[AIAgent] get_feature_plan: id mismatch feature=\(stub.id)")
                        return .value(.string("Failed to fetch the plan for this feature."))
                    }
                    print("[AIAgent] get_feature_plan: ok feature=\(feature.id)")
                    return .value(.string(HivePlanFormatter.formatPlan(feature)))
                }
            }
        )
    }

    // MARK: get_plan_chat_history

    func buildGetPlanChatHistoryTool() -> TypedTool<FeatureNameInput, JSONValue> {
        tool(
            description: "Read the most recent messages (last 20) of a feature's plan chat with the planner, including clarifying questions and options. Use this for questions about what the planner asked or said.",
            execute: { (input: FeatureNameInput, _: ToolCallOptions) async throws -> ToolExecutionResult<JSONValue> in
                print("[AIAgent] get_plan_chat_history: workspace=\(input.workspace_name)")
                switch await self.resolveFeature(workspaceName: input.workspace_name, featureName: input.feature_name) {
                case .error(let msg):
                    return .value(.string(msg))
                case .found(_, let stub):
                    let (msgs, status) = await API.sharedInstance.fetchFeatureChatResult(featureId: stub.id)
                    guard let messages = msgs else {
                        print("[HiveAPI] get_plan_chat_history failed status=\(status ?? -1) feature=\(stub.id)")
                        if status == 404 { return .value(.string("Feature not found (404).")) }
                        if status == 403 { return .value(.string("You don't have access to this feature (403).")) }
                        return .value(.string("Failed to fetch the plan chat."))
                    }
                    print("[AIAgent] get_plan_chat_history: ok feature=\(stub.id) count=\(messages.count)")
                    return .value(.string(HivePlanFormatter.formatChat(messages)))
                }
            }
        )
    }

    // MARK: send_to_planner

    func buildSendToPlannerTool() -> TypedTool<SendToPlannerInput, JSONValue> {
        tool(
            description: "Send a message to a feature's planner in its plan chat. IMPORTANT: Before invoking this tool, ask the user for explicit confirmation, repeating the exact message text that will be sent. Only invoke after the user confirms.",
            execute: { (input: SendToPlannerInput, _: ToolCallOptions) async throws -> ToolExecutionResult<JSONValue> in
                print("[AIAgent] send_to_planner: workspace=\(input.workspace_name)")
                switch await self.resolveFeature(workspaceName: input.workspace_name, featureName: input.feature_name) {
                case .error(let msg):
                    return .value(.string(msg))
                case .found(let workspace, let stub):
                    let repoIds = AIAgentManager.savedRepositoryIds(workspaceId: workspace.id, featureId: stub.id)
                    let result = await API.sharedInstance.sendFeatureChatMessageResult(
                        featureId: stub.id, message: input.message, selectedRepositoryIds: repoIds
                    )
                    var outcome = "failed"
                    switch result {
                    case .sent: outcome = "sent"
                    case .plannerBusy: outcome = "plannerBusy"
                    case .notFound: outcome = "notFound"
                    case .forbidden: outcome = "forbidden"
                    case .failed: outcome = "failed"
                    }
                    print("[AIAgent] send_to_planner: outcome=\(outcome) feature=\(stub.id)")
                    return .value(.string(HivePlanFormatter.sendFailureMessage(result)))
                }
            }
        )
    }

    /// Repository selection saved by the Create Feature / Feature Plan screens.
    static func savedRepositoryIds(workspaceId: String, featureId: String?) -> [String]? {
        if let fid = featureId,
           let ids = UserDefaults.standard.object([String].self, with: "hiveFeatureRepos_\(fid)"), !ids.isEmpty {
            return ids
        }
        if let ids = UserDefaults.standard.object([String].self, with: "hiveWorkspaceRepos_\(workspaceId)"), !ids.isEmpty {
            return ids
        }
        return nil
    }
}
