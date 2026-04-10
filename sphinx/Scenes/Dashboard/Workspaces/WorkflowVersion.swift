//
//  WorkflowVersion.swift
//  sphinx
//
//  Copyright © 2025 sphinx. All rights reserved.
//

import Foundation
import SwiftyJSON

struct WorkflowVersion: Sendable {
    let versionId: Int          // workflow_version_id (numeric)
    let workflowId: Int
    let workflowName: String?
    let refId: String?          // ref_id (graph node ref)
    let workflowVersionId: String? // full UUID string
    let published: Bool

    init?(json: JSON) {
        guard let versionId = json["workflow_version_id"].int,
              let workflowId = json["workflow_id"].int else { return nil }
        self.versionId = versionId
        self.workflowId = workflowId
        self.workflowName = json["workflow_name"].string
        self.refId = json["ref_id"].string
        self.workflowVersionId = json["ref_id"].string
        self.published = json["published"].bool ?? false
    }
}
