//
//  HiveChatMessage.swift
//  sphinx
//
//  Created on 2025-02-26.
//  Copyright © 2025 sphinx. All rights reserved.
//

import Foundation
import SwiftyJSON

struct HiveChatMessageCreatedBy {
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

struct PRProgress {
    let state: String?
    let mergeable: Bool?
    let ciStatus: String?
    let ciSummary: String?
}

struct PRContent {
    let repo: String?
    let url: String?
    let status: String?
    let number: Int?
    let title: String?
    let additions: Int?
    let deletions: Int?
    let changedFiles: Int?
    let progress: PRProgress?
}

struct HiveChatMessageArtifact {
    let id: String?
    let type: String?
    /// Plain string content (for CODE, DIFF, etc.)
    let content: String?
    /// Parsed PR content when type == "PULL_REQUEST"
    let prContent: PRContent?

    var isPullRequest: Bool { type == "PULL_REQUEST" }

    init(json: JSON) {
        self.id   = json["id"].string
        self.type = json["type"].string

        if json["type"].string == "PULL_REQUEST" {
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
        } else {
            self.prContent = nil
            self.content = json["content"].string
        }
    }
}

struct HiveChatMessageAttachment {
    let filename: String?
    let path: String?
    let mimeType: String?

    init(json: JSON) {
        self.filename = json["filename"].string
        self.path = json["path"].string
        self.mimeType = json["mimeType"].string
    }
}

struct HiveChatMessage {
    let id: String
    let featureId: String?
    let message: String
    let role: String       // "USER" or "ASSISTANT" (uppercase from API)
    let status: String?
    let userId: String?
    let createdAt: String?
    let artifacts: [HiveChatMessageArtifact]
    let attachments: [HiveChatMessageAttachment]
    let createdBy: HiveChatMessageCreatedBy?
    let replyId: String?

    init?(json: JSON) {
        guard let id = json["id"].string,
              let message = json["message"].string,
              let role = json["role"].string else { return nil }
        self.id = id
        self.featureId = json["featureId"].string
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
}
