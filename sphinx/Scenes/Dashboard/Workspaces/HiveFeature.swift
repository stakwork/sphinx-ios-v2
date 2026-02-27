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

struct HiveFeature {
    let id: String
    let title: String
    let description: String?
    let brief: String?
    let userStories: [String]?  // Can be array or string
    let requirements: String?
    let architecture: String?
    let status: String?
    let priority: String?
    let createdAt: String?
    let updatedAt: String?
    let assignee: HiveAssignee?
    let createdBy: HiveAssignee?
    let deploymentStatus: String?
    let deploymentUrl: String?
    let userStoriesCount: Int?
    let stakworkRunsCount: Int?
    
    // Computed property to get name (backwards compatibility)
    var name: String { return title }
    
    // Computed property to get workflow status (backwards compatibility)
    var workflowStatus: String? { return status }
    
    init?(json: JSON) {
        guard let id = json["id"].string,
              let title = json["title"].string else { return nil }
        self.id = id
        self.title = title
        self.description = json["description"].string
        self.brief = json["brief"].string
        
        // Parse userStories - can be array of strings or string
        if let storiesArray = json["userStories"].array {
            self.userStories = storiesArray.compactMap { $0.string }
        } else if let storiesString = json["userStories"].string {
            self.userStories = [storiesString]
        } else {
            self.userStories = nil
        }
        
        self.requirements = json["requirements"].string
        self.architecture = json["architecture"].string
        self.status = json["status"].string
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
    }
}
