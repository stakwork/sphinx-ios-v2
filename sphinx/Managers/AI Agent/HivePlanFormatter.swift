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

    static func answerResultMessage(_ r: PlannerFormAnswerResult) -> String {
        switch r {
        case .answered: return "Answer sent. The planner will continue."
        case .alreadyAnswered: return "Those questions were already answered."
        case .badRequest: return "Hive rejected the request: a required field was missing."
        case .notFound(let m): return "\(m ?? "Feature or organization not found")."
        case .forbidden: return "This feature does not belong to that organization."
        case .plannerBusy: return "Planner is still running - try again shortly."
        case .failed: return "Failed to send the answer. Nothing was double-sent; it is safe to retry."
        }
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

    /// Picks the org owning `slug`; never guesses.
    static func matchOrg(logins: [String], slugsByLogin: [String: [String]], slug: String) -> String? {
        if logins.count == 1 { return logins[0] }
        return logins.first { slugsByLogin[$0]?.contains(slug) == true }
    }
}
