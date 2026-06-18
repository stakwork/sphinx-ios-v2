//
//  AIAgentManager+HiveTools.swift
//  sphinx
//
//  Created for Sphinx Agent Hive Tools integration.
//  Copyright © 2026 sphinx. All rights reserved.
//

import Foundation
import SwiftAISDK

// MARK: - AIAgentManager + Hive Tools

extension AIAgentManager {

    // MARK: - Shared Helpers

    /// Resolves a named Hive item (feature or task) from a list using 3-pass fuzzy match.
    /// - Returns: (.match, []) on success, (.nil, [candidates]) when ambiguous, (.nil, []) when not found.
    static func resolveHiveItem<T>(
        query: String, items: [T], name: (T) -> String
    ) -> (match: T?, candidates: [String]) {
        let normalizedQuery = normalizeName(query)

        // Pass 1: exact normalised match
        if let exact = items.first(where: { normalizeName(name($0)) == normalizedQuery }) {
            return (exact, [])
        }

        // Pass 2: contains match
        let contains = items.filter { normalizeName(name($0)).contains(normalizedQuery) }
        if contains.count == 1 { return (contains[0], []) }
        if contains.count > 1  { return (nil, contains.map { name($0) }) }

        // Pass 3: Levenshtein fuzzy match
        let threshold = max(1, normalizedQuery.count / 4)
        var fuzzy: [(item: T, dist: Int)] = items.compactMap { item in
            let d = levenshteinDistance(normalizeName(name(item)), normalizedQuery)
            return d <= threshold ? (item: item, dist: d) : nil
        }
        fuzzy.sort { $0.dist < $1.dist }

        if fuzzy.isEmpty { return (nil, []) }
        if fuzzy.count == 1 { return (fuzzy[0].item, []) }
        if fuzzy[0].dist + 2 <= fuzzy[1].dist { return (fuzzy[0].item, []) }
        return (nil, fuzzy.map { name($0.item) })
    }

    /// Resolves a workspace by name from a list using 3-pass fuzzy match (mirrors buildQueryHiveGraphTool logic).
    static func resolveWorkspace(query: String, from workspaces: [Workspace]) -> (workspace: Workspace?, candidates: [String]) {
        let (match, candidates) = resolveHiveItem(query: query, items: workspaces, name: { $0.name })
        return (workspace: match, candidates: candidates)
    }

    // MARK: - Input Structs

    struct WorkspaceNameInput: Codable, Sendable {
        let workspace_name: String
    }

    struct SearchWorkspaceInput: Codable, Sendable {
        let workspace_name: String
        let query: String
    }

    struct ListTasksInput: Codable, Sendable {
        let workspace_name: String
        let include_archived: Bool?
    }

    struct FeatureNameInput: Codable, Sendable {
        let workspace_name: String
        let feature_name: String
    }

    struct TaskNameInput: Codable, Sendable {
        let workspace_name: String
        let task_name: String
    }

    struct CreateFeatureInput: Codable, Sendable {
        let workspace_name: String
        let title: String
    }

    struct UpdateFeatureInput: Codable, Sendable {
        let workspace_name: String
        let feature_name: String
        let status: String?
        let priority: String?
    }

    struct UpdateTaskStatusInput: Codable, Sendable {
        let workspace_name: String
        let task_name: String
        let status: String
    }

    // MARK: - Org Cache Helpers

    /// Fetches the first Hive org and caches orgId + githubLogin in UserDefaults.
    static func fetchAndCacheHiveOrg() async {
        let org: HiveOrg? = await withCheckedContinuation { continuation in
            API.sharedInstance.fetchOrgsWithAuth(
                callback: { org in continuation.resume(returning: org) },
                errorCallback: { continuation.resume(returning: nil) }
            )
        }
        guard let org = org else {
            print("[AIAgent] fetchAndCacheHiveOrg: failed to fetch org")
            return
        }
        UserDefaults.Keys.hiveOrgId.set(org.id)
        UserDefaults.Keys.hiveGithubLogin.set(org.githubLogin)
        print("[AIAgent] fetchAndCacheHiveOrg: cached orgId=\(org.id) login=\(org.githubLogin)")
    }

    /// Fetches org workspace slugs and caches them. Clears conversationId map if slugs changed.
    static func fetchAndCacheOrgSlugs() async {
        // Ensure githubLogin is available
        if UserDefaults.Keys.hiveGithubLogin.get() == nil {
            await fetchAndCacheHiveOrg()
        }
        guard let githubLogin: String = UserDefaults.Keys.hiveGithubLogin.get() else {
            print("[AIAgent] fetchAndCacheOrgSlugs: no githubLogin available")
            return
        }

        let slugs: [String]? = await withCheckedContinuation { continuation in
            API.sharedInstance.fetchOrgWorkspacesWithAuth(
                githubLogin: githubLogin,
                callback: { slugs in continuation.resume(returning: slugs) },
                errorCallback: { continuation.resume(returning: nil) }
            )
        }
        guard let slugs = slugs else {
            print("[AIAgent] fetchAndCacheOrgSlugs: failed to fetch org workspaces")
            return
        }

        // Check if slugs changed — if so, clear conversationId map
        if let existingData: Data = UserDefaults.Keys.hiveOrgSlugs.get(),
           let existingSlugs = try? JSONDecoder().decode([String].self, from: existingData),
           Set(existingSlugs) != Set(slugs) {
            print("[AIAgent] fetchAndCacheOrgSlugs: slug list changed, clearing conversationId cache")
            UserDefaults.Keys.hiveConversationIdByOrg.set(nil as Data?)
        }

        if let encoded = try? JSONEncoder().encode(slugs) {
            UserDefaults.Keys.hiveOrgSlugs.set(encoded)
        }
        UserDefaults.Keys.hiveOrgSlugsCacheDate.set(Date().timeIntervalSince1970)
        print("[AIAgent] fetchAndCacheOrgSlugs: cached \(slugs.count) slug(s)")
    }

