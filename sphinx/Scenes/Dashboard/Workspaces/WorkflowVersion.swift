//
//  WorkflowVersion.swift
//  sphinx
//
//  Copyright © 2025 sphinx. All rights reserved.
//

import Foundation
import SwiftyJSON

struct WorkflowVersion: Sendable {
    let versionId: String       // workflow_version_id (full UUID string)
    let workflowId: Int
    let workflowName: String?
    let refId: String?          // ref_id (graph node ref)
    let published: Bool
    let workflowJson: String?
    let dateAddedToGraph: Date?

    init?(json: JSON) {
        guard let versionId = json["workflow_version_id"].string,
              let workflowId = json["workflow_id"].int else { return nil }
        self.versionId = versionId
        self.workflowId = workflowId
        self.workflowName = json["workflow_name"].string
        self.refId = json["ref_id"].string
        self.published = json["published"].bool ?? false
        self.workflowJson = json["workflow_json"].string
        if let dateStr = json["date_added_to_graph"].string {
            let formatter = ISO8601DateFormatter()
            self.dateAddedToGraph = formatter.date(from: dateStr)
        } else {
            self.dateAddedToGraph = nil
        }
    }
}
