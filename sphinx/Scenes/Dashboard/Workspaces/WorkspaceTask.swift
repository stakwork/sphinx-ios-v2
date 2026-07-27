//
//  WorkspaceTask.swift
//  sphinx
//
//  Created on 2025-02-23.
//  Copyright © 2025 sphinx. All rights reserved.
//

import Foundation
import SwiftyJSON

struct WorkspaceTask {
    let id: String
    var title: String
    let description: String?
    var status: String          // "TODO|IN_PROGRESS|DONE|CANCELLED|BLOCKED"
    let priority: String        // "LOW|MEDIUM|HIGH|CRITICAL"
    var workflowStatus: String?
    var archived: Bool
    let sourceType: String?
    let mode: String?
    var podId: String?
    let createdAt: String?
    let updatedAt: String?
    let featureId: String?
    let featureTitle: String?
    let assigneeId: String?
    let assigneeName: String?
    let assigneeEmail: String?
    let assigneeImage: String?
    let repositoryId: String?
    let repositoryName: String?
    let repositoryUrl: String?
    let createdById: String?
    let createdByName: String?
    let createdByEmail: String?
    let createdByImage: String?
    let chatMessageCount: Int
    var prArtifactId: String?
    var prUrl: String?
    var prStatus: String?
    var prNumber: Int?
    var stakworkProjectId: Int?
    var deploymentStatus: String?       // "production" | "staging" | "failed" | nil
    var deployedToProductionAt: String? // ISO 8601
    let systemAssigneeType: String?     // e.g. "TASK_COORDINATOR"
    var autoMerge: Bool
    var runBuild: Bool
    var runTestSuite: Bool
    var dependsOnTaskIds: [String]
    let workflowId: Int?
    let workflowName: String?
    let workflowRefId: String?
    var phaseId: String?           // injected post-init by HivePhase; nil for loose tasks
    var workflowTaskType: String?  // parsed from JSON
    var workflowVersionId: String? // parsed from JSON

    init?(json: JSON) {
        guard let id = json["id"].string,
              let title = json["title"].string else { return nil }
        self.id = id
        self.title = title
        self.description = json["description"].string
        self.status = json["status"].string ?? "TODO"
        self.priority = json["priority"].string ?? "LOW"
        self.workflowStatus = json["workflowStatus"].string
        self.sourceType = json["sourceType"].string
        self.mode = json["mode"].string
        self.createdAt = json["createdAt"].string
        self.updatedAt = json["updatedAt"].string
        self.featureId = json["feature"]["id"].string
        self.featureTitle = json["feature"]["title"].string
        self.assigneeId = json["assignee"]["id"].string
        self.assigneeName = json["assignee"]["name"].string
        self.assigneeEmail = json["assignee"]["email"].string
        self.assigneeImage = json["assignee"]["image"].string
        self.repositoryId = json["repository"]["id"].string
        self.repositoryName = json["repository"]["name"].string
        // Detail endpoint uses "repositoryUrl", workspace tasks endpoint uses "url"
        self.repositoryUrl = json["repository"]["repositoryUrl"].string ?? json["repository"]["url"].string
        self.createdById = json["createdBy"]["id"].string
        self.createdByName = json["createdBy"]["name"].string
        self.createdByEmail = json["createdBy"]["email"].string
        self.createdByImage = json["createdBy"]["image"].string
        self.chatMessageCount = json["chatMessageCount"].int ?? 0
        self.archived = json["archived"].bool ?? false
        self.prArtifactId = json["prArtifact"]["id"].string
        self.prUrl = json["prArtifact"]["content"]["url"].string
        self.prStatus = json["prArtifact"]["content"]["status"].string
        self.prNumber = json["prArtifact"]["content"]["number"].int
        self.stakworkProjectId = json["stakworkProjectId"].int
        self.deploymentStatus = json["deploymentStatus"].string
        self.deployedToProductionAt = json["deployedToProductionAt"].string
        self.systemAssigneeType = json["systemAssigneeType"].string
        self.autoMerge = json["autoMerge"].bool ?? false
        self.runBuild = json["runBuild"].bool ?? true
        self.runTestSuite = json["runTestSuite"].bool ?? true
        self.dependsOnTaskIds = json["dependsOnTaskIds"].arrayValue.compactMap { $0.string }
        self.workflowId = json["workflowId"].int
        self.workflowName = json["workflowName"].string
        self.workflowRefId = json["workflowRefId"].string
        self.workflowTaskType = json["workflowTaskType"].string
        self.workflowVersionId = json["workflowVersionId"].string
        self.phaseId = nil  // populated by HivePhase after init
    }
}