    /// Returns cached org slugs if the cache is less than 24 hours old, otherwise nil.
    static func cachedOrgSlugs() -> [String]? {
        guard let cacheDate: Double = UserDefaults.Keys.hiveOrgSlugsCacheDate.get(),
              Date().timeIntervalSince1970 - cacheDate < 86400,
              let data: Data = UserDefaults.Keys.hiveOrgSlugs.get(),
              let slugs = try? JSONDecoder().decode([String].self, from: data) else {
            return nil
        }
        return slugs
    }

    // MARK: - Helper: fetch workspaces async

    private func fetchWorkspacesAsync() async -> [Workspace]? {
        return await withCheckedContinuation { continuation in
            API.sharedInstance.fetchWorkspacesWithAuth(
                callback: { workspaces in continuation.resume(returning: workspaces) },
                errorCallback: { continuation.resume(returning: nil) }
            )
        }
    }

    // MARK: - 1. list_hive_workspaces

    func buildListHiveWorkspacesTool() -> TypedTool<JSONValue, JSONValue> {
        let inputSchema = FlexibleSchema<JSONValue>(
            jsonSchema(.object([
                "type": .string("object"),
                "properties": .object([:]),
                "required": .array([])
            ]))
        )
        return tool(
            description: "List all Hive workspaces the user has access to.",
            inputSchema: inputSchema,
            execute: { (_: JSONValue, _: ToolCallOptions) async throws -> ToolExecutionResult<JSONValue> in
                guard let workspaces = await self.fetchWorkspacesAsync() else {
                    return .value(.string("Failed to fetch Hive workspaces. Make sure your Hive token is configured."))
                }
                if workspaces.isEmpty { return .value(.string("No Hive workspaces found.")) }
                let lines = workspaces.enumerated().map { (i, ws) in
                    "\(i + 1). \(ws.name) (slug: \(ws.slug ?? ws.id))"
                }
                return .value(.string(lines.joined(separator: "\n")))
            }
        )
    }

    // MARK: - 2. get_workspace_detail

    func buildGetWorkspaceDetailTool() -> TypedTool<WorkspaceNameInput, JSONValue> {
        tool(
            description: "Get the repositories and members for a named Hive workspace.",
            execute: { (input: WorkspaceNameInput, _: ToolCallOptions) async throws -> ToolExecutionResult<JSONValue> in
                guard let workspaces = await self.fetchWorkspacesAsync() else {
                    return .value(.string("Failed to fetch Hive workspaces. Make sure your Hive token is configured."))
                }
                let (ws, candidates) = AIAgentManager.resolveWorkspace(query: input.workspace_name, from: workspaces)
                guard let workspace = ws else {
                    if candidates.isEmpty {
                        let available = workspaces.map { $0.name }.joined(separator: ", ")
                        return .value(.string("No workspace found matching '\(input.workspace_name)'. Available: \(available)."))
                    }
                    return .value(.string("Multiple workspaces match '\(input.workspace_name)': \(candidates.joined(separator: ", ")). Please be more specific."))
                }
                let slug = workspace.slug ?? workspace.id

                async let reposResult: [WorkspaceRepository]? = withCheckedContinuation { continuation in
                    API.sharedInstance.fetchWorkspaceDetailWithAuth(
                        slug: slug,
                        callback: { repos in continuation.resume(returning: repos) },
                        errorCallback: { continuation.resume(returning: nil) }
                    )
                }
                async let membersResult: [WorkspaceMember]? = withCheckedContinuation { continuation in
                    API.sharedInstance.fetchWorkspaceMembersWithAuth(
                        slug: slug,
                        callback: { members in continuation.resume(returning: members) },
                        errorCallback: { continuation.resume(returning: nil) }
                    )
                }

                let repos = await reposResult
                let members = await membersResult

                var lines: [String] = ["Workspace: \(workspace.name)"]

                lines.append("\nRepositories:")
                if let repos = repos, !repos.isEmpty {
                    for r in repos {
                        lines.append("  - \(r.name) (\(r.repositoryUrl))\(r.branch.map { " [branch: \($0)]" } ?? "")")
                    }
                } else {
                    lines.append("  (none)")
                }

                lines.append("\nMembers:")
                if let members = members, !members.isEmpty {
                    for m in members {
                        let pubkey = m.lightningPubkey.map { " pubkey: \($0)" } ?? ""
                        lines.append("  - [\(m.role)] userId:\(m.userId)\(pubkey)")
                    }
                } else {
                    lines.append("  (none)")
                }

                return .value(.string(lines.joined(separator: "\n")))
            }
        )
    }

    // MARK: - 3. search_workspace

