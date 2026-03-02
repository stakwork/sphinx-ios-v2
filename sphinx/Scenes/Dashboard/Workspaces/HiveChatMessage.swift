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

struct HiveChatMessageArtifact {
    let type: String?
    let content: String?

    init(json: JSON) {
        self.type = json["type"].string
        self.content = json["content"].string
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
