//
//  HiveChatMessage.swift
//  sphinx
//
//  Created on 2025-02-26.
//  Copyright © 2025 sphinx. All rights reserved.
//

import Foundation
import SwiftyJSON

struct HiveChatMessageCreatedBy: Sendable {
    let id: String
    let name: String?
    let email: String?
    let image: String?

    init?(json: JSON) {
        guard let id = json["id"].string else { return nil }
        self.id = id
        self.name = json["name"].string
        self.email = json["email"].string
        self.image = json["image"].string
    }
}

struct PRProgress: @unchecked Sendable {
    let state: String?
    let mergeable: Bool?
    let ciStatus: String?
    let ciSummary: String?
}

struct PRContent: Sendable {
    let repo: String?
    var url: String?
    var status: String?
    let number: Int?
    let title: String?
    let additions: Int?
    let deletions: Int?
    let changedFiles: Int?
    let progress: PRProgress?
    var state: String?
}

struct LongformContent: Sendable {
    let title: String?
    let text: String?
}

struct ClarifyingQuestion: Sendable {
    let question: String
    let options: [String]
    let type: String // "single_choice" or "multiple_choice"
}

// MARK: - Stream Artifact Info

struct StreamArtifactInfo: Sendable {
    let requestId: String
    let eventsToken: String
    let baseUrl: String
}

// MARK: - Workflow Content

struct WorkflowContent: Sendable {
    let workflowId: Int?
    let workflowName: String?
    let workflowRefId: String?
    let workflowVersionId: String?
    let projectId: String?       // covers both projectId and debuggerProjectId
    let webhook: String?
    let workflowJson: String?
}

struct HiveChatMessageArtifact: @unchecked Sendable {
    let id: String?
    let type: String?
    /// Plain string content (for CODE, DIFF, etc.)
    let content: String?
    /// Parsed PR content when type == "PULL_REQUEST"
    var prContent: PRContent?
    /// Parsed longform content when type == "LONGFORM"
    let longformContent: LongformContent?
    /// Raw JSON content for PLAN artifacts
    let contentJSON: JSON?
    /// Parsed clarifying questions when type == "PLAN" and tool_use == "ask_clarifying_questions"
    let clarifyingQuestions: [ClarifyingQuestion]?
    /// Parsed stream info when type == "STREAM"
    let streamInfo: StreamArtifactInfo?
    /// Parsed workflow content when type == "WORKFLOW"
    let workflowContent: WorkflowContent?

    var isPullRequest: Bool { type == "PULL_REQUEST" }
    var isLongform: Bool { type == "LONGFORM" }
    var isStream: Bool { type == "STREAM" }
    var isWorkflow: Bool { type == "WORKFLOW" }

    var isClarifyingQuestions: Bool {
        return type == "PLAN" && contentJSON?["tool_use"].string == "ask_clarifying_questions"
    }