    func buildSearchWorkspaceTool() -> TypedTool<SearchWorkspaceInput, JSONValue> {
        tool(
            description: "Full-text search across features and tasks in a Hive workspace.",
            execute: { (input: SearchWorkspaceInput, _: ToolCallOptions) async throws -> ToolExecutionResult<JSONValue> in
                guard let workspaces = await self.fetchWorkspacesAsync() else {
                    return .value(.string("Failed to fetch Hive workspaces. Make sure your Hive token is configured."))
                }
                let (ws, candidates) = AIAgentManager.resolveWorkspace(query: input.workspace_name, from: workspaces)
                guard let workspace = ws else {
                    if candidates.isEmpty {
                        let available = workspaces.map { $0.name }.joined(separator: ", ")
                        return .value(.string("No workspace found matching '\(input.workspace_name)'. Available: \(available)."))
                    }
                    return .value(.string("Multiple workspaces match '\(input.workspace_name)': \(candidates.joined(separator: ", ")). Please be more specific."))
                }
                let slug = workspace.slug ?? workspace.id

                let results: HiveSearchResults? = await withCheckedContinuation { continuation in
                    API.sharedInstance.searchWorkspaceWithAuth(
                        slug: slug,
                        query: input.query,
                        callback: { results in continuation.resume(returning: results) },
                        errorCallback: { continuation.resume(returning: nil) }
                    )
                }

                guard let results = results else {
                    return .value(.string("Search failed for query '\(input.query)' in workspace '\(workspace.name)'."))
                }

                var lines: [String] = ["Search results for '\(input.query)' in '\(workspace.name)' (total: \(results.total)):"]

                if !results.features.isEmpty {
                    lines.append("\nFeatures:")
                    for f in results.features {
                        let status = f.status.map { " [\($0)]" } ?? ""
                        lines.append("  - \(f.title)\(status)")
                    }
                }
                if !results.tasks.isEmpty {
                    lines.append("\nTasks:")
                    for t in results.tasks {
                        let status = t.status.map { " [\($0)]" } ?? ""
                        let feature = t.featureTitle.map { " (feature: \($0))" } ?? ""
                        lines.append("  - \(t.title)\(status)\(feature)")
                    }
                }
                if results.features.isEmpty && results.tasks.isEmpty {
                    lines.append("  No results found.")
                }

                return .value(.string(lines.joined(separator: "\n")))
            }
        )
    }

    // MARK: - 4. list_features

    func buildListFeaturesTool() -> TypedTool<WorkspaceNameInput, JSONValue> {
        tool(
            description: "List features in a Hive workspace (first page of up to 20).",
            execute: { (input: WorkspaceNameInput, _: ToolCallOptions) async throws -> ToolExecutionResult<JSONValue> in
                guard let workspaces = await self.fetchWorkspacesAsync() else {
                    return .value(.string("Failed to fetch Hive workspaces. Make sure your Hive token is configured."))
                }
                let (ws, candidates) = AIAgentManager.resolveWorkspace(query: input.workspace_name, from: workspaces)
                guard let workspace = ws else {
                    if candidates.isEmpty {
                        let available = workspaces.map { $0.name }.joined(separator: ", ")
                        return .value(.string("No workspace found matching '\(input.workspace_name)'. Available: \(available)."))
                    }
                    return .value(.string("Multiple workspaces match '\(input.workspace_name)': \(candidates.joined(separator: ", ")). Please be more specific."))
                }

                let featureResult: ([HiveFeature], PaginationInfo)? = await withCheckedContinuation { continuation in
                    API.sharedInstance.fetchFeaturesWithAuth(
                        workspaceId: workspace.id,
                        page: 1,
                        callback: { features, pagination in continuation.resume(returning: (features, pagination)) },
                        errorCallback: { continuation.resume(returning: nil) }
                    )
                }

                guard let (features, pagination) = featureResult else {
                    return .value(.string("Failed to fetch features for workspace '\(workspace.name)'."))
                }
                if features.isEmpty { return .value(.string("No features found in workspace '\(workspace.name)'.")) }

                var lines = features.enumerated().map { (i, f) in
                    "\(i + 1). \(f.title) [\(f.status ?? "unknown")] (\(f.priority ?? "unknown"))"
                }
                if pagination.hasMore {
                    lines.append("(Showing first 20 of \(pagination.totalCount) features)")
                }
                return .value(.string(lines.joined(separator: "\n")))
            }
        )
    }

    // MARK: - 5. get_feature_detail

    func buildGetFeatureDetailTool() -> TypedTool<FeatureNameInput, JSONValue> {
        tool(
            description: "Get full details of a named Hive feature including status, priority, and task summary.",
            execute: { (input: FeatureNameInput, _: ToolCallOptions) async throws -> ToolExecutionResult<JSONValue> in
                guard let workspaces = await self.fetchWorkspacesAsync() else {
                    return .value(.string("Failed to fetch Hive workspaces. Make sure your Hive token is configured."))
                }
                let (ws, wsCandidates) = AIAgentManager.resolveWorkspace(query: input.workspace_name, from: workspaces)
                guard let workspace = ws else {
                    if wsCandidates.isEmpty {
                        let available = workspaces.map { $0.name }.joined(separator: ", ")
                        return .value(.string("No workspace found matching '\(input.workspace_name)'. Available: \(available)."))
                    }
                    return .value(.string("Multiple workspaces match '\(input.workspace_name)': \(wsCandidates.joined(separator: ", ")). Please be more specific."))
                }

                let featureListResult: ([HiveFeature], PaginationInfo)? = await withCheckedContinuation { continuation in
                    API.sharedInstance.fetchFeaturesWithAuth(
                        workspaceId: workspace.id,
                        page: 1,
                        callback: { features, pagination in continuation.resume(returning: (features, pagination)) },
                        errorCallback: { continuation.resume(returning: nil) }
                    )
                }
                guard let (features, _) = featureListResult else {
                    return .value(.string("Failed to fetch features for workspace '\(workspace.name)'."))
                }

                let (match, fCandidates) = AIAgentManager.resolveHiveItem(
                    query: input.feature_name,
                    items: features,
                    name: { $0.title }
                )
                guard let featureStub = match else {
                    if fCandidates.isEmpty {
                        let available = features.map { $0.title }.joined(separator: ", ")
                        return .value(.string("No feature found matching '\(input.feature_name)'. Available: \(available)."))
                    }
                    return .value(.string("Multiple features match '\(input.feature_name)': \(fCandidates.joined(separator: ", ")). Please be more specific."))
                }

                let detail: HiveFeature? = await withCheckedContinuation { continuation in
                    API.sharedInstance.fetchFeatureDetailWithAuth(
                        featureId: featureStub.id,
                        callback: { feature in continuation.resume(returning: feature) },
                        errorCallback: { continuation.resume(returning: nil) }
                    )
                }
                guard let feature = detail else {
                    return .value(.string("Failed to fetch detail for feature '\(featureStub.title)'."))
                }

                let taskCount = feature.allTasks.count
                let assigneeName = feature.assignee?.name ?? "(unassigned)"
                var lines: [String] = [
                    "Feature: \(feature.title)",
                    "Status: \(feature.status ?? "unknown")",
                    "Priority: \(feature.priority ?? "unknown")",
                    "Workflow Status: \(feature.workflowStatus ?? "none")",
                    "Deployment Status: \(feature.deploymentStatus ?? "none")",
                    "Assignee: \(assigneeName)",
                    "Task Count: \(taskCount)",
                ]
                if let desc = feature.description, !desc.isEmpty {
                    lines.append("Description: \(desc)")
                }
                return .value(.string(lines.joined(separator: "\n")))
            }
        )
    }

