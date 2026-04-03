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
    var tasks: [WorkspaceTask]

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
    var status: String?
    let workflowStatus: String?
    var priority: String?
    let createdAt: String?
    let updatedAt: String?
    let assignee: HiveAssignee?
    let createdBy: HiveAssignee?
    let deploymentStatus: String?
    let deploymentUrl: String?
    let userStoriesCount: Int?
    let stakworkRunsCount: Int?
    var stakworkProjectId: Int?

    /// Phases with their tasks (from the detail endpoint)
    var phases: [HivePhase]
    /// Top-level tasks not assigned to any phase (from the detail endpoint)
    var looseTasks: [WorkspaceTask]

    /// Flattened list of all tasks across phases + loose tasks, sorted by createdAt ascending (oldest first).
    var allTasks: [WorkspaceTask] {
        let phaseTasks = phases.sorted { $0.order < $1.order }.flatMap { $0.tasks }
        let combined = phaseTasks + looseTasks
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(secondsFromGMT: 0)
        return combined.sorted { taskA, taskB in
            let d0 = taskA.createdAt.flatMap { s in HiveFeature.parseISO8601(s, formatter: df) } ?? Date.distantPast
            let d1 = taskB.createdAt.flatMap { s in HiveFeature.parseISO8601(s, formatter: df) } ?? Date.distantPast
            return d0 < d1
        }
    }

    private static func parseISO8601(_ string: String, formatter: DateFormatter) -> Date? {
        let formats = ["yyyy-MM-dd'T'HH:mm:ss.SSSZ", "yyyy-MM-dd'T'HH:mm:ssZ"]
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: string) { return date }
        }
        return nil
    }

    var hasTasks: Bool { !allTasks.isEmpty }
    
    // Computed property to get name (backwards compatibility)
    var name: String { return title }

    /// Finds the task with `taskId`, applies `apply` in place, and returns the flat index into `allTasks`.
    /// Returns `nil` if no task with that id belongs to this feature.
    @discardableResult
    mutating func updateTask(_ taskId: String, apply: (inout WorkspaceTask) -> Void) -> Int? {
        let sortedPhaseIndices = phases.indices.sorted { phases[$0].order < phases[$1].order }
        var flatOffset = 0
        for pi in sortedPhaseIndices {
            for ti in phases[pi].tasks.indices {
                if phases[pi].tasks[ti].id == taskId {
                    apply(&phases[pi].tasks[ti])
                    return flatOffset + ti
                }
            }
            flatOffset += phases[pi].tasks.count
        }
        for i in looseTasks.indices {
            if looseTasks[i].id == taskId {
                apply(&looseTasks[i])
                return flatOffset + i
            }
        }
        return nil
    }

    /// Removes the task with `taskId` from this feature and returns its flat index into `allTasks`.
    /// Returns `nil` if no task with that id belongs to this feature.
    @discardableResult
    mutating func removeTask(_ taskId: String) -> Int? {
        let sortedPhaseIndices = phases.indices.sorted { phases[$0].order < phases[$1].order }
        var flatOffset = 0
        for pi in sortedPhaseIndices {
            for ti in phases[pi].tasks.indices {
                if phases[pi].tasks[ti].id == taskId {
                    phases[pi].tasks.remove(at: ti)
                    return flatOffset + ti
                }
            }
            flatOffset += phases[pi].tasks.count
        }
        for i in looseTasks.indices {
            if looseTasks[i].id == taskId {
                looseTasks.remove(at: i)
                return flatOffset + i
            }
        }
        return nil
    }

    
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
        self.stakworkProjectId = json["stakworkProjectId"].int

        // Parse phases (detail endpoint only)
        self.phases = json["phases"].arrayValue.compactMap { HivePhase(json: $0) }

        // Parse top-level tasks not inside a phase
        self.looseTasks = json["tasks"].arrayValue.compactMap { WorkspaceTask(json: $0) }
    }
}
