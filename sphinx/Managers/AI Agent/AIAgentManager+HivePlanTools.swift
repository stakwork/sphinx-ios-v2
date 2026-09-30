//
//  AIAgentManager+HivePlanTools.swift
//  sphinx
//
//  get_feature_plan, get_plan_chat_history, send_to_planner, answer_planner_form.
//

import Foundation
import SwiftAISDK

extension AIAgentManager {

    struct SendToPlannerInput: Codable, Sendable {
        let workspace_name: String
        let feature_name: String
        let message: String
    }

    struct AnswerPlannerFormInput: Codable, Sendable {
        let workspace_name: String
        let feature_name: String
        let planner_message_id: String
        let answers: [String]?
        let answer: String?
    }

    enum FeatureResolution {
        case found(Workspace, HiveFeature)
        case failure(String)
    }

    static let maxFeaturePages = 10

    /// Resolves the workspace from the user's own list, then pages that workspace's
    /// features (exact title match preferred) before any write is attempted.
    func resolveFeature(workspaceName: String, featureName: String) async -> FeatureResolution {
        guard let workspaces = await fetchWorkspacesAsync() else {
            return .failure("Failed to fetch Hive workspaces. Make sure your Hive token is configured.")
        }
        let (ws, candidates) = AIAgentManager.resolveWorkspace(query: workspaceName, from: workspaces)
        guard let workspace = ws else {
            if candidates.isEmpty { return .failure("No workspace found matching '\(workspaceName)'.") }
            return .failure("Multiple workspaces match '\(workspaceName)': \(candidates.joined(separator: ", ")). Please be more specific.")
        }
        let query = AIAgentManager.normalizeName(featureName)
        var all: [HiveFeature] = []
        var page = 1
        while page <= AIAgentManager.maxFeaturePages {
            let current = page
            let res: ([HiveFeature], PaginationInfo)? = await withCheckedContinuation { c in
                API.sharedInstance.fetchFeaturesWithAuth(
                    workspaceId: workspace.id, page: current,
                    callback: { f, p in c.resume(returning: (f, p)) },
                    errorCallback: { c.resume(returning: nil) }
                )
            }
            guard let (features, info) = res else {
                return .failure("Failed to fetch features for workspace '\(workspace.name)' (no access or network error).")
            }
            all += features
            if let exact = all.first(where: { AIAgentManager.normalizeName($0.title) == query }) {
                return .found(workspace, exact)
            }
            if !info.hasMore { break }
            page += 1
        }
        let (match, cands) = AIAgentManager.resolveHiveItem(query: featureName, items: all, name: { $0.title })
        if let m = match { return .found(workspace, m) }
        if !cands.isEmpty {
            return .failure("Multiple features match '\(featureName)': \(cands.joined(separator: ", ")). Please be more specific.")
        }
        return .failure("No feature named '\(featureName)' in workspace '\(workspace.name)'.")
    }

    // MARK: - get_feature_plan

    func buildGetFeaturePlanTool() -> TypedTool<FeatureNameInput, JSONValue> {
        tool(
            description: "Read a Hive feature's plan: brief, user stories, requirements, architecture, status, and whether the planner is working or idle.",
            execute: { (input: FeatureNameInput, _: ToolCallOptions) async throws -> ToolExecutionResult<JSONValue> in
                print("[AIAgent] get_feature_plan: ws=\(input.workspace_name)")
                switch await self.resolveFeature(workspaceName: input.workspace_name, featureName: input.feature_name) {
                case .failure(let m): return .value(.string(m))
                case .found(_, let stub):
                    let feature: HiveFeature? = await withCheckedContinuation { c in
                        API.sharedInstance.fetchFeatureDetailWithAuth(
                            featureId: stub.id,
                            callback: { c.resume(returning: $0) },
                            errorCallback: { c.resume(returning: nil) })
                    }
                    guard let f = feature else {
                        print("[AIAgent] get_feature_plan: failed feature=\(stub.id)")
                        return .value(.string("Feature not found or you don't have access to it."))
                    }
                    return .value(.string(HivePlanFormatter.formatPlan(f)))
                }
            }
        )
    }

    // MARK: - get_plan_chat_history