    // MARK: - 6. list_tasks

    func buildListTasksTool() -> TypedTool<ListTasksInput, JSONValue> {
        tool(
            description: "List tasks in a Hive workspace. Pass include_archived=true to include archived tasks.",
            execute: { (input: ListTasksInput, _: ToolCallOptions) async throws -> ToolExecutionResult<JSONValue> in
                guard let workspaces = await self.fetchWorkspacesAsync() else {
                    return .value(.string("Failed to fetch Hive workspaces. Make sure your Hive token is configured."))
                }
                let (ws, candidates) = AIAgentManager.resolveWorkspace(query: input.workspace_name, from: workspaces)
                guard let workspace = ws else {
                    if candidates.isEmpty {
                        let available = workspaces.map { $0.name }.joined(separator: ", ")
                        return .value(.string("No workspace found matching '\(input.workspace_name)'. Available: \(available)."))
                    }
                    return .value(.string("Multiple workspaces match '\(input.workspace_name)': \(candidates.joined(separator: ", ")). Please be more specific."))
                }

                let includeArchived = input.include_archived ?? false
                let taskResult: ([WorkspaceTask], PaginationInfo)? = await withCheckedContinuation { continuation in
                    API.sharedInstance.fetchTasksWithAuth(
                        workspaceId: workspace.id,
                        includeArchived: includeArchived,
                        page: 1,
                        callback: { tasks, pagination in continuation.resume(returning: (tasks, pagination)) },
                        errorCallback: { continuation.resume(returning: nil) }
                    )
                }
                guard let (tasks, pagination) = taskResult else {
                    return .value(.string("Failed to fetch tasks for workspace '\(workspace.name)'."))
                }
                if tasks.isEmpty { return .value(.string("No tasks found in workspace '\(workspace.name)'.")) }

                var lines = tasks.enumerated().map { (i, t) in
                    let wf = t.workflowStatus ?? ""
                    let wfSuffix = wf.isEmpty ? "" : " — \(wf)"
                    return "\(i + 1). \(t.title) [\(t.status)] (\(t.priority))\(wfSuffix)"
                }
                if pagination.hasMore {
                    lines.append("(Showing first page of \(pagination.totalCount) tasks)")
                }
                return .value(.string(lines.joined(separator: "\n")))
            }
        )
    }

    // MARK: - 7. get_task_detail

    func buildGetTaskDetailTool() -> TypedTool<TaskNameInput, JSONValue> {
        tool(
            description: "Get full details of a named task in a Hive workspace.",
            execute: { (input: TaskNameInput, _: ToolCallOptions) async throws -> ToolExecutionResult<JSONValue> in
                guard let workspaces = await self.fetchWorkspacesAsync() else {
                    return .value(.string("Failed to fetch Hive workspaces. Make sure your Hive token is configured."))
                }
                let (ws, wsCandidates) = AIAgentManager.resolveWorkspace(query: input.workspace_name, from: workspaces)
                guard let workspace = ws else {
                    if wsCandidates.isEmpty {
                        let available = workspaces.map { $0.name }.joined(separator: ", ")
                        return .value(.string("No workspace found matching '\(input.workspace_name)'. Available: \(available)."))
                    }
                    return .value(.string("Multiple workspaces match '\(input.workspace_name)': \(wsCandidates.joined(separator: ", ")). Please be more specific."))
                }

                let taskListResult: ([WorkspaceTask], PaginationInfo)? = await withCheckedContinuation { continuation in
                    API.sharedInstance.fetchTasksWithAuth(
                        workspaceId: workspace.id,
                        page: 1,
                        callback: { tasks, pagination in continuation.resume(returning: (tasks, pagination)) },
                        errorCallback: { continuation.resume(returning: nil) }
                    )
                }
                guard let (tasks, _) = taskListResult else {
                    return .value(.string("Failed to fetch tasks for workspace '\(workspace.name)'."))
                }

                let (match, tCandidates) = AIAgentManager.resolveHiveItem(
                    query: input.task_name,
                    items: tasks,
                    name: { $0.title }
                )
                guard let taskStub = match else {
                    if tCandidates.isEmpty {
                        let available = tasks.map { $0.title }.joined(separator: ", ")
                        return .value(.string("No task found matching '\(input.task_name)'. Available: \(available)."))
                    }
                    return .value(.string("Multiple tasks match '\(input.task_name)': \(tCandidates.joined(separator: ", ")). Please be more specific."))
                }

                let detail: WorkspaceTask? = await withCheckedContinuation { continuation in
                    API.sharedInstance.fetchTaskDetailWithAuth(
                        taskId: taskStub.id,
                        callback: { task in continuation.resume(returning: task) },
                        errorCallback: { continuation.resume(returning: nil) }
                    )
                }
                guard let task = detail else {
                    return .value(.string("Failed to fetch detail for task '\(taskStub.title)'."))
                }

                var lines: [String] = [
                    "Task: \(task.title)",
                    "Status: \(task.status)",
                    "Priority: \(task.priority)",
                    "Workflow Status: \(task.workflowStatus ?? "none")",
                    "Feature: \(task.featureTitle ?? "(none)")",
                    "Repository: \(task.repositoryName ?? "(none)")",
                    "Assignee: \(task.assigneeName ?? "(unassigned)")",
                    "Deployment Status: \(task.deploymentStatus ?? "none")",
                    "Chat Messages: \(task.chatMessageCount)",
                ]
                if let prUrl = task.prUrl {
                    lines.append("PR URL: \(prUrl)")
                    lines.append("PR Status: \(task.prStatus ?? "unknown")")
                }
                return .value(.string(lines.joined(separator: "\n")))
            }
        )
    }

