//
//  AIAgentThreadingRules.swift
//  sphinx
//
//  Pure, Core-Data-free rules for making the Sphinx Agent thread- and
//  reply-aware. `AIAgentManager` maps `TransactionMessage` / `Chat` into the
//  plain value types below at the call site, so these functions can be
//  unit-tested without a Core Data stack.
//

import Foundation

// MARK: - Value types

/// A Core-Data-free snapshot of the fields of a `TransactionMessage` needed
/// to reason about threading/reply rules.
struct AgentMessageRef: Sendable, Equatable {
    let uuid: String?
    let threadUUID: String?
    let replyUUID: String?
    let chatId: Int?
    let isDeleted: Bool

    init(
        uuid: String?,
        threadUUID: String?,
        replyUUID: String?,
        chatId: Int?,
        isDeleted: Bool = false
    ) {
        self.uuid = uuid
        self.threadUUID = threadUUID
        self.replyUUID = replyUUID
        self.chatId = chatId
        self.isDeleted = isDeleted
    }
}

/// A minimal row used for grouping messages into threads (`groupThreads`).
struct AgentThreadRow: Sendable, Equatable {
    let uuid: String?
    let threadUUID: String?
    let date: Date
}

/// Result of a validation rule: either acceptable, or a refusal with a
/// human-readable reason that is safe to surface to the model/user.
enum ValidationResult: Sendable, Equatable {
    case ok
    case refused(reason: String)

    var isOK: Bool {
        if case .ok = self { return true }
        return false
    }
}

enum AIAgentThreadingRules {

    // MARK: - Wire values

    /// Works out the wire `threadUUID` / `replyUUID` pair to send, using the
    /// exact same rules as the app's own composer
    /// (`NewChatViewModel+SendMessageExtension`):
    ///
    ///   tuuid = threadUUID ?? replyingTo?.threadUUID ?? replyingTo?.replyUUID ?? replyingTo?.uuid
    ///   send(threadUUID: tuuid, replyUUID: replyingTo?.uuid)
    ///
    /// Cases:
    ///   - A (no thread, no reply): `(nil, nil)`.
    ///   - E (thread only, no reply): `(threadUUID, nil)`.
    ///   - B/D (reply to R, with or without an explicit thread): the formula
    ///     above, falling back through R's threadUUID, then replyUUID
    ///     (for older messages that only carry a flat replyUUID), then R's
    ///     own uuid.
    ///
    /// NOTE: In a 1:1 chat a reply still produces a non-nil wire thread
    /// (case B) — this is intentional and matches the composer's behaviour;
    /// it is not specific to tribes.
    static func wireValues(
        threadUUID: String?,
        replyTo: AgentMessageRef?
    ) -> (thread: String?, reply: String?) {
        guard let replyTo = replyTo else {
            // Case A (nil/nil) or Case E (thread/nil)
            return (threadUUID, nil)
        }
        // Cases B/D
        let tuuid = threadUUID ?? replyTo.threadUUID ?? replyTo.replyUUID ?? replyTo.uuid
        return (tuuid, replyTo.uuid)
    }

    // MARK: - Validation

    /// Validates that `ref` is a legitimate target to reply to.
    /// Refuses when: not found, uuid is nil (not yet confirmed), deleted,
    /// or belongs to a different chat.
    ///
    /// IDOR guard: a missing/unresolved `chatId` on the looked-up message is
    /// treated as a refusal (fail closed), never as an implicit pass — a
    /// caller-supplied uuid must be provably owned by the target chat before
    /// it can be used as a reply target.
    static func validateReplyTarget(
        _ ref: AgentMessageRef?,
        chatId: Int
    ) -> ValidationResult {
        guard let ref = ref else {
            return .refused(reason: "message not found")
        }
        guard let uuid = ref.uuid, !uuid.isEmpty else {
            return .refused(reason: "message is not yet confirmed (no uuid), nothing to reply to")
        }
        if ref.isDeleted {
            return .refused(reason: "message has been deleted")
        }
        guard let refChatId = ref.chatId, refChatId == chatId else {
            return .refused(reason: "message is not in this chat")
        }
        return .ok
    }

    /// Validates that `ref` is a legitimate thread root. Refuses when: the
    /// chat isn't a tribe, not found/deleted, in another chat, or the
    /// message is itself a member of another thread (so it can't be a root).
    ///
    /// NOTE: reply count is intentionally NOT checked here — posting into a
    /// root that currently has 0 or 1 replies is valid; the post itself
    /// creates or completes the thread.
    ///
    /// IDOR guard: a missing/unresolved `chatId` on the looked-up message is
    /// treated as a refusal (fail closed), never as an implicit pass — a
    /// caller-supplied uuid must be provably owned by the target chat before
    /// it can be used as a thread root.
    static func validateThreadRoot(
        _ ref: AgentMessageRef?,
        chatId: Int,
        isTribe: Bool
    ) -> ValidationResult {
        guard isTribe else {
            return .refused(reason: "threads are only available in tribes, not 1:1 chats")
        }
        guard let ref = ref else {
            return .refused(reason: "thread root message not found")
        }
        if ref.isDeleted {
            return .refused(reason: "thread root message has been deleted")
        }
        guard let refChatId = ref.chatId, refChatId == chatId else {
            return .refused(reason: "thread root message is not in this chat")
        }
        if let threadUUID = ref.threadUUID, threadUUID != ref.uuid {
            return .refused(reason: "message is itself part of another thread, so it cannot be used as a thread root")
        }
        return .ok
    }

