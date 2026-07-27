//
//  GraphChatHistory.swift
//  sphinx
//
//  Created on 5/22/26.
//  Copyright © 2026 sphinx. All rights reserved.
//

import Foundation

/// In-memory cache that stores the last N Graph Chat messages per workspace ID
/// for the lifetime of the app session. Cleared on app termination.
final class GraphChatHistory: @unchecked Sendable {
    nonisolated(unsafe) static let shared = GraphChatHistory()
    private static let maxMessages = 20

    private var store: [String: [HiveChatMessage]] = [:]
    private let queue = DispatchQueue(label: "com.sphinx.graphChatHistory")

    private init() {}

    func save(_ messages: [HiveChatMessage], forWorkspaceId id: String) {
        let capped = Array(messages.suffix(Self.maxMessages))
        queue.async { [weak self] in self?.store[id] = capped }
    }

    func load(forWorkspaceId id: String) -> [HiveChatMessage] {
        queue.sync { store[id] ?? [] }
    }

    func clear(forWorkspaceId id: String) {
        queue.async { [weak self] in self?.store.removeValue(forKey: id) }
    }
}