    // MARK: - 8. get_task_messages

    func buildGetTaskMessagesTool() -> TypedTool<TaskNameInput, JSONValue> {
        tool(
            description: "Read the agent chat message history for a named Hive task.",
            execute: { (input: TaskNameInput, _: ToolCallOptions) async throws -> ToolExecutionResult<JSONValue> in
                guard let workspaces = await self.fetchWorkspacesAsync() else {
                    return .value(.string("Failed to fetch Hive workspaces. Make sure your Hive token is configured."))
                }
                let (ws, wsCandidates) = AIAgentManager.resolveWorkspace(query: input.workspace_name, from: workspaces)
                guard let workspace = ws else {
                    if wsCandidates.isEmpty {
                        let available = workspaces.map { $0.name }.joined(separator: ", ")
                        return .value(.string("No workspace found matching '\(input.workspace_name)'. Available: \(available)."))
                    }
                    return .value(.string("Multiple workspaces match '\(input.workspace_name)': \(wsCandidates.joined(separator: ", ")). Please be more specific."))
                }

                let taskListResult: ([WorkspaceTask], PaginationInfo)? = await withCheckedContinuation { continuation in
                    API.sharedInstance.fetchTasksWithAuth(
                        workspaceId: workspace.id,
                        page: 1,
                        callback: { tasks, pagination in continuation.resume(returning: (tasks, pagination)) },
                        errorCallback: { continuation.resume(returning: nil) }
                    )
                }
                guard let (tasks, _) = taskListResult else {
                    return .value(.string("Failed to fetch tasks for workspace '\(workspace.name)'."))
                }

                let (match, tCandidates) = AIAgentManager.resolveHiveItem(
                    query: input.task_name,
                    items: tasks,
                    name: { $0.title }
                )
                guard let taskStub = match else {
                    if tCandidates.isEmpty {
                        let available = tasks.map { $0.title }.joined(separator: ", ")
                        return .value(.string("No task found matching '\(input.task_name)'. Available: \(available)."))
                    }
                    return .value(.string("Multiple tasks match '\(input.task_name)': \(tCandidates.joined(separator: ", ")). Please be more specific."))
                }

                let messagesResult: ([HiveChatMessage], String?)? = await withCheckedContinuation { continuation in
                    API.sharedInstance.fetchTaskMessagesWithAuth(
                        taskId: taskStub.id,
                        callback: { messages, cursor in continuation.resume(returning: (messages, cursor)) },
                        errorCallback: { continuation.resume(returning: nil) }
                    )
                }
                guard let (messages, _) = messagesResult else {
                    return .value(.string("Failed to fetch messages for task '\(taskStub.title)'."))
                }
                if messages.isEmpty {
                    return .value(.string("No messages found for task '\(taskStub.title)'."))
                }

                let last20 = messages.suffix(20)
                let lines = last20.map { msg in
                    "[\(msg.role ?? "unknown")]: \(msg.message ?? "")"
                }
                return .value(.string(lines.joined(separator: "\n")))
            }
        )
    }

    // MARK: - 9. create_feature (write — confirmation required)

    func buildCreateFeatureTool() -> TypedTool<CreateFeatureInput, JSONValue> {
        tool(
            description: "Create a new feature in a Hive workspace. IMPORTANT: Before invoking this tool, describe the action to the user and ask for explicit confirmation. Only invoke after the user confirms.",
            execute: { (input: CreateFeatureInput, _: ToolCallOptions) async throws -> ToolExecutionResult<JSONValue> in
                print("[AIAgent] create_feature: \(input.workspace_name)/\(input.title)")
                guard let workspaces = await self.fetchWorkspacesAsync() else {
                    return .value(.string("Failed to fetch Hive workspaces. Make sure your Hive token is configured."))
                }
                let (ws, candidates) = AIAgentManager.resolveWorkspace(query: input.workspace_name, from: workspaces)
                guard let workspace = ws else {
                    if candidates.isEmpty {
                        let available = workspaces.map { $0.name }.joined(separator: ", ")
                        return .value(.string("No workspace found matching '\(input.workspace_name)'. Available: \(available)."))
                    }
                    return .value(.string("Multiple workspaces match '\(input.workspace_name)': \(candidates.joined(separator: ", ")). Please be more specific."))
                }

                let created: HiveFeature? = await withCheckedContinuation { continuation in
                    API.sharedInstance.createFeatureWithAuth(
                        workspaceId: workspace.id,
                        title: input.title,
                        callback: { feature in continuation.resume(returning: feature) },
                        errorCallback: { continuation.resume(returning: nil) }
                    )
                }
                guard created != nil else {
                    return .value(.string("Failed to create feature '\(input.title)' in workspace '\(workspace.name)'."))
                }
                return .value(.string("Feature '\(input.title)' created successfully in workspace '\(workspace.name)'."))
            }
        )
    }

    // MARK: - 10. update_feature (write — confirmation required)

