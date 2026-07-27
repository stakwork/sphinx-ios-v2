//
//  HiveFeatureAttachment.swift
//  sphinx
//
//  Created on 2026-03-18.
//  Copyright © 2026 sphinx. All rights reserved.
//

import Foundation
import SwiftyJSON

struct HiveFeatureAttachment {
    let id: String
    let filename: String?
    let mimeType: String?
    let url: String        // pre-signed S3 URL — no second presign needed
    let taskId: String
    let taskTitle: String
    let createdAt: String?

    init?(json: JSON) {
        guard let id = json["id"].string,
              let url = json["url"].string,
              let taskId = json["taskId"].string else { return nil }
        self.id = id
        self.filename = json["filename"].string
        self.mimeType = json["mimeType"].string
        self.url = url
        self.taskId = taskId
        self.taskTitle = json["taskTitle"].string ?? ""
        self.createdAt = json["createdAt"].string
    }

    /// Bridge to `HiveChatMessageAttachment` for use with `AttachmentGridView`.
    func toChatAttachment() -> HiveChatMessageAttachment {
        return HiveChatMessageAttachment(
            presignedUrl: url,
            mimeType: mimeType,
            filename: filename
        )
    }
}