    init(json: JSON) {
        self.id   = json["id"].string
        self.type = json["type"].string

        if json["type"].string == "STREAM" {
            self.prContent = nil
            self.content = nil
            self.longformContent = nil
            self.contentJSON = nil
            self.clarifyingQuestions = nil
            self.workflowContent = nil
            // Content may be a JSON object or a JSON string that needs decoding
            let rawContent = json["content"]
            let contentJSON: JSON
            if rawContent.type == .string,
               let str = rawContent.string,
               let data = str.data(using: .utf8),
               let parsed = try? JSON(data: data) {
                contentJSON = parsed
            } else {
                contentJSON = rawContent
            }
            if let requestId = contentJSON["requestId"].string,
               let eventsToken = contentJSON["eventsToken"].string,
               let baseUrl = contentJSON["baseUrl"].string {
                self.streamInfo = StreamArtifactInfo(
                    requestId: requestId,
                    eventsToken: eventsToken,
                    baseUrl: baseUrl
                )
            } else {
                self.streamInfo = nil
            }
        } else if json["type"].string == "PULL_REQUEST" {
            let c = json["content"]
            let progress = c["progress"]
            self.prContent = PRContent(
                repo:         c["repo"].string,
                url:          c["url"].string,
                status:       c["status"].string,
                number:       c["number"].int,
                title:        c["title"].string,
                additions:    c["additions"].int,
                deletions:    c["deletions"].int,
                changedFiles: c["changedFiles"].int,
                progress: PRProgress(
                    state:      progress["state"].string,
                    mergeable:  progress["mergeable"].bool,
                    ciStatus:   progress["ciStatus"].string,
                    ciSummary:  progress["ciSummary"].string
                )
            )
            self.content = nil
            self.longformContent = nil
            self.contentJSON = nil
            self.clarifyingQuestions = nil
            self.streamInfo = nil
            self.workflowContent = nil
        } else if json["type"].string == "LONGFORM" {
            let c = json["content"]
            self.longformContent = LongformContent(title: c["title"].string, text: c["text"].string)
            self.content = nil
            self.prContent = nil
            self.contentJSON = nil
            self.clarifyingQuestions = nil
            self.streamInfo = nil
            self.workflowContent = nil
        } else if json["type"].string == "PLAN" {
            self.prContent = nil
            self.content = nil
            self.longformContent = nil
            let planContent = json["content"]
            self.contentJSON = planContent
            if planContent["tool_use"].string == "ask_clarifying_questions" {
                self.clarifyingQuestions = planContent["content"].arrayValue.compactMap { item in
                    guard let question = item["question"].string,
                          let type = item["type"].string else { return nil }
                    let options = item["options"].arrayValue.compactMap { $0.string }
                    return ClarifyingQuestion(question: question, options: options, type: type)
                }
            } else {
                self.clarifyingQuestions = nil
            }
            self.streamInfo = nil
            self.workflowContent = nil
        } else if json["type"].string == "WORKFLOW" {
            let c = json["content"]
            self.workflowContent = WorkflowContent(
                workflowId:        c["workflowId"].int,
                workflowName:      c["workflowName"].string,
                workflowRefId:     c["workflowRefId"].string,
                workflowVersionId: c["workflowVersionId"].string,
                projectId:         c["projectId"].string ?? c["debuggerProjectId"].string,
                webhook:           c["webhook"].string,
                workflowJson:      c["workflowJson"].string
            )
            self.content = nil
            self.prContent = nil
            self.longformContent = nil
            self.contentJSON = nil
            self.clarifyingQuestions = nil
            self.streamInfo = nil
        } else {
            self.prContent = nil
            self.contentJSON = nil
            self.clarifyingQuestions = nil
            self.longformContent = nil
            self.content = json["content"].string
            self.streamInfo = nil
            self.workflowContent = nil
        }
    }
}

struct HiveChatMessageAttachment: Sendable {
    let filename: String?
    let path: String?
    let url: String?
    let mimeType: String?
    /// When `true` the `url` is already a pre-signed S3 URL and should be used directly
    /// without an additional presign round-trip.
    let isPresigned: Bool

    init(json: JSON) {
        self.filename = json["filename"].string
        self.path = json["path"].string
        self.url = json["url"].string
        self.mimeType = json["mimeType"].string
        self.isPresigned = false
    }

    /// Convenience init for pre-signed URLs (e.g. from the /attachments endpoint).
    init(presignedUrl: String, mimeType: String?, filename: String? = nil) {
        self.url = presignedUrl
        self.mimeType = mimeType
        self.filename = filename
        self.path = nil
        self.isPresigned = true
    }

    var resolvedUrl: String? { url ?? path }
}

struct HiveChatMessage: @unchecked Sendable {
    let id: String
    let featureId: String?
    let taskId: String?
    var message: String
    let role: String       // "USER" or "ASSISTANT" (uppercase from API)
    let status: String?
    let userId: String?
    let createdAt: String?
    var artifacts: [HiveChatMessageArtifact]
    let attachments: [HiveChatMessageAttachment]
    let createdBy: HiveChatMessageCreatedBy?
    let replyId: String?