    /// When both a thread and a reply target are given, requires that the
    /// reply target actually belongs to that thread: either it IS the root
    /// (`R.uuid == threadUUID`) or it's already a member (`R.threadUUID ==
    /// threadUUID`). Prevents sending into thread T a message that quotes a
    /// message belonging to a different thread.
    static func validateThreadReplyConsistency(
        threadUUID: String,
        replyTo: AgentMessageRef?
    ) -> ValidationResult {
        guard let replyTo = replyTo else {
            return .refused(reason: "reply target not found")
        }
        if replyTo.uuid == threadUUID || replyTo.threadUUID == threadUUID {
            return .ok
        }
        return .refused(reason: "reply target does not belong to the given thread")
    }

    // MARK: - Thread root marking

    /// Returns the set of root uuids that have 2 or more messages pointing
    /// at them (the same threshold used by `ThreadsListDataSource.processThreadMessages`,
    /// which requires `threadMessageMap.1.count > 1`; the root itself is not
    /// counted). Threads only exist in tribes — returns an empty set when
    /// `!isTribe`, matching `TransactionMessage.getThreadMessagesFor`, which
    /// returns `[:]` for non-public-group chats.
    static func threadRootUUIDs(
        replies: [AgentMessageRef],
        isTribe: Bool
    ) -> Set<String> {
        guard isTribe else { return [] }
        var counts: [String: Int] = [:]
        for ref in replies {
            guard let threadUUID = ref.threadUUID else { continue }
            counts[threadUUID, default: 0] += 1
        }
        return Set(counts.filter { $0.value >= 2 }.keys)
    }

    // MARK: - Grouping threads

    /// Groups `rows` by `threadUUID`, keeps only groups with 2 or more
    /// replies, and sorts by the latest reply date, newest first. Mirrors
    /// `processThreadMessages` / `getThreadMessagesFrom`.
    static func groupThreads(
        rows: [AgentThreadRow]
    ) -> [(rootUUID: String, replyCount: Int, lastActivity: Date)] {
        var groups: [String: (count: Int, lastActivity: Date)] = [:]
        for row in rows {
            guard let threadUUID = row.threadUUID else { continue }
            if var existing = groups[threadUUID] {
                existing.count += 1
                if row.date > existing.lastActivity {
                    existing.lastActivity = row.date
                }
                groups[threadUUID] = existing
            } else {
                groups[threadUUID] = (count: 1, lastActivity: row.date)
            }
        }
        let filtered = groups.filter { $0.value.count >= 2 }
        return filtered
            .map { (rootUUID: $0.key, replyCount: $0.value.count, lastActivity: $0.value.lastActivity) }
            .sorted { $0.lastActivity > $1.lastActivity }
    }

    // MARK: - Line formatting

    /// Builds a single output line in the shape:
    /// `[sender] date (uuid=… thread=… reply=… [THREAD ROOT, n replies] [IN THREAD]): content`
    ///
    /// - `uuid=pending` is shown when `ref.uuid` is nil.
    /// - `[THREAD ROOT, n replies]` is appended when `rootReplyCount` (>= 2) is provided.
    /// - `[IN THREAD]` is appended when `isInThread` is true (a tribe message whose
    ///   threadUUID points to a root with 2+ replies — these are hidden from the main chat).
    /// - Sender rules: "Me" for the owner; the resolved 1:1 contact display name
    ///   (never the raw query the model typed) in 1:1 chats; `senderAlias ?? "Unknown"`
    ///   in tribes (never the tribe name).
    static func formatLine(
        ref: AgentMessageRef,
        isOwner: Bool,
        isTribe: Bool,
        senderAlias: String?,
        resolvedContactName: String?,
        date: Date?,
        content: String,
        rootReplyCount: Int? = nil,
        isInThread: Bool = false,
        isoFormatter: ISO8601DateFormatter = ISO8601DateFormatter()
    ) -> String {
        let sender: String
        if isOwner {
            sender = "Me"
        } else if isTribe {
            sender = senderAlias ?? "Unknown"
        } else {
            sender = resolvedContactName ?? "Unknown"
        }

        let dateStr = date.map { isoFormatter.string(from: $0) } ?? "unknown date"
        let uuidStr = ref.uuid ?? "pending"

        var meta = "uuid=\(uuidStr)"
        if let threadUUID = ref.threadUUID {
            meta += " thread=\(threadUUID)"
        }
        if let replyUUID = ref.replyUUID {
            meta += " reply=\(replyUUID)"
        }
        if let rootReplyCount = rootReplyCount, rootReplyCount >= 2 {
            meta += " [THREAD ROOT, \(rootReplyCount) replies]"
        }
        if isInThread {
            meta += " [IN THREAD]"
        }

        return "[\(sender)] \(dateStr) (\(meta)): \(content)"
    }
}
