//
//  AIAgentManager+HiveConversation.swift
//  sphinx
//
//  Per-org "start a new Jamie conversation" decision logic. A reset can be
//  requested by the model (query_hive_graph's `new_conversation` flag) or
//  triggered automatically after a period of inactivity. Either kind of
//  reset is blocked while a proposal in that org is still awaiting approval
//  or rejection, so approve/reject never lose their conversation context.
//
//  Every helper here either takes `AIAgentManager.withHiveCacheLock` itself
//  (the public entry points) or explicitly documents that it assumes the
//  caller already holds it (the `...Locked` helpers). `withHiveCacheLock`
//  wraps a plain `DispatchQueue.sync` and is NOT re-entrant — nesting two
//  calls on the same thread deadlocks. `...Locked` helpers must therefore
//  never call `withHiveCacheLock` (or any public wrapper that does).
//
//  Copyright © 2026 sphinx. All rights reserved.
//

import Foundation

extension AIAgentManager {

    /// After this much inactivity on an org's Jamie conversation, the next
    /// question to that org starts a new conversation automatically (the
    /// "idle backstop"). Same pending-proposal guard as a model-requested reset.
    static let hiveConversationIdleTimeout: TimeInterval = 30 * 60

    /// Tool names the SSE stream captures as proposals. Mirrors the sets
    /// already used throughout AIAgentManager+HiveGraphTool.swift — kept as
    /// its own constant here so this file doesn't need to reach into that
    /// extension's local `let`s.
    private static let hiveProposalToolNames: Set<String> = [
        "propose_feature", "propose_initiative", "propose_milestone"
    ]

    // MARK: - Decision

    /// Outcome of `conversationIdForQuery` for a single query_hive_graph call.
    struct HiveConversationDecision: Sendable {
        let requestedNew: Bool
        let idleExpired: Bool
        let blockedByProposal: Bool
        let outcome: Outcome

        enum Outcome: String, Sendable, Equatable {
            case continued
            case reset
        }
    }

    // MARK: - Pending Proposal Guard

    /// True if `orgId` currently has a proposal awaiting approval or rejection —
    /// either the single `hivePendingProposal` slot, or an unactioned
    /// `propose_*` tool call sitting in this org's own canvas history (whose
    /// message has no `approvalResult` yet).
    ///
    /// Checking canvas history too (not just the pending slot) closes a gap:
    /// the pending slot holds only one proposal at a time, so org B's proposal
    /// can replace org A's in that slot while A's card is still shown and
    /// still actionable from A's own canvas history. Without this check, a
    /// reset for org A would go through even though approving A's still-visible
    /// card needs A's conversation id to remain intact.
    ///
    /// Caller MUST already hold `withHiveCacheLock` — this never takes the
    /// lock itself, so it's safe to call from inside another locked block
    /// (e.g. `fetchAndCacheOrgSlugs`'s existing lock).
    ///
    /// KNOWN LIMIT: a proposal card that is never approved or rejected pins
    /// this org's conversation indefinitely — both the `new_conversation` flag
    /// and the idle backstop are ignored for it until the card is actioned.
    /// This mirrors the pinning that workspace-change clearing in
    /// `fetchAndCacheOrgSlugs` already has today.
    static func hasUnactionedProposalLocked(orgId: String) -> Bool {
        if let data: Data = UserDefaults.Keys.hivePendingProposal.get(),
           let proposal = try? JSONDecoder().decode(PendingProposal.self, from: data),
           proposal.orgId == orgId {
            return true
        }

        // Read canvas history directly rather than via `canvasHistory(orgId:)` —
        // that helper takes `withHiveCacheLock` itself, which would deadlock here.
        guard let data: Data = UserDefaults.Keys.hiveCanvasChatHistoryByOrg.get(),
              let dict = try? JSONDecoder().decode([String: [CanvasChatMessage]].self, from: data),
              let history = dict[orgId]
        else { return false }

        return history.contains { message in
            message.approvalResult == nil &&
            (message.toolCalls?.contains { hiveProposalToolNames.contains($0.toolName) } == true)
        }
    }

    /// Thin, lock-taking wrapper around `hasUnactionedProposalLocked`. Use this
    /// from call sites that don't already hold `withHiveCacheLock`.
    static func hasUnactionedProposal(orgId: String) -> Bool {
        withHiveCacheLock { hasUnactionedProposalLocked(orgId: orgId) }
    }

    // MARK: - Conversation Reset Decision

