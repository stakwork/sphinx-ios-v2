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
    func onToolCall(toolName: String, input: [String: Any]?) {}
    func onToolOutputAvailable() {}
}

// MARK: - AIAgentManager + query_hive_graph tool

extension AIAgentManager {

    struct QueryHiveGraphInput: Codable, Sendable {
        let question: String
    }

    func buildQueryHiveGraphTool() -> TypedTool<QueryHiveGraphInput, JSONValue> {
        tool(
            description: "Query the Hive org knowledge graph (Jamie). Use this when the user asks about their org's codebase, project structure, recent commits, features, tasks, or asks to talk to Jamie. No workspace name is needed — Jamie has full access to the entire organization.",
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

                // 2. Read persisted conversationId for this org (nil on first call).
                // First call sends messages array; server returns X-Conversation-Id which is then stored.
                // Subsequent calls send message + conversationId (server-history mode).
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
                    return .value(.string("Hive authentication failed. Please check your Hive configuration."))
                }

                // 4. Stream via org SSE
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

                return .value(.string(result))
            }
        )
    }
}