    func buildUpdateFeatureTool() -> TypedTool<UpdateFeatureInput, JSONValue> {
        tool(
            description: "Update the status or priority of a Hive feature. IMPORTANT: Before invoking this tool, describe the action to the user and ask for explicit confirmation. Only invoke after the user confirms.",
            execute: { (input: UpdateFeatureInput, _: ToolCallOptions) async throws -> ToolExecutionResult<JSONValue> in
                print("[AIAgent] update_feature: \(input.workspace_name)/\(input.feature_name)")
                guard let workspaces = await self.fetchWorkspacesAsync() else {
                    return .value(.string("Failed to fetch Hive workspaces. Make sure your Hive token is configured."))
                }
                let (ws, wsCandidates) = AIAgentManager.resolveWorkspace(query: input.workspace_name, from: workspaces)
                guard let workspace = ws else {
                    if wsCandidates.isEmpty {
                        let available = workspaces.map { $0.name }.joined(separator: ", ")
                        return .value(.string("No workspace found matching '\(input.workspace_name)'. Available: \(available)."))
                    }
                    return .value(.string("Multiple workspaces match '\(input.workspace_name)': \(wsCandidates.joined(separator: ", ")). Please be more specific."))
                }

                let featureListResult: ([HiveFeature], PaginationInfo)? = await withCheckedContinuation { continuation in
                    API.sharedInstance.fetchFeaturesWithAuth(
                        workspaceId: workspace.id,
                        page: 1,
                        callback: { features, pagination in continuation.resume(returning: (features, pagination)) },
                        errorCallback: { continuation.resume(returning: nil) }
                    )
                }
                guard let (features, _) = featureListResult else {
                    return .value(.string("Failed to fetch features for workspace '\(workspace.name)'."))
                }

                let (match, fCandidates) = AIAgentManager.resolveHiveItem(
                    query: input.feature_name,
                    items: features,
                    name: { $0.title }
                )
                guard let feature = match else {
                    if fCandidates.isEmpty {
                        let available = features.map { $0.title }.joined(separator: ", ")
                        return .value(.string("No feature found matching '\(input.feature_name)'. Available: \(available)."))
                    }
                    return .value(.string("Multiple features match '\(input.feature_name)': \(fCandidates.joined(separator: ", ")). Please be more specific."))
                }

                let updated: HiveFeature? = await withCheckedContinuation { continuation in
                    API.sharedInstance.updateFeatureWithAuth(
                        featureId: feature.id,
                        status: input.status,
                        priority: input.priority,
                        callback: { f in continuation.resume(returning: f) },
                        errorCallback: { continuation.resume(returning: nil) }
                    )
                }
                guard updated != nil else {
                    return .value(.string("Failed to update feature '\(feature.title)'."))
                }
                let statusStr = input.status ?? "(unchanged)"
                let priorityStr = input.priority ?? "(unchanged)"
                return .value(.string("Feature '\(feature.title)' updated: status=\(statusStr), priority=\(priorityStr)."))
            }
        )
    }

    // MARK: - 11. trigger_task_generation (write — confirmation required)

    func buildTriggerTaskGenerationTool() -> TypedTool<FeatureNameInput, JSONValue> {
        tool(
            description: "Trigger AI task breakdown for a named Hive feature. IMPORTANT: Before invoking this tool, describe the action to the user and ask for explicit confirmation. Only invoke after the user confirms.",
            execute: { (input: FeatureNameInput, _: ToolCallOptions) async throws -> ToolExecutionResult<JSONValue> in
                print("[AIAgent] trigger_task_generation: \(input.workspace_name)/\(input.feature_name)")
                guard let workspaces = await self.fetchWorkspacesAsync() else {
                    return .value(.string("Failed to fetch Hive workspaces. Make sure your Hive token is configured."))
                }
                let (ws, wsCandidates) = AIAgentManager.resolveWorkspace(query: input.workspace_name, from: workspaces)
                guard let workspace = ws else {
                    if wsCandidates.isEmpty {
                        let available = workspaces.map { $0.name }.joined(separator: ", ")
                        return .value(.string("No workspace found matching '\(input.workspace_name)'. Available: \(available)."))
                    }
                    return .value(.string("Multiple workspaces match '\(input.workspace_name)': \(wsCandidates.joined(separator: ", ")). Please be more specific."))
                }

                let featureListResult: ([HiveFeature], PaginationInfo)? = await withCheckedContinuation { continuation in
                    API.sharedInstance.fetchFeaturesWithAuth(
                        workspaceId: workspace.id,
                        page: 1,
                        callback: { features, pagination in continuation.resume(returning: (features, pagination)) },
                        errorCallback: { continuation.resume(returning: nil) }
                    )
                }
                guard let (features, _) = featureListResult else {
                    return .value(.string("Failed to fetch features for workspace '\(workspace.name)'."))
                }

                let (match, fCandidates) = AIAgentManager.resolveHiveItem(
                    query: input.feature_name,
                    items: features,
                    name: { $0.title }
                )
                guard let feature = match else {
                    if fCandidates.isEmpty {
                        let available = features.map { $0.title }.joined(separator: ", ")
                        return .value(.string("No feature found matching '\(input.feature_name)'. Available: \(available)."))
                    }
                    return .value(.string("Multiple features match '\(input.feature_name)': \(fCandidates.joined(separator: ", ")). Please be more specific."))
                }

                let run: StakworkRun? = await withCheckedContinuation { continuation in
                    API.sharedInstance.triggerTaskGenerationWithAuth(
                        workspaceId: workspace.id,
                        featureId: feature.id,
                        includeHistory: false,
                        callback: { run in continuation.resume(returning: run) },
                        errorCallback: { continuation.resume(returning: nil) }
                    )
                }
                guard run != nil else {
                    return .value(.string("Failed to trigger task generation for feature '\(feature.title)'."))
                }
                return .value(.string("AI task generation started for feature '\(feature.title)'. Run ID: \(run?.id ?? "unknown")."))
            }
        )
    }