    func buildGetPlanChatHistoryTool() -> TypedTool<FeatureNameInput, JSONValue> {
        tool(
            description: "Read the recent plan-chat history (last 20 messages) of a Hive feature, including PLAN clarifying questions and FORM artifacts with their ids.",
            execute: { (input: FeatureNameInput, _: ToolCallOptions) async throws -> ToolExecutionResult<JSONValue> in
                print("[AIAgent] get_plan_chat_history: ws=\(input.workspace_name)")
                switch await self.resolveFeature(workspaceName: input.workspace_name, featureName: input.feature_name) {
                case .failure(let m): return .value(.string(m))
                case .found(_, let stub):
                    let msgs: [HiveChatMessage]? = await withCheckedContinuation { c in
                        API.sharedInstance.fetchFeatureChatWithAuth(
                            featureId: stub.id,
                            callback: { c.resume(returning: $0) },
                            errorCallback: { c.resume(returning: nil) })
                    }
                    guard let messages = msgs else {
                        return .value(.string("Failed to fetch plan chat (feature missing or no access)."))
                    }
                    return .value(.string(HivePlanFormatter.formatHistory(messages)))
                }
            }
        )
    }

    // MARK: - send_to_planner (confirmation required)

    func buildSendToPlannerTool() -> TypedTool<SendToPlannerInput, JSONValue> {
        tool(
            description: "Send a message to a Hive feature's planner (plan chat). IMPORTANT: Before invoking, show the user the exact message text that will be sent and ask for explicit confirmation. Only invoke after the user confirms. If the planner is already running the tool says so; do not retry immediately.",
            execute: { (input: SendToPlannerInput, _: ToolCallOptions) async throws -> ToolExecutionResult<JSONValue> in
                print("[AIAgent] send_to_planner: ws=\(input.workspace_name)")
                switch await self.resolveFeature(workspaceName: input.workspace_name, featureName: input.feature_name) {
                case .failure(let m): return .value(.string(m))
                case .found(let ws, let feature):
                    let repos = await self.validatedRepositoryIds(featureId: feature.id, workspace: ws)
                    let result: FeatureChatSendResult = await withCheckedContinuation { c in
                        API.sharedInstance.sendFeatureChatMessageResult(
                            featureId: feature.id, message: input.message,
                            selectedRepositoryIds: repos,
                            completion: { c.resume(returning: $0) })
                    }
                    print("[AIAgent] send_to_planner: done feature=\(feature.id)")
                    return .value(.string(HivePlanFormatter.sendResultMessage(result)))
                }
            }
        )
    }

    /// Saved selection filtered to repositories the user's own workspace actually lists; nil if none remain.
    func validatedRepositoryIds(featureId: String?, workspace: Workspace) async -> [String]? {
        guard let saved = AIAgentManager.savedRepositoryIds(featureId: featureId, workspaceId: workspace.id),
              let slug = workspace.slug else { return nil }
        let repos: [WorkspaceRepository]? = await withCheckedContinuation { c in
            API.sharedInstance.fetchWorkspaceDetailWithAuth(
                slug: slug,
                callback: { c.resume(returning: $0) },
                errorCallback: { c.resume(returning: nil) })
        }
        guard let owned = repos else { return nil }
        let ownedIds = Set(owned.map { $0.id })
        let valid = saved.filter { ownedIds.contains($0) }
        return valid.isEmpty ? nil : valid
    }

    /// Saved repo selection (same UserDefaults keys as the Create/FeaturePlan screens).
    static func savedRepositoryIds(featureId: String?, workspaceId: String) -> [String]? {
        if let f = featureId,
           let ids = UserDefaults.standard.object([String].self, with: "hiveFeatureRepos_\(f)"), !ids.isEmpty { return ids }
        if let ids = UserDefaults.standard.object([String].self, with: "hiveWorkspaceRepos_\(workspaceId)"), !ids.isEmpty { return ids }
        return nil
    }

    // MARK: - resolveOrgLogin

