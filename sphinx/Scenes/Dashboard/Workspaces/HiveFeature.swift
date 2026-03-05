//
//  HiveFeature.swift
//  sphinx
//
//  Created on 2025-02-26.
//  Copyright © 2025 sphinx. All rights reserved.
//

import Foundation
import SwiftyJSON

struct HiveAssignee {
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

/// A phase groups tasks together under a named milestone.
struct HivePhase {
    let id: String
    let name: String
    let order: Int
    let tasks: [WorkspaceTask]

    init?(json: JSON) {
        guard let id = json["id"].string else { return nil }
        self.id = id
        self.name = json["name"].string ?? ""
        self.order = json["order"].int ?? 0
        self.tasks = json["tasks"].arrayValue.compactMap { WorkspaceTask(json: $0) }
    }
}

struct HiveFeature {
    let id: String
    var title: String
    let description: String?
    let brief: String?
    let userStories: [String]?  // Can be array or string
    let requirements: String?
    let architecture: String?
    let status: String?
    let workflowStatus: String?
    let priority: String?
    let createdAt: String?
    let updatedAt: String?
    let assignee: HiveAssignee?
    let createdBy: HiveAssignee?
    let deploymentStatus: String?
    let deploymentUrl: String?
    let userStoriesCount: Int?
    let stakworkRunsCount: Int?

    /// Phases with their tasks (from the detail endpoint)
    let phases: [HivePhase]
    /// Top-level tasks not assigned to any phase (from the detail endpoint)
    let looseTasks: [WorkspaceTask]

    /// Flattened list of all tasks across phases + loose tasks, sorted by phase order then task order.
    var allTasks: [WorkspaceTask] {
        let phaseTasks = phases.sorted { $0.order < $1.order }.flatMap { $0.tasks }
        return phaseTasks + looseTasks
    }

    var hasTasks: Bool { !allTasks.isEmpty }
    
    // Computed property to get name (backwards compatibility)
    var name: String { return title }
    
    init?(json: JSON) {
        guard let id = json["id"].string,
              let title = json["title"].string else { return nil }
        self.id = id
        self.title = title
        self.description = json["description"].string
        self.brief = json["brief"].string
        
        // Parse userStories — may be:
        //   - Array of objects: [{ id, title, order, completed }]  (detail endpoint)
        //   - Array of strings                                      (older format)
        //   - A single string
        if let storiesArray = json["userStories"].array {
            let titles = storiesArray.compactMap { item -> String? in
                if let title = item["title"].string { return title }
                return item.string
            }
            self.userStories = titles.isEmpty ? nil : titles
        } else if let storiesString = json["userStories"].string {
            self.userStories = [storiesString]
        } else {
            self.userStories = nil
        }
        
        self.requirements = json["requirements"].string
        self.architecture = json["architecture"].string
        self.status = json["status"].string
        self.workflowStatus = json["workflowStatus"].string
        self.priority = json["priority"].string
        self.createdAt = json["createdAt"].string
        self.updatedAt = json["updatedAt"].string
        self.assignee = HiveAssignee(json: json["assignee"])
        self.createdBy = HiveAssignee(json: json["createdBy"])
        self.deploymentStatus = json["deploymentStatus"].string
        self.deploymentUrl = json["deploymentUrl"].string
        
        // Parse _count object
        self.userStoriesCount = json["_count"]["userStories"].int
        self.stakworkRunsCount = json["_count"]["stakworkRuns"].int

        // Parse phases (detail endpoint only)
        self.phases = json["phases"].arrayValue.compactMap { HivePhase(json: $0) }

        // Parse top-level tasks not inside a phase
        self.looseTasks = json["tasks"].arrayValue.compactMap { WorkspaceTask(json: $0) }
    }
}