    // MARK: - 12. update_task_status (write — confirmation required)

    func buildUpdateTaskStatusTool() -> TypedTool<UpdateTaskStatusInput, JSONValue> {
        tool(
            description: "Update the status of a named Hive task. Valid statuses: TODO, IN_PROGRESS, DONE, CANCELLED, BLOCKED. IMPORTANT: Before invoking this tool, describe the action to the user and ask for explicit confirmation. Only invoke after the user confirms.",
            execute: { (input: UpdateTaskStatusInput, _: ToolCallOptions) async throws -> ToolExecutionResult<JSONValue> in
                print("[AIAgent] update_task_status: \(input.workspace_name)/\(input.task_name)")
                guard let workspaces = await self.fetchWorkspacesAsync() else {
                    return .value(.string("Failed to fetch Hive workspaces. Make sure your Hive token is configured."))
                }
                let (ws, wsCandidates) = AIAgentManager.resolveWorkspace(query: input.workspace_name, from: workspaces)
                guard let workspace = ws else {
                    if wsCandidates.isEmpty {
                        let available = workspaces.map { $0.name }.joined(separator: ", ")
                        return .value(.string("No workspace found matching '\(input.workspace_name)'. Available: \(available)."))
                    }
                    return .value(.string("Multiple workspaces match '\(input.workspace_name)': \(wsCandidates.joined(separator: ", ")). Please be more specific."))
                }

                let taskListResult: ([WorkspaceTask], PaginationInfo)? = await withCheckedContinuation { continuation in
                    API.sharedInstance.fetchTasksWithAuth(
                        workspaceId: workspace.id,
                        page: 1,
                        callback: { tasks, pagination in continuation.resume(returning: (tasks, pagination)) },
                        errorCallback: { continuation.resume(returning: nil) }
                    )
                }
                guard let (tasks, _) = taskListResult else {
                    return .value(.string("Failed to fetch tasks for workspace '\(workspace.name)'."))
                }

                let (match, tCandidates) = AIAgentManager.resolveHiveItem(
                    query: input.task_name,
                    items: tasks,
                    name: { $0.title }
                )
                guard let task = match else {
                    if tCandidates.isEmpty {
                        let available = tasks.map { $0.title }.joined(separator: ", ")
                        return .value(.string("No task found matching '\(input.task_name)'. Available: \(available)."))
                    }
                    return .value(.string("Multiple tasks match '\(input.task_name)': \(tCandidates.joined(separator: ", ")). Please be more specific."))
                }

                let success: Bool = await withCheckedContinuation { continuation in
                    API.sharedInstance.updateTaskStatusWithAuth(
                        taskId: task.id,
                        status: input.status,
                        callback: { continuation.resume(returning: true) },
                        errorCallback: { continuation.resume(returning: false) }
                    )
                }
                guard success else {
                    return .value(.string("Failed to update status for task '\(task.title)'."))
                }
                return .value(.string("Task '\(task.title)' status updated to '\(input.status)'."))
            }
        )
    }

    // MARK: - 13. start_task (write — confirmation required)

    func buildStartTaskTool() -> TypedTool<TaskNameInput, JSONValue> {
        tool(
            description: "Start the AI coding workflow for a named Hive task. IMPORTANT: Before invoking this tool, describe the action to the user and ask for explicit confirmation. Only invoke after the user confirms.",
            execute: { (input: TaskNameInput, _: ToolCallOptions) async throws -> ToolExecutionResult<JSONValue> in
                print("[AIAgent] start_task: \(input.workspace_name)/\(input.task_name)")
                guard let workspaces = await self.fetchWorkspacesAsync() else {
                    return .value(.string("Failed to fetch Hive workspaces. Make sure your Hive token is configured."))
                }
                let (ws, wsCandidates) = AIAgentManager.resolveWorkspace(query: input.workspace_name, from: workspaces)
                guard let workspace = ws else {
                    if wsCandidates.isEmpty {
                        let available = workspaces.map { $0.name }.joined(separator: ", ")
                        return .value(.string("No workspace found matching '\(input.workspace_name)'. Available: \(available)."))
                    }
                    return .value(.string("Multiple workspaces match '\(input.workspace_name)': \(wsCandidates.joined(separator: ", ")). Please be more specific."))
                }

                let taskListResult: ([WorkspaceTask], PaginationInfo)? = await withCheckedContinuation { continuation in
                    API.sharedInstance.fetchTasksWithAuth(
                        workspaceId: workspace.id,
                        page: 1,
                        callback: { tasks, pagination in continuation.resume(returning: (tasks, pagination)) },
                        errorCallback: { continuation.resume(returning: nil) }
                    )
                }
                guard let (tasks, _) = taskListResult else {
                    return .value(.string("Failed to fetch tasks for workspace '\(workspace.name)'."))
                }

                let (match, tCandidates) = AIAgentManager.resolveHiveItem(
                    query: input.task_name,
                    items: tasks,
                    name: { $0.title }
                )
                guard let task = match else {
                    if tCandidates.isEmpty {
                        let available = tasks.map { $0.title }.joined(separator: ", ")
                        return .value(.string("No task found matching '\(input.task_name)'. Available: \(available)."))
                    }
                    return .value(.string("Multiple tasks match '\(input.task_name)': \(tCandidates.joined(separator: ", ")). Please be more specific."))
                }

                let success: Bool = await withCheckedContinuation { continuation in
                    API.sharedInstance.startTaskWithAuth(
                        taskId: task.id,
                        callback: { continuation.resume(returning: true) },
                        errorCallback: { continuation.resume(returning: false) }
                    )
                }
                guard success else {
                    return .value(.string("Failed to start workflow for task '\(task.title)'."))
                }
                return .value(.string("Task '\(task.title)' workflow started successfully."))
            }
        )
    }