    /// Memberwise initialiser for programmatic construction (e.g. Graph Chat streaming).
    init(
        id: String,
        message: String,
        role: String,
        featureId: String? = nil,
        taskId: String? = nil,
        status: String? = nil,
        userId: String? = nil,
        createdAt: String? = nil,
        artifacts: [HiveChatMessageArtifact] = [],
        attachments: [HiveChatMessageAttachment] = [],
        createdBy: HiveChatMessageCreatedBy? = nil,
        replyId: String? = nil
    ) {
        self.id = id
        self.message = message
        self.role = role
        self.featureId = featureId
        self.taskId = taskId
        self.status = status
        self.userId = userId
        self.createdAt = createdAt
        self.artifacts = artifacts
        self.attachments = attachments
        self.createdBy = createdBy
        self.replyId = replyId
    }

    init?(json: JSON) {
        guard let id = json["id"].string,
              let message = json["message"].string,
              let role = json["role"].string else { return nil }
        self.id = id
        self.featureId = json["featureId"].string
        self.taskId = json["taskId"].string
        self.message = message
        self.role = role
        self.status = json["status"].string
        self.userId = json["userId"].string
        self.createdAt = json["createdAt"].string
        self.artifacts = (json["artifacts"].array ?? []).map { HiveChatMessageArtifact(json: $0) }
        self.attachments = (json["attachments"].array ?? []).map { HiveChatMessageAttachment(json: $0) }
        self.createdBy = HiveChatMessageCreatedBy(json: json["createdBy"])
        self.replyId = json["replyId"].string
    }

    /// Returns true if the message was sent by the user (role == "USER")
    var isUserMessage: Bool {
        return role.uppercased() == "USER"
    }

    /// Returns `message` if non-empty; otherwise composes text from the first LONGFORM artifact.
    var resolvedDisplayText: String {
        if !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return message
        }
        if let lf = artifacts.first(where: { $0.isLongform })?.longformContent {
            let title = lf.title ?? ""
            let text  = lf.text  ?? ""
            return title.isEmpty ? text : "**\(title)**\n\n\(text)"
        }
        return message
    }

    /// Returns true when the message text is empty and a LONGFORM artifact carries the content.
    var isLongformMessage: Bool {
        return message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && artifacts.contains(where: { $0.isLongform })
    }

    /// True when the full message content is a logs block.
    var isLogsMessage: Bool {
        let t = resolvedDisplayText.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.hasPrefix("<logs>") && t.hasSuffix("</logs>")
    }

    /// Extracts the raw content between <logs>…</logs> tags.
    var logsContent: String? {
        guard isLogsMessage else { return nil }
        let t = resolvedDisplayText.trimmingCharacters(in: .whitespacesAndNewlines)
        let inner = t.dropFirst("<logs>".count).dropLast("</logs>".count)
        return String(inner)
    }

    // MARK: - Pre-computed render cache (populated off the main thread)

    /// Cached result of `MarkdownContentSplitter.split(resolvedDisplayText)`.
    /// `nil` means the cache has not been populated yet — callers must fall back to computing inline.
    var cachedSegments: [MessageContentSegment]? = nil

    /// One `[CGFloat]` per `.table` segment in `cachedSegments`, in document order.
    /// `nil` means column widths have not been pre-measured yet.
    var cachedColumnWidths: [[CGFloat]]? = nil

    /// Pre-rendered `NSAttributedString` for each segment in `cachedSegments`.
    /// Index is parallel to `cachedSegments`: non-nil for `.text` segments, nil for `.table` segments.
    /// `nil` outer optional means the cache has not been populated yet.
    var cachedRenderedText: [NSAttributedString?]? = nil

    /// Pre-computed estimated row height for `UITableView.estimatedHeightForRowAt`.
    /// Populated by `precompute()` on the background thread so the table view never
    /// has to measure a cell to produce an estimate.
    var estimatedCellHeight: CGFloat? = nil

    /// Returns true when this message should be shown in the chat table.
    /// Mirrors the filter applied by `displayMessages` in all chat view controllers.
    var isDisplayable: Bool {
        !message.isEmpty ||
        !attachments.isEmpty ||
        artifacts.contains(where: { $0.type != "STREAM" && $0.type != "WORKFLOW" })
    }
}