    /// Org owning the workspace slug; never guesses and never falls back to a stored login.
    func resolveOrgLogin(workspaceSlug: String) async -> Result<String, Error> {
        struct OrgError: LocalizedError {
            let message: String
            var errorDescription: String? { message }
        }
        let failure = Result<String, Error>.failure(
            OrgError(message: "Couldn't determine which Hive org owns workspace \(workspaceSlug).")
        )
        guard let token: String = UserDefaults.Keys.hiveToken.get() else { return failure }
        if let cached = await HiveOrgLoginCache.shared.login(for: workspaceSlug, token: token) {
            return .success(cached)
        }
        let orgs: [HiveOrg]? = await withCheckedContinuation { c in
            API.sharedInstance.fetchAllOrgs(
                authToken: token,
                callback: { c.resume(returning: $0) },
                errorCallback: { c.resume(returning: nil) })
        }
        guard let all = orgs, !all.isEmpty else {
            print("[AIAgent] resolveOrgLogin: unresolved ws=\(workspaceSlug)")
            return failure
        }
        var slugsByLogin: [String: [String]] = [:]
        if all.count > 1 {
            for org in all {
                let slugs: [String]? = await withCheckedContinuation { c in
                    API.sharedInstance.fetchOrgWorkspaces(
                        githubLogin: org.githubLogin, authToken: token,
                        callback: { c.resume(returning: $0) },
                        errorCallback: { c.resume(returning: nil) })
                }
                slugsByLogin[org.githubLogin] = slugs ?? []
            }
        }
        guard let login = HivePlanFormatter.matchOrg(
            logins: all.map { $0.githubLogin }, slugsByLogin: slugsByLogin, slug: workspaceSlug
        ) else {
            print("[AIAgent] resolveOrgLogin: unresolved ws=\(workspaceSlug)")
            return failure
        }
        await HiveOrgLoginCache.shared.store(login, for: workspaceSlug, token: token)
        print("[AIAgent] resolveOrgLogin: resolved ws=\(workspaceSlug)")
        return .success(login)
    }

    // MARK: - answer_planner_form (confirmation required)

    func buildAnswerPlannerFormTool() -> TypedTool<AnswerPlannerFormInput, JSONValue> {
        tool(
            description: "Answer the planner's clarifying questions on a Hive feature (use plannerMessageId from get_plan_chat_history). Supply either `answers` (one per question, in order) or a single `answer`, never both. IMPORTANT: Before invoking, show the user the exact answer text that will be sent and ask for explicit confirmation. Only invoke after the user confirms.",
            execute: { (input: AnswerPlannerFormInput, _: ToolCallOptions) async throws -> ToolExecutionResult<JSONValue> in
                print("[AIAgent] answer_planner_form: ws=\(input.workspace_name) messageId=\(input.planner_message_id)")
                if input.answers != nil && input.answer != nil {
                    return .value(.string("Provide either `answers` or `answer`, not both."))
                }
                let parts = (input.answers ?? input.answer.map { [$0] } ?? [])
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                guard !parts.isEmpty else { return .value(.string("No answer text was provided.")) }
                switch await self.resolveFeature(workspaceName: input.workspace_name, featureName: input.feature_name) {
                case .failure(let m): return .value(.string(m))
                case .found(let ws, let feature):
                    guard let slug = ws.slug else {
                        return .value(.string("Workspace '\(ws.name)' has no slug; cannot resolve its Hive org."))
                    }
                    let msgs: [HiveChatMessage]? = await withCheckedContinuation { c in
                        API.sharedInstance.fetchFeatureChatWithAuth(
                            featureId: feature.id,
                            callback: { c.resume(returning: $0) },
                            errorCallback: { c.resume(returning: nil) })
                    }
                    guard let messages = msgs else {
                        return .value(.string("Failed to fetch plan chat (feature missing or no access)."))
                    }
                    guard messages.contains(where: {
                        $0.id == input.planner_message_id && HivePlanFormatter.isClarifyingPlannerMessage($0)
                    }) else {
                        print("[AIAgent] answer_planner_form: message not in feature chat feature=\(feature.id)")
                        return .value(.string("That plannerMessageId is not a planner clarifying-questions message in this feature's chat. Use get_plan_chat_history to find it."))
                    }
                    guard case .success(let login) = await self.resolveOrgLogin(workspaceSlug: slug) else {
                        return .value(.string("Couldn't determine which Hive org owns workspace \(slug)."))
                    }
                    let result: PlannerFormAnswerResult = await withCheckedContinuation { c in
                        API.sharedInstance.answerPlannerForm(
                            githubLogin: login, featureId: feature.id,
                            plannerMessageId: input.planner_message_id,
                            answer: parts.joined(separator: "\n\n"),
                            completion: { c.resume(returning: $0) })
                    }
                    print("[AIAgent] answer_planner_form: done feature=\(feature.id)")
                    return .value(.string(HivePlanFormatter.answerResultMessage(result)))
                }
            }
        )
    }
}