    /// Decides whether `orgId`'s next Jamie question continues the stored
    /// conversation or starts a new one, and performs the reset (removing only
    /// that org's stored id) when it does. Runs entirely inside one lock
    /// acquisition and calls only `...Locked` helpers — safe to call from a
    /// context that does not already hold the lock.
    ///
    /// - `idleExpired` is true when there's a timestamp older than
    ///   `hiveConversationIdleTimeout`, OR when there's no timestamp at all but
    ///   a conversation id is already stored (retires long-lived threads that
    ///   predate the idle backstop, on their first use after upgrade). No id
    ///   and no timestamp is a true no-op — nothing to reset.
    /// - A reset is skipped (`blockedByProposal`) while `orgId` has an
    ///   unactioned proposal, even if `requestNew` or `idleExpired` would
    ///   otherwise trigger one.
    static func conversationIdForQuery(
        orgId: String, requestNew: Bool, now: Date
    ) -> (id: String?, decision: HiveConversationDecision) {
        withHiveCacheLock {
            let blocked = hasUnactionedProposalLocked(orgId: orgId)

            let storedId: String? = {
                guard let data: Data = UserDefaults.Keys.hiveConversationIdByOrg.get(),
                      let dict = try? JSONDecoder().decode([String: String].self, from: data)
                else { return nil }
                return dict[orgId]
            }()

            let lastQueryAt: Double? = {
                guard let data: Data = UserDefaults.Keys.hiveLastQueryAtByOrg.get(),
                      let dict = try? JSONDecoder().decode([String: Double].self, from: data)
                else { return nil }
                return dict[orgId]
            }()

            let idleExpired: Bool
            if let last = lastQueryAt {
                idleExpired = now.timeIntervalSince1970 - last > hiveConversationIdleTimeout
            } else {
                idleExpired = storedId != nil
            }

            guard (requestNew || idleExpired) && !blocked else {
                let decision = HiveConversationDecision(
                    requestedNew: requestNew, idleExpired: idleExpired,
                    blockedByProposal: blocked, outcome: .continued
                )
                return (storedId, decision)
            }

            // Reset: remove only this org's entry.
            if let data: Data = UserDefaults.Keys.hiveConversationIdByOrg.get(),
               var dict = try? JSONDecoder().decode([String: String].self, from: data) {
                dict.removeValue(forKey: orgId)
                if let encoded = try? JSONEncoder().encode(dict) {
                    UserDefaults.Keys.hiveConversationIdByOrg.set(encoded)
                }
            }

            let decision = HiveConversationDecision(
                requestedNew: requestNew, idleExpired: idleExpired,
                blockedByProposal: blocked, outcome: .reset
            )
            return (nil, decision)
        }
    }

    // MARK: - Compare-and-Set Conversation Id Write

    /// Writes `dict[orgId] = newId` only if the current value is still
    /// `startedWith` (the id this stream started with) or already equals
    /// `newId`. Otherwise the write is skipped and logged.
    ///
    /// This stops two races:
    /// - A continuing stream that started with the old id finishing late and
    ///   overwriting an id a parallel reset-stream already stored.
    /// - A late response bringing back an id that a reset already cleared.
    ///
    /// When two parallel streams for the same org both start with `nil`
    /// (e.g. two reset calls racing), the first write wins and the second
    /// Hive thread is simply abandoned — an accepted, documented outcome.
    @discardableResult
    static func storeConversationId(orgId: String, newId: String, startedWith: String?) -> Bool {
        withHiveCacheLock {
            var dict: [String: String] = [:]
            if let data: Data = UserDefaults.Keys.hiveConversationIdByOrg.get(),
               let existing = try? JSONDecoder().decode([String: String].self, from: data) {
                dict = existing
            }
            let current = dict[orgId]
            guard current == startedWith || current == newId else {
                print("AIAgent [HiveConversation] staleConversationIdIgnored org=\(orgId)")
                return false
            }
            dict[orgId] = newId
            if let encoded = try? JSONEncoder().encode(dict) {
                UserDefaults.Keys.hiveConversationIdByOrg.set(encoded)
            }
            return true
        }
    }

    // MARK: - Activity Timestamp

    /// Records that `orgId` had a successful Jamie turn at `date`. Call this
    /// ONLY after a turn that completed without `onError` and produced either
    /// a conversation id or a non-empty result — token/slug failures and
    /// errored streams never reached Hive, so they don't count as activity.
    static func recordHiveQuery(orgId: String, at date: Date) {
        withHiveCacheLock {
            var dict: [String: Double] = [:]
            if let data: Data = UserDefaults.Keys.hiveLastQueryAtByOrg.get(),
               let existing = try? JSONDecoder().decode([String: Double].self, from: data) {
                dict = existing
            }
            dict[orgId] = date.timeIntervalSince1970
            if let encoded = try? JSONEncoder().encode(dict) {
                UserDefaults.Keys.hiveLastQueryAtByOrg.set(encoded)
            }
        }
    }
}
