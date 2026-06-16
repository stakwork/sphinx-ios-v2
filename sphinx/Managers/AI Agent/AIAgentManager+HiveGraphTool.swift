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

    func onTextDelta(_ delta: String) {
        buffer += delta
    }

    func onFinish() {
        guard !resumed else { return }
        resumed = true
        let result = buffer.isEmpty ? "No response." : buffer
        print("AIAgent [HiveGraph] finished, buffer length: \(buffer.count)")
        sseManager?.stopStream()
        continuation?.resume(returning: result)
    }

    func onError(_ text: String) {
        guard !resumed else { return }
        resumed = true
        print("AIAgent [HiveGraph] error: \(text)")
        sseManager?.stopStream()
        continuation?.resume(returning: "Hive graph error: \(text)")
    }

    func onToolInputAvailable(toolName: String) {}
    func onToolCall(toolName: String, input: [String: Any]?) {}
    func onToolOutputAvailable() {}
}

// MARK: - AIAgentManager + query_hive_graph tool

extension AIAgentManager {

    struct QueryHiveGraphInput: Codable, Sendable {
        let workspace_name: String
        let question: String
    }

    func buildQueryHiveGraphTool() -> TypedTool<QueryHiveGraphInput, JSONValue> {
        tool(
            description: "Query a Hive workspace knowledge graph by workspace name and question. Use this when the user asks about their codebase, project structure, recent commits, or any information that lives in a Hive workspace graph.",
            execute: { (input: QueryHiveGraphInput, _: ToolCallOptions) async throws -> ToolExecutionResult<JSONValue> in

                // Step 1: Fetch workspaces
                let workspaces: [Workspace]? = await withCheckedContinuation { continuation in
                    API.sharedInstance.fetchWorkspacesWithAuth(
                        callback: { workspaces in
                            continuation.resume(returning: workspaces)
                        },
                        errorCallback: {
                            continuation.resume(returning: nil)
                        }
                    )
                }

                guard let workspaces = workspaces, !workspaces.isEmpty else {
                    return .value(.string("Failed to fetch Hive workspaces. Make sure your Hive token is configured."))
                }

                // Step 2: Fuzzy-match workspace name
                let queryName = input.workspace_name
                let normalizedQuery = AIAgentManager.normalizeName(queryName)

                // Pass 1: case-insensitive exact match (normalized)
                if let exactMatch = workspaces.first(where: { AIAgentManager.normalizeName($0.name) == normalizedQuery }) {
                    let slug = exactMatch.slug ?? exactMatch.id
                    return try await AIAgentManager.executeHiveGraphQuery(
                        workspaceName: exactMatch.name,
                        slug: slug,
                        question: input.question
                    )
                }

                // Pass 2: case-insensitive contains
                let containsMatches = workspaces.filter {
                    AIAgentManager.normalizeName($0.name).contains(normalizedQuery)
                }
                if containsMatches.count == 1 {
                    let match = containsMatches[0]
                    let slug = match.slug ?? match.id
                    return try await AIAgentManager.executeHiveGraphQuery(
                        workspaceName: match.name,
                        slug: slug,
                        question: input.question
                    )
                } else if containsMatches.count > 1 {
                    let names = containsMatches.map { $0.name }.joined(separator: ", ")
                    return .value(.string("Ambiguous workspace name '\(queryName)'. Multiple matches found: \(names). Please be more specific."))
                }

                // Pass 3: Levenshtein fuzzy match
                let threshold = max(1, normalizedQuery.count / 4)
                var fuzzyMatches: [(workspace: Workspace, dist: Int)] = workspaces.compactMap { ws in
                    let d = AIAgentManager.levenshteinDistance(AIAgentManager.normalizeName(ws.name), normalizedQuery)
                    return d <= threshold ? (workspace: ws, dist: d) : nil
                }
                fuzzyMatches.sort { $0.dist < $1.dist }

                if fuzzyMatches.isEmpty {
                    let available = workspaces.map { $0.name }.joined(separator: ", ")
                    return .value(.string("No Hive workspace found matching '\(queryName)'. Available workspaces: \(available)."))
                } else if fuzzyMatches.count == 1 {
                    let match = fuzzyMatches[0].workspace
                    let slug = match.slug ?? match.id
                    return try await AIAgentManager.executeHiveGraphQuery(
                        workspaceName: match.name,
                        slug: slug,
                        question: input.question
                    )
                } else {
                    // Check if the best match is clearly better
                    if fuzzyMatches[0].dist + 2 <= fuzzyMatches[1].dist {
                        let match = fuzzyMatches[0].workspace
                        let slug = match.slug ?? match.id
                        return try await AIAgentManager.executeHiveGraphQuery(
                            workspaceName: match.name,
                            slug: slug,
                            question: input.question
                        )
                    }
                    let names = fuzzyMatches.map { $0.workspace.name }.joined(separator: ", ")
                    return .value(.string("Ambiguous workspace name '\(queryName)'. Multiple possible matches: \(names). Please be more specific."))
                }
            }
        )
    }

    /// Resolves an auth token and executes the SSE graph query for the given workspace.
    private static func executeHiveGraphQuery(
        workspaceName: String,
        slug: String,
        question: String
    ) async throws -> ToolExecutionResult<JSONValue> {

        // Step 3: Resolve Hive auth token
        let token: String? = await withCheckedContinuation { continuation in
            API.sharedInstance.resolveHiveToken(
                callback: { token in continuation.resume(returning: token) },
                errorCallback: { continuation.resume(returning: nil) }
            )
        }

        guard let token = token else {
            return .value(.string("Hive authentication failed. Please check your Hive configuration."))
        }

        // Step 4: Create bridge + SSE manager, stream the query
        let bridge = HiveGraphBridge()
        let sseManager = GraphChatSSEManager()
        bridge.sseManager = sseManager
        sseManager.delegate = bridge

        print("AIAgent [HiveGraph] querying workspace '\(slug)': \(question)")

        // Step 5: Await completion via continuation
        // continuation is set BEFORE startStream to avoid race condition where
        // SSE response arrives before the continuation is registered
        let result: String = await withCheckedContinuation { continuation in
            bridge.continuation = continuation
            sseManager.startStream(
                messages: [["role": "user", "content": question]],
                workspaceSlug: slug,
                token: token
            )
        }

        return .value(.string(result))
    }

}
