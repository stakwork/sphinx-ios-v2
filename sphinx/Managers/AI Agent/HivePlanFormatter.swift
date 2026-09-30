//
//  HivePlanFormatter.swift
//  sphinx
//
//  Pure formatting helpers for the Hive plan tools.
//

import Foundation

enum HivePlanFormatter {

    static let notWritten = "(not yet written)"

    private static func section(_ title: String, _ value: String?) -> String {
        let t = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return "## \(title)\n\(t.isEmpty ? notWritten : t)"
    }

    static func formatPlan(_ f: HiveFeature) -> String {
        let items = f.userStoryItems.isEmpty
            ? (f.userStories ?? []).filter { !$0.isEmpty }.map { "- \($0)" }
            : f.userStoryItems.map { "- \($0.completed ? "✓" : "○") \($0.title)" }
        let storiesText = items.isEmpty ? nil : items.joined(separator: "\n")
        let running = f.workflowStatus == "IN_PROGRESS"
        return [
            "Feature: \(f.title)",
            "Status: \(f.status ?? "unknown")",
            "Workflow Status: \(f.workflowStatus ?? "none")",
            running ? "Planner: WORKING (a run is in progress)" : "Planner: idle",
            section("Brief", f.brief),
            section("User Stories", storiesText),
            section("Requirements", f.requirements),
            section("Architecture", f.architecture)
        ].joined(separator: "\n\n")
    }

    static func sendResultMessage(_ r: FeatureChatSendResult) -> String {
        switch r {
        case .sent: return "Message sent to the planner."
        case .plannerBusy(let m):
            let extra = (m?.isEmpty == false) ? " (Hive: \(m!))" : ""
            return "Planner is still running - try again shortly.\(extra)"
        case .notFound: return "Feature not found."
        case .forbidden: return "You don't have access to this feature."
        case .failed: return "Failed to send the message. Nothing was double-sent; it is safe to retry."
        }
    }

    static func answeredPlannerMessageIds(_ messages: [HiveChatMessage]) -> Set<String> {
        var ids = Set<String>()
        for m in messages where m.role == "USER" {
            if let r = m.replyId { ids.insert(r) }
        }
        return ids
    }

    static func isClarifyingPlannerMessage(_ m: HiveChatMessage) -> Bool {
        return m.role == "ASSISTANT" && m.artifacts.contains { $0.isClarifyingQuestions }
    }

    enum PlannerMessageResolution: Equatable {
        /// The message to reply to.
        case target(id: String)
        case alreadyAnswered(id: String)
        /// No PLAN clarifying-questions message is currently open.
        case noOpenQuestions
        /// `plannerMessageId` was given but is not an open-able PLAN question message
        /// in this feature's own chat history (missing, wrong feature, or wrong type).
        case invalidMessageId
    }

    /// Pure. Resolves the target planner message for `answer_planner_form`:
    /// - an explicit `plannerMessageId` must belong to `messages` and carry a PLAN
    ///   clarifying-questions artifact, else `.invalidMessageId`;
    /// - otherwise defaults to the LATEST open (unanswered) clarifying-questions
    ///   message, else `.noOpenQuestions`.
    /// "Answered" uses `answeredPlannerMessageIds` (a later message's `replyId` match) —
    /// the same signal `formatMessage`'s ANSWERED/UNANSWERED tag already relies on.
    static func resolvePlannerMessage(
        messages: [HiveChatMessage],
        plannerMessageId: String?
    ) -> PlannerMessageResolution {
        let answeredIds = answeredPlannerMessageIds(messages)

        if let targetId = plannerMessageId {
            guard let msg = messages.first(where: { $0.id == targetId }),
                  isClarifyingPlannerMessage(msg) else {
                return .invalidMessageId
            }
            if answeredIds.contains(targetId) {
                return .alreadyAnswered(id: targetId)
            }
            return .target(id: targetId)
        }

        for msg in messages.reversed() where isClarifyingPlannerMessage(msg) {
            if !answeredIds.contains(msg.id) {
                return .target(id: msg.id)
            }
        }
        return .noOpenQuestions
    }

    static func formatMessage(_ m: HiveChatMessage, answeredIds: Set<String> = []) -> String {
        let who = m.createdBy?.name ?? (m.role == "USER" ? "User" : "Planner")
        var lines = ["[\(m.createdAt ?? "?")] \(m.role) \(who): \(m.resolvedDisplayText)"]
        for a in m.artifacts {
            if a.isClarifyingQuestions, let qs = a.clarifyingQuestions {
                let state = answeredIds.contains(m.id) ? "ANSWERED" : "UNANSWERED"
                lines.append("  PLAN clarifying questions (plannerMessageId: \(m.id)) - \(state):")
                for (i, q) in qs.enumerated() {
                    lines.append("   \(i + 1). \(q.question) options: \(q.options.joined(separator: " | "))")
                }
            } else if a.type == "PLAN" {
                lines.append("  PLAN update")
            }
        }
        return lines.joined(separator: "\n")
    }

    static func formatHistory(_ messages: [HiveChatMessage], limit: Int = 20) -> String {
        if messages.isEmpty { return "No plan chat messages yet." }
        let answered = answeredPlannerMessageIds(messages)
        return messages.suffix(limit).map { formatMessage($0, answeredIds: answered) }.joined(separator: "\n\n")
    }

    static func openingMessage(title: String, description: String?) -> String {
        if let d = description?.trimmingCharacters(in: .whitespacesAndNewlines), !d.isEmpty {
            return "\(title)\n\n\(d)"
        }
        return title
    }

    static func createFeatureMessage(
        result: CreateFeatureResult, seed: FeatureChatSendResult?, workspace: String
    ) -> String {
        switch result {
        case .failed:
            return "Failed to create the feature in workspace '\(workspace)'."
        case .createdUnparseable:
            return "Hive accepted the feature but didn't return its ID - check the workspace before retrying, so you don't create a duplicate."
        case .created(let f):
            if case .sent = seed {
                return "Feature created (ID: \(f.id)) in workspace '\(workspace)'. The planner has started."
            }
            return "Feature WAS created (ID: \(f.id)) in workspace '\(workspace)', but the first plan message did not go through. Use send_to_planner to retry the message - do not create the feature again."
        }
    }
}