    // MARK: - 14. retry_task_workflow (write — confirmation required)

    func buildRetryTaskWorkflowTool() -> TypedTool<TaskNameInput, JSONValue> {
        tool(
            description: "Retry the workflow for a halted or failed Hive task. IMPORTANT: Before invoking this tool, describe the action to the user and ask for explicit confirmation. Only invoke after the user confirms.",
            execute: { (input: TaskNameInput, _: ToolCallOptions) async throws -> ToolExecutionResult<JSONValue> in
                print("[AIAgent] retry_task_workflow: \(input.workspace_name)/\(input.task_name)")
                guard let workspaces = await self.fetchWorkspacesAsync() else {
                    return .value(.string("Failed to fetch Hive workspaces. Make sure your Hive token is configured."))
                }
                let (ws, wsCandidates) = AIAgentManager.resolveWorkspace(query: input.workspace_name, from: workspaces)
                guard let workspace = ws else {
                    if wsCandidates.isEmpty {
                        let available = workspaces.map { $0.name }.joined(separator: ", ")
                        return .value(.string("No workspace found matching '\(input.workspace_name)'. Available: \(available)."))
                    }
                    return .value(.string("Multiple workspaces match '\(input.workspace_name)': \(wsCandidates.joined(separator: ", ")). Please be more specific."))
                }

                let taskListResult: ([WorkspaceTask], PaginationInfo)? = await withCheckedContinuation { continuation in
                    API.sharedInstance.fetchTasksWithAuth(
                        workspaceId: workspace.id,
                        page: 1,
                        callback: { tasks, pagination in continuation.resume(returning: (tasks, pagination)) },
                        errorCallback: { continuation.resume(returning: nil) }
                    )
                }
                guard let (tasks, _) = taskListResult else {
                    return .value(.string("Failed to fetch tasks for workspace '\(workspace.name)'."))
                }

                let (match, tCandidates) = AIAgentManager.resolveHiveItem(
                    query: input.task_name,
                    items: tasks,
                    name: { $0.title }
                )
                guard let task = match else {
                    if tCandidates.isEmpty {
                        let available = tasks.map { $0.title }.joined(separator: ", ")
                        return .value(.string("No task found matching '\(input.task_name)'. Available: \(available)."))
                    }
                    return .value(.string("Multiple tasks match '\(input.task_name)': \(tCandidates.joined(separator: ", ")). Please be more specific."))
                }

                let success: Bool = await withCheckedContinuation { continuation in
                    API.sharedInstance.retryTaskWorkflowWithAuth(
                        taskId: task.id,
                        callback: { continuation.resume(returning: true) },
                        errorCallback: { continuation.resume(returning: false) }
                    )
                }
                guard success else {
                    return .value(.string("Failed to retry workflow for task '\(task.title)'."))
                }
                return .value(.string("Task '\(task.title)' workflow retry triggered."))
            }
        )
    }

    // MARK: - 15. archive_task (write — confirmation required)

    func buildArchiveTaskTool() -> TypedTool<TaskNameInput, JSONValue> {
        tool(
            description: "Archive a named Hive task. IMPORTANT: Before invoking this tool, describe the action to the user and ask for explicit confirmation. Only invoke after the user confirms.",
            execute: { (input: TaskNameInput, _: ToolCallOptions) async throws -> ToolExecutionResult<JSONValue> in
                print("[AIAgent] archive_task: \(input.workspace_name)/\(input.task_name)")
                guard let workspaces = await self.fetchWorkspacesAsync() else {
                    return .value(.string("Failed to fetch Hive workspaces. Make sure your Hive token is configured."))
                }
                let (ws, wsCandidates) = AIAgentManager.resolveWorkspace(query: input.workspace_name, from: workspaces)
                guard let workspace = ws else {
                    if wsCandidates.isEmpty {
                        let available = workspaces.map { $0.name }.joined(separator: ", ")
                        return .value(.string("No workspace found matching '\(input.workspace_name)'. Available: \(available)."))
                    }
                    return .value(.string("Multiple workspaces match '\(input.workspace_name)': \(wsCandidates.joined(separator: ", ")). Please be more specific."))
                }

                let taskListResult: ([WorkspaceTask], PaginationInfo)? = await withCheckedContinuation { continuation in
                    API.sharedInstance.fetchTasksWithAuth(
                        workspaceId: workspace.id,
                        page: 1,
                        callback: { tasks, pagination in continuation.resume(returning: (tasks, pagination)) },
                        errorCallback: { continuation.resume(returning: nil) }
                    )
                }
                guard let (tasks, _) = taskListResult else {
                    return .value(.string("Failed to fetch tasks for workspace '\(workspace.name)'."))
                }

                let (match, tCandidates) = AIAgentManager.resolveHiveItem(
                    query: input.task_name,
                    items: tasks,
                    name: { $0.title }
                )
                guard let task = match else {
                    if tCandidates.isEmpty {
                        let available = tasks.map { $0.title }.joined(separator: ", ")
                        return .value(.string("No task found matching '\(input.task_name)'. Available: \(available)."))
                    }
                    return .value(.string("Multiple tasks match '\(input.task_name)': \(tCandidates.joined(separator: ", ")). Please be more specific."))
                }

                let success: Bool = await withCheckedContinuation { continuation in
                    API.sharedInstance.archiveTaskWithAuth(
                        taskId: task.id,
                        callback: { continuation.resume(returning: true) },
                        errorCallback: { continuation.resume(returning: false) }
                    )
                }
                guard success else {
                    return .value(.string("Failed to archive task '\(task.title)'."))
                }
                return .value(.string("Task '\(task.title)' archived."))
            }
        )
    }
}
